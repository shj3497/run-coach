import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/models/strava_connection.dart';
import '../../data/services/strava_service.dart';
import '../auth/providers/auth_providers.dart';
import 'data_providers.dart';

// ─── State ───

enum StravaAuthStatus { disconnected, connecting, connected, error }

class StravaAuthState {
  final StravaAuthStatus status;
  final StravaConnection? connection;
  final String? errorMessage;

  const StravaAuthState({
    this.status = StravaAuthStatus.disconnected,
    this.connection,
    this.errorMessage,
  });

  bool get isConnected => status == StravaAuthStatus.connected;
  bool get isConnecting => status == StravaAuthStatus.connecting;

  StravaAuthState copyWith({
    StravaAuthStatus? status,
    StravaConnection? connection,
    String? errorMessage,
  }) =>
      StravaAuthState(
        status: status ?? this.status,
        connection: connection ?? this.connection,
        errorMessage: errorMessage,
      );
}

// ─── Notifier ───

class StravaAuthNotifier extends StateNotifier<StravaAuthState> {
  final StravaService _stravaService;
  final String? _userId;
  StreamSubscription<Uri>? _linkSub;

  /// Supabase Edge Function을 중간 리다이렉트 서버로 사용.
  /// Strava → Edge Function → runcoach://strava-callback 딥링크로 리다이렉트.
  static const String _redirectUri =
      'https://wyhyamulyoemflsmhipc.supabase.co/functions/v1/strava-callback';

  StravaAuthNotifier({
    required StravaService stravaService,
    required String? userId,
  })  : _stravaService = stravaService,
        _userId = userId,
        super(const StravaAuthState()) {
    _checkExistingConnection();
  }

  /// 기존 Strava 연결 확인
  Future<void> _checkExistingConnection() async {
    debugPrint('[StravaAuth] _checkExistingConnection — userId=$_userId');
    if (_userId == null) return;
    try {
      final connection = await _stravaService.getConnection(_userId);
      debugPrint(
          '[StravaAuth] connection found: ${connection != null}, isActive: ${connection?.isActive}');
      if (connection != null && connection.isActive) {
        state = StravaAuthState(
          status: StravaAuthStatus.connected,
          connection: connection,
        );
        debugPrint('[StravaAuth] → status set to CONNECTED');
      }
    } catch (e) {
      debugPrint('[StravaAuth] _checkExistingConnection ERROR: $e');
      // 확인 실패 시 disconnected 상태 유지
    }
  }

  /// Strava OAuth 플로우 시작
  Future<void> startOAuthFlow() async {
    if (_userId == null) {
      state = state.copyWith(
        status: StravaAuthStatus.error,
        errorMessage: '로그인이 필요합니다',
      );
      return;
    }

    state = state.copyWith(status: StravaAuthStatus.connecting);

    try {
      // 딥링크 리스너 등록
      _linkSub?.cancel();
      final appLinks = AppLinks();
      _linkSub = appLinks.uriLinkStream.listen(
        _handleCallback,
        onError: (_) {
          state = state.copyWith(
            status: StravaAuthStatus.error,
            errorMessage: 'Strava 인증 콜백 처리 중 오류가 발생했습니다',
          );
        },
      );

      // Strava 인증 페이지 열기
      final authUrl = _stravaService.getAuthorizationUrl(
        redirectUri: _redirectUri,
      );
      final uri = Uri.parse(authUrl);

      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        state = state.copyWith(
          status: StravaAuthStatus.error,
          errorMessage: 'Strava 인증 페이지를 열 수 없습니다',
        );
      }
    } catch (e) {
      state = state.copyWith(
        status: StravaAuthStatus.error,
        errorMessage: 'Strava 연동 시작에 실패했습니다',
      );
    }
  }

  /// OAuth 콜백 처리
  Future<void> _handleCallback(Uri uri) async {
    if (uri.scheme != 'runcoach' || uri.host != 'strava-callback') return;

    final code = uri.queryParameters['code'];
    final error = uri.queryParameters['error'];

    if (error != null || code == null) {
      state = state.copyWith(
        status: StravaAuthStatus.error,
        errorMessage: error == 'access_denied'
            ? 'Strava 연동이 거부되었습니다'
            : 'Strava 인증에 실패했습니다',
      );
      _linkSub?.cancel();
      return;
    }

    try {
      final connection = await _stravaService.exchangeAuthCode(
        authCode: code,
        userId: _userId!,
      );

      state = StravaAuthState(
        status: StravaAuthStatus.connected,
        connection: connection,
      );
    } catch (e) {
      state = state.copyWith(
        status: StravaAuthStatus.error,
        errorMessage: 'Strava 토큰 교환에 실패했습니다',
      );
    } finally {
      _linkSub?.cancel();
    }
  }

  /// Strava 연동 해제
  Future<void> disconnect() async {
    if (_userId == null) return;
    try {
      await _stravaService.disconnect(_userId);
      state = const StravaAuthState(status: StravaAuthStatus.disconnected);
    } catch (e) {
      state = state.copyWith(
        status: StravaAuthStatus.error,
        errorMessage: 'Strava 연동 해제에 실패했습니다',
      );
    }
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    super.dispose();
  }
}

// ─── Providers ───

final stravaAuthProvider =
    StateNotifierProvider<StravaAuthNotifier, StravaAuthState>((ref) {
  return StravaAuthNotifier(
    stravaService: ref.watch(stravaServiceProvider),
    userId: ref.watch(currentUserProvider)?.id,
  );
});

/// Strava 연결 여부 편의 Provider
final isStravaConnectedProvider = Provider<bool>((ref) {
  return ref.watch(stravaAuthProvider).isConnected;
});
