/// Strava OAuth 연동 정보 모델
/// DB 테이블: strava_connections
class StravaConnection {
  final String id;
  final String userId;
  final int stravaAthleteId;
  final String accessToken;
  final String refreshToken;
  final DateTime tokenExpiresAt;
  final String scope;
  final bool isActive;
  final DateTime? lastSyncAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const StravaConnection({
    required this.id,
    required this.userId,
    required this.stravaAthleteId,
    required this.accessToken,
    required this.refreshToken,
    required this.tokenExpiresAt,
    required this.scope,
    this.isActive = true,
    this.lastSyncAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory StravaConnection.fromJson(Map<String, dynamic> json) =>
      StravaConnection(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        stravaAthleteId: json['strava_athlete_id'] as int,
        accessToken: json['access_token'] as String,
        refreshToken: json['refresh_token'] as String,
        tokenExpiresAt: DateTime.parse(json['token_expires_at'] as String),
        scope: json['scope'] as String,
        isActive: json['is_active'] as bool? ?? true,
        lastSyncAt: json['last_sync_at'] != null
            ? DateTime.parse(json['last_sync_at'] as String)
            : null,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'strava_athlete_id': stravaAthleteId,
        'access_token': accessToken,
        'refresh_token': refreshToken,
        'token_expires_at': tokenExpiresAt.toIso8601String(),
        'scope': scope,
        'is_active': isActive,
        'last_sync_at': lastSyncAt?.toIso8601String(),
      };
}
