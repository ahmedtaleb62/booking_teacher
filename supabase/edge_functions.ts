// ============================================================
// Supabase Edge Functions — حجز استاذ
// Deploy each function separately under /supabase/functions/
// ============================================================

// ============================================================
// 1. auto-cancel-session
//    Runs every minute via pg_cron or Supabase scheduled function.
//    Cancels TEACHER_APPROVED sessions where payment was not
//    submitted within 60 minutes.
// ============================================================
// supabase/functions/auto-cancel-session/index.ts
export const autoCancelSession = async () => {
  const { data: timedOut } = await supabase
    .from('sessions')
    .select('id')
    .eq('state', 'TEACHER_APPROVED')
    .lt('updated_at', new Date(Date.now() - 60 * 60 * 1000).toISOString());

  for (const session of (timedOut ?? [])) {
    await supabase.from('sessions').update({ state: 'CANCELLED' }).eq('id', session.id);
    await supabase.from('session_events').insert({
      session_id: session.id,
      event_type: 'CANCELLED',
      actor: 'system',
      note: 'انتهت مهلة الدفع (60 دقيقة)',
    });

    // Notify student
    const { data: s } = await supabase.from('sessions').select('student_id').eq('id', session.id).single();
    if (s) {
      await supabase.from('notifications').insert({
        user_id: s.student_id,
        title: 'انتهت مهلة الدفع',
        body: 'تم إلغاء طلبك تلقائياً لعدم إتمام الدفع خلال ساعة.',
        type: 'AUTO_CANCELLED',
        session_id: session.id,
      });
    }
  }
};

// ============================================================
// 2. no-show-handler
//    Checks sessions that started 15+ minutes ago and neither
//    party joined. Marks TEACHER_NO_SHOW or STUDENT_NO_SHOW.
// ============================================================
// supabase/functions/no-show-handler/index.ts
export const noShowHandler = async () => {
  const cutoff = new Date(Date.now() - 15 * 60 * 1000).toISOString();

  // Sessions in ACTIVE_SESSION that started 15+ min ago
  const { data: activeSessions } = await supabase
    .from('sessions')
    .select('id, teacher_id, student_id, scheduled_at')
    .eq('state', 'ACTIVE_SESSION')
    .lt('scheduled_at', cutoff);

  for (const session of (activeSessions ?? [])) {
    // Check join logs (stored in metadata)
    const { data: events } = await supabase
      .from('session_events')
      .select('event_type, actor')
      .eq('session_id', session.id)
      .in('event_type', ['TEACHER_JOINED', 'STUDENT_JOINED']);

    const teacherJoined = events?.some(e => e.event_type === 'TEACHER_JOINED');
    const studentJoined = events?.some(e => e.event_type === 'STUDENT_JOINED');

    if (!teacherJoined) {
      // Teacher no-show: reschedule automatically
      await supabase.from('sessions').update({ state: 'TEACHER_NO_SHOW' }).eq('id', session.id);
      await supabase.from('session_events').insert({
        session_id: session.id,
        event_type: 'TEACHER_NO_SHOW',
        actor: 'system',
      });

      // Create reschedule session with same payment
      await supabase.from('sessions').insert({
        student_id: session.student_id,
        teacher_id: session.teacher_id,
        state: 'REQUESTED',
        parent_session_id: session.id,
        // Carry over other fields from original session
      });

      await supabase.from('notifications').insert({
        user_id: session.student_id,
        title: 'غياب الأستاذ',
        body: 'لم يحضر الأستاذ. سيتم إعادة الجدولة تلقائياً دون أي خسارة مالية.',
        type: 'TEACHER_NO_SHOW',
        session_id: session.id,
      });

    } else if (!studentJoined) {
      // Student no-show: no refund
      await supabase.from('sessions').update({ state: 'STUDENT_NO_SHOW' }).eq('id', session.id);
      await supabase.from('session_events').insert({
        session_id: session.id,
        event_type: 'STUDENT_NO_SHOW',
        actor: 'system',
      });
    }
  }
};

// ============================================================
// 3. confirm-payment (called by admin panel)
//    Confirms payment, updates session to CONFIRMED_BOOKING,
//    writes to ledger, and sends notifications.
// ============================================================
// supabase/functions/confirm-payment/index.ts
export const confirmPayment = async (paymentId: string, adminId: string) => {
  const { data: payment } = await supabase
    .from('payments')
    .select('*, session:sessions(*)')
    .eq('id', paymentId)
    .single();

  if (!payment) throw new Error('Payment not found');

  const commission = payment.amount * 0.10;
  const netAmount  = payment.amount - commission;

  await supabase.from('payments').update({
    status: 'confirmed',
    confirmed_by: adminId,
    confirmed_at: new Date().toISOString(),
  }).eq('id', paymentId);

  await supabase.from('sessions').update({
    state: 'CONFIRMED_BOOKING',
  }).eq('id', payment.session_id);

  await supabase.from('ledger_entries').insert({
    payment_id: paymentId,
    session_id: payment.session_id,
    student_id: payment.student_id,
    teacher_id: payment.session.teacher_id,
    type: 'payment_received',
    amount: payment.amount,
    commission,
    net_amount: netAmount,
    description: `دفعة جلسة #${payment.session_id}`,
  });

  // Notify both parties
  await supabase.from('notifications').insert([
    {
      user_id: payment.student_id,
      title: 'تم تأكيد الدفع',
      body: 'تم تأكيد دفعتك! حجزك مؤكّد الآن.',
      type: 'PAYMENT_CONFIRMED',
      session_id: payment.session_id,
    },
    {
      user_id: payment.session.teacher_id,
      title: 'حجز مؤكّد',
      body: 'تم تأكيد الحجز والدفع. الجلسة في موعدها.',
      type: 'SESSION_CONFIRMED',
      session_id: payment.session_id,
    },
  ]);
};

// ============================================================
// 4. open-dispute (auto-triggered if payment not confirmed in 1h)
// ============================================================
// supabase/functions/open-dispute/index.ts
export const openDisputeForUnconfirmedPayments = async () => {
  const cutoff = new Date(Date.now() - 60 * 60 * 1000).toISOString();

  const { data: stale } = await supabase
    .from('sessions')
    .select('id, student_id, teacher_id')
    .eq('state', 'PAYMENT_SUBMITTED')
    .lt('updated_at', cutoff);

  for (const session of (stale ?? [])) {
    await supabase.from('sessions').update({ state: 'DISPUTE' }).eq('id', session.id);
    await supabase.from('session_events').insert({
      session_id: session.id,
      event_type: 'DISPUTE_OPENED',
      actor: 'system',
      note: 'لم يتم تأكيد الدفع خلال ساعة — فُتح نزاع تلقائياً',
    });

    await supabase.from('notifications').insert({
      user_id: session.student_id,
      title: 'فُتح نزاع',
      body: 'لم يتم تأكيد دفعتك خلال ساعة. تم فتح نزاع وستتواصل معك الإدارة.',
      type: 'DISPUTE_OPENED',
      session_id: session.id,
    });
  }
};

// Supabase client placeholder (injected by Supabase runtime)
declare const supabase: any;
