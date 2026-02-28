import 'package:supabase_flutter/supabase_flutter.dart';

/// 인증 관련 데이터 접근
class AuthRepository {
  final SupabaseClient _client;

  AuthRepository(this._client);

  /// 익명 로그인 (개발용 임시 우회)
  Future<AuthResponse> signInAnonymously() async {
    return await _client.auth.signInAnonymously();
  }

  /// 로그아웃
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  /// 현재 로그인된 사용자
  User? get currentUser => _client.auth.currentUser;

  /// 현재 세션
  Session? get currentSession => _client.auth.currentSession;

  /// 로그인 상태
  bool get isLoggedIn => _client.auth.currentSession != null;

  /// 인증 상태 변경 스트림
  Stream<AuthState> get onAuthStateChange =>
      _client.auth.onAuthStateChange;
}
