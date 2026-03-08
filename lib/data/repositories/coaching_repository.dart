import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/coaching_message.dart';

/// coaching_messages 테이블 데이터 접근
class CoachingRepository {
  final SupabaseClient _client;

  CoachingRepository(this._client);

  SupabaseQueryBuilder get _table => _client.from('coaching_messages');

  /// 사용자의 코칭 메시지 목록 (최신순)
  Future<List<CoachingMessage>> getMessages(
    String userId, {
    String? planId,
    int? limit,
  }) async {
    var query = _table.select().eq('user_id', userId);

    if (planId != null) {
      query = query.eq('plan_id', planId);
    }

    final ordered = query.order('created_at', ascending: false);

    final limited = limit != null ? ordered.limit(limit) : ordered;

    final response = await limited;
    return (response as List)
        .map((json) => CoachingMessage.fromJson(json))
        .toList();
  }

  /// 읽지 않은 메시지 목록
  Future<List<CoachingMessage>> getUnreadMessages(String userId) async {
    final response = await _table
        .select()
        .eq('user_id', userId)
        .eq('is_read', false)
        .order('created_at', ascending: false);
    return (response as List)
        .map((json) => CoachingMessage.fromJson(json))
        .toList();
  }

  /// 읽지 않은 메시지 개수
  Future<int> getUnreadCount(String userId) async {
    final response = await _table
        .select('id')
        .eq('user_id', userId)
        .eq('is_read', false);
    return (response as List).length;
  }

  /// 코칭 메시지 생성
  Future<CoachingMessage> createMessage(CoachingMessage message) async {
    final response = await _table
        .insert(message.toJson())
        .select()
        .single();
    return CoachingMessage.fromJson(response);
  }

  /// 메시지 읽음 처리
  Future<void> markAsRead(String messageId) async {
    await _table.update({'is_read': true}).eq('id', messageId);
  }

  /// 모든 메시지 읽음 처리
  Future<void> markAllAsRead(String userId) async {
    await _table
        .update({'is_read': true})
        .eq('user_id', userId)
        .eq('is_read', false);
  }

  /// 특정 유형의 최신 메시지 조회
  Future<CoachingMessage?> getLatestByType(
    String userId,
    String messageType,
  ) async {
    final response = await _table
        .select()
        .eq('user_id', userId)
        .eq('message_type', messageType)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return response == null ? null : CoachingMessage.fromJson(response);
  }

  /// 특정 플랜 + 주차의 메시지 조회
  Future<List<CoachingMessage>> getMessagesByWeek(
    String planId,
    String weekId,
  ) async {
    final response = await _table
        .select()
        .eq('plan_id', planId)
        .eq('week_id', weekId)
        .order('created_at', ascending: false);
    return (response as List)
        .map((json) => CoachingMessage.fromJson(json))
        .toList();
  }

  /// 특정 세션의 피드백 메시지 조회
  Future<CoachingMessage?> getSessionFeedback(String sessionId) async {
    final response = await _table
        .select()
        .eq('session_id', sessionId)
        .eq('message_type', 'session_feedback')
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return response == null ? null : CoachingMessage.fromJson(response);
  }

  /// 코칭 메시지 삭제
  Future<void> deleteMessage(String messageId) async {
    await _table.delete().eq('id', messageId);
  }

  /// 특정 주차의 주간 리뷰 메시지 조회
  Future<CoachingMessage?> getWeeklyReview(String weekId) async {
    final response = await _table
        .select()
        .eq('week_id', weekId)
        .eq('message_type', 'weekly_review')
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return response == null ? null : CoachingMessage.fromJson(response);
  }

  /// 특정 세션의 날씨 페이스 보정 메시지 조회
  Future<CoachingMessage?> getWeatherAdjustment(String sessionId) async {
    final response = await _table
        .select()
        .eq('session_id', sessionId)
        .eq('message_type', 'pace_adjustment')
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return response == null ? null : CoachingMessage.fromJson(response);
  }
}
