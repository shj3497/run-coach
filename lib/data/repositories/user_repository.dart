import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_profile.dart';

/// user_profiles 테이블 데이터 접근
class UserRepository {
  final SupabaseClient _client;

  UserRepository(this._client);

  SupabaseQueryBuilder get _table => _client.from('user_profiles');

  /// 프로필 조회
  Future<UserProfile?> getProfile(String userId) async {
    final response = await _table
        .select()
        .eq('id', userId)
        .maybeSingle();
    return response == null ? null : UserProfile.fromJson(response);
  }

  /// 프로필 생성/갱신 (upsert)
  Future<UserProfile> upsertProfile(UserProfile profile) async {
    final response = await _table
        .upsert(profile.toJson())
        .select()
        .single();
    return UserProfile.fromJson(response);
  }

  /// 프로필 부분 업데이트
  Future<void> updateProfile(
    String userId,
    Map<String, dynamic> updates,
  ) async {
    await _table.update(updates).eq('id', userId);
  }

  /// 프로필 존재 여부 확인
  Future<bool> hasProfile(String userId) async {
    final response = await _table
        .select('id')
        .eq('id', userId)
        .maybeSingle();
    return response != null;
  }
}
