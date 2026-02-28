/// 코칭 메시지 모델
/// DB 테이블: coaching_messages
class CoachingMessage {
  final String id;
  final String userId;
  final String? planId;
  final String? weekId;
  final String? sessionId;
  final String messageType;
  final String? title;
  final String content;
  final String? llmModel;
  final Map<String, dynamic>? llmPromptSnapshot;
  final Map<String, dynamic>? tokenUsage;
  final bool isRead;
  final DateTime createdAt;

  const CoachingMessage({
    required this.id,
    required this.userId,
    this.planId,
    this.weekId,
    this.sessionId,
    required this.messageType,
    this.title,
    required this.content,
    this.llmModel,
    this.llmPromptSnapshot,
    this.tokenUsage,
    this.isRead = false,
    required this.createdAt,
  });

  factory CoachingMessage.fromJson(Map<String, dynamic> json) =>
      CoachingMessage(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        planId: json['plan_id'] as String?,
        weekId: json['week_id'] as String?,
        sessionId: json['session_id'] as String?,
        messageType: json['message_type'] as String,
        title: json['title'] as String?,
        content: json['content'] as String,
        llmModel: json['llm_model'] as String?,
        llmPromptSnapshot:
            json['llm_prompt_snapshot'] as Map<String, dynamic>?,
        tokenUsage: json['token_usage'] as Map<String, dynamic>?,
        isRead: json['is_read'] as bool? ?? false,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'plan_id': planId,
        'week_id': weekId,
        'session_id': sessionId,
        'message_type': messageType,
        'title': title,
        'content': content,
        'llm_model': llmModel,
        'llm_prompt_snapshot': llmPromptSnapshot,
        'token_usage': tokenUsage,
        'is_read': isRead,
      };
}
