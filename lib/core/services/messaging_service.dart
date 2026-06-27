import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/session_message.dart';
import 'supabase_service.dart';

class MessagingService {
  static final _db = SupabaseService.client;
  static const _bucket = 'session-media';

  /// Sends an FCM push notification via the notify-user Edge Function.
  /// Silently ignores errors so callers don't need to handle them.
  static Future<void> notifyRecipient({
    required String recipientId,
    required String title,
    required String body,
    required String sessionId,
    String type = 'SESSION_MESSAGE',
    Map<String, String>? extra,
  }) async {
    try {
      await SupabaseService.client.functions.invoke(
        'notify-user',
        body: {
          'user_id': recipientId,
          'title':   title,
          'body':    body,
          'data': {
            'type':       type,
            'session_id': sessionId,
            ...?extra,
          },
        },
      );
    } catch (_) {}
  }

  static Future<List<SessionMessage>> getMessages(String sessionId) async {
    final data = await _db
        .from('session_messages')
        .select()
        .eq('session_id', sessionId)
        .order('created_at');
    return (data as List)
        .map((e) => SessionMessage.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static RealtimeChannel subscribeToMessages(
    String sessionId, {
    required void Function(SessionMessage) onInsert,
    required void Function(SessionMessage) onUpdate,
    required void Function(String msgId) onDelete,
  }) {
    final filter = PostgresChangeFilter(
      type: PostgresChangeFilterType.eq,
      column: 'session_id',
      value: sessionId,
    );
    return _db
        .channel('msgs-$sessionId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'session_messages',
          filter: filter,
          callback: (p) => onInsert(SessionMessage.fromJson(p.newRecord)),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'session_messages',
          filter: filter,
          callback: (p) => onUpdate(SessionMessage.fromJson(p.newRecord)),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'session_messages',
          filter: filter,
          callback: (p) {
            final id = p.oldRecord['id'] as String?;
            if (id != null) onDelete(id);
          },
        )
        .subscribe();
  }

  static Future<void> deleteMessage(String msgId) async {
    await _db.from('session_messages')
        .delete()
        .eq('id', msgId)
        .eq('sender_id', SupabaseService.userId!);
  }

  static Future<void> editMessage(String msgId, String newContent) async {
    await _db.from('session_messages')
        .update({'content': newContent.trim()})
        .eq('id', msgId)
        .eq('sender_id', SupabaseService.userId!)
        .eq('type', 'text');
  }

  static Future<void> sendText(String sessionId, String text) async {
    await _db.from('session_messages').insert({
      'session_id': sessionId,
      'sender_id':  SupabaseService.userId,
      'type':       'text',
      'content':    text.trim(),
    });
  }

  static Future<void> sendImage(
    String sessionId,
    Uint8List bytes,
    String ext,
  ) async {
    final uid = SupabaseService.userId!;
    final path = '$uid/${sessionId}_img_${DateTime.now().millisecondsSinceEpoch}.$ext';
    final contentType = ext == 'png' ? 'image/png' : (ext == 'webp' ? 'image/webp' : 'image/jpeg');
    await SupabaseService.client.storage
        .from(_bucket)
        .uploadBinary(path, bytes, fileOptions: FileOptions(contentType: contentType));
    final url = SupabaseService.client.storage.from(_bucket).getPublicUrl(path);
    await _db.from('session_messages').insert({
      'session_id': sessionId,
      'sender_id':  uid,
      'type':       'image',
      'file_url':   url,
    });
  }

  static Future<void> sendAudio(
    String sessionId,
    Uint8List bytes,
    int durationSec,
  ) async {
    final uid = SupabaseService.userId!;
    final path = '$uid/${sessionId}_audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await SupabaseService.client.storage
        .from(_bucket)
        .uploadBinary(path, bytes, fileOptions: const FileOptions(contentType: 'audio/m4a'));
    final url = SupabaseService.client.storage.from(_bucket).getPublicUrl(path);
    await _db.from('session_messages').insert({
      'session_id':  sessionId,
      'sender_id':   uid,
      'type':        'audio',
      'file_url':    url,
      'duration_sec': durationSec,
    });
  }

  static Future<void> sendFile(
    String sessionId,
    Uint8List bytes,
    String fileName,
    String mimeType,
  ) async {
    final uid      = SupabaseService.userId!;
    final safeName = _sanitizeName(fileName);
    final path     = '$uid/${sessionId}_file_${DateTime.now().millisecondsSinceEpoch}_$safeName';
    await SupabaseService.client.storage
        .from(_bucket)
        .uploadBinary(path, bytes, fileOptions: FileOptions(contentType: mimeType));
    final url = SupabaseService.client.storage.from(_bucket).getPublicUrl(path);
    await _db.from('session_messages').insert({
      'session_id': sessionId,
      'sender_id':  uid,
      'type':       'file',
      'content':    fileName, // display original name to user
      'file_url':   url,
    });
  }

  // Replace non-ASCII chars and whitespace/special chars with underscores
  // so storage keys are always valid.
  static String _sanitizeName(String name) {
    final noAccents = name.replaceAll(RegExp(r'[^\x00-\x7F]'), '_');
    return noAccents.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
  }
}
