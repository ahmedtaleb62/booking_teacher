class SessionMessage {
  final String id;
  final String sessionId;
  final String senderId;
  final String type; // 'text' | 'image' | 'audio' | 'file'
  final String? content;
  final String? fileUrl;
  final int? durationSec;
  final DateTime createdAt;

  const SessionMessage({
    required this.id,
    required this.sessionId,
    required this.senderId,
    required this.type,
    this.content,
    this.fileUrl,
    this.durationSec,
    required this.createdAt,
  });

  factory SessionMessage.fromJson(Map<String, dynamic> json) {
    return SessionMessage(
      id:          json['id'] as String,
      sessionId:   json['session_id'] as String,
      senderId:    json['sender_id'] as String,
      type:        json['type'] as String,
      content:     json['content'] as String?,
      fileUrl:     json['file_url'] as String?,
      durationSec: json['duration_sec'] as int?,
      createdAt:   DateTime.parse(json['created_at'] as String),
    );
  }
}
