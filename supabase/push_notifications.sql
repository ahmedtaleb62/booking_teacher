-- ══════════════════════════════════════════════════════════════════
-- Push notifications setup
-- Run this SQL in: Supabase Dashboard → SQL Editor
-- ══════════════════════════════════════════════════════════════════

-- 1. Enable pg_net extension (needed for HTTP calls from triggers)
create extension if not exists pg_net with schema extensions;

-- ══════════════════════════════════════════════════════════════════
-- 2. device_tokens table — stores FCM tokens per user
-- ══════════════════════════════════════════════════════════════════
create table if not exists public.device_tokens (
  id          uuid        default gen_random_uuid() primary key,
  user_id     uuid        references auth.users(id) on delete cascade not null,
  token       text        not null,
  platform    text        not null check (platform in ('android', 'ios')),
  updated_at  timestamptz default now(),
  unique (user_id, token)
);

alter table public.device_tokens enable row level security;

create policy "Users manage own tokens"
  on public.device_tokens
  for all
  using  (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- ══════════════════════════════════════════════════════════════════
-- 3. Postgres function — calls the Edge Function via pg_net
-- ══════════════════════════════════════════════════════════════════
create or replace function public.send_push_for_notification()
returns trigger language plpgsql security definer as $$
begin
  perform net.http_post(
    url     := 'https://tmrrkqqtpbzckaehnprq.supabase.co/functions/v1/notify-user',
    headers := jsonb_build_object(
      'Content-Type',  'application/json',
      'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRtcnJrcXF0cGJ6Y2thZWhucHJxIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2NzU5NjgzOCwiZXhwIjoyMDgzMTcyODM4fQ.twKsJKpL1YpAlhnWo_FsD9X-feOLrQ9Llw53GpyMI1E'
    ),
    body    := jsonb_build_object(
      'user_id', NEW.user_id,
      'title',   NEW.title,
      'body',    NEW.body,
      'data',    jsonb_build_object(
        'type',       NEW.type,
        'session_id', NEW.session_id
      )
    )
  );
  return NEW;
end;
$$;

-- ══════════════════════════════════════════════════════════════════
-- 4. Trigger: fire after every INSERT into notifications
-- ══════════════════════════════════════════════════════════════════
drop trigger if exists push_on_notification_insert on public.notifications;
create trigger push_on_notification_insert
  after insert on public.notifications
  for each row execute function public.send_push_for_notification();
