import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/strava_connection.dart';
import '../models/workout_log.dart';

/// Strava REST API 연동 서비스
///
/// OAuth2 토큰 자동 갱신, Activity 데이터 조회,
/// [WorkoutLog] 모델로의 변환을 담당합니다.
class StravaService {
  StravaService({
    required SupabaseClient supabaseClient,
    Dio? dio,
  })  : _supabaseClient = supabaseClient,
        _dio = dio ??
            Dio(BaseOptions(
              baseUrl: _baseUrl,
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 15),
            ));

  final SupabaseClient _supabaseClient;
  final Dio _dio;

  static const String _baseUrl = 'https://www.strava.com/api/v3';
  static const String _authUrl = 'https://www.strava.com/oauth/token';

  /// Strava Client ID (.env에서 읽기)
  String get _clientId => dotenv.env['STRAVA_CLIENT_ID'] ?? '';

  /// Strava Client Secret (.env에서 읽기)
  String get _clientSecret => dotenv.env['STRAVA_CLIENT_SECRET'] ?? '';

  // ---------------------------------------------------------------------------
  // OAuth2 토큰 관리
  // ---------------------------------------------------------------------------

  /// Authorization Code를 사용하여 초기 토큰을 교환합니다.
  ///
  /// Strava OAuth 콜백에서 받은 [authCode]로 access_token, refresh_token을 발급받고,
  /// strava_connections 테이블에 저장합니다.
  ///
  /// 반환: 생성된 [StravaConnection]
  Future<StravaConnection> exchangeAuthCode({
    required String authCode,
    required String userId,
  }) async {
    final tokenDio = Dio();
    try {
      final response = await tokenDio.post(
        _authUrl,
        data: {
          'client_id': _clientId,
          'client_secret': _clientSecret,
          'code': authCode,
          'grant_type': 'authorization_code',
        },
      );

      final data = response.data as Map<String, dynamic>;

      final athleteId = data['athlete']['id'] as int;
      final accessToken = data['access_token'] as String;
      final refreshToken = data['refresh_token'] as String;
      final expiresAt = data['expires_at'] as int;
      final scope = data['scope'] as String? ?? 'read,activity:read';

      final tokenExpiresAt =
          DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000);

      // DB에 저장 (upsert - 기존 연결이 있으면 업데이트)
      final connectionData = {
        'user_id': userId,
        'strava_athlete_id': athleteId,
        'access_token': accessToken,
        'refresh_token': refreshToken,
        'token_expires_at': tokenExpiresAt.toIso8601String(),
        'scope': scope,
        'is_active': true,
      };

      final result = await _supabaseClient
          .from('strava_connections')
          .upsert(connectionData, onConflict: 'user_id')
          .select()
          .single();

      return StravaConnection.fromJson(result);
    } finally {
      tokenDio.close();
    }
  }

  /// 사용자의 Strava 연결 정보를 가져옵니다.
  ///
  /// 활성화된 연결만 반환합니다.
  Future<StravaConnection?> getConnection(String userId) async {
    final result = await _supabaseClient
        .from('strava_connections')
        .select()
        .eq('user_id', userId)
        .eq('is_active', true)
        .maybeSingle();

    return result == null ? null : StravaConnection.fromJson(result);
  }

  /// 토큰이 만료되었으면 자동으로 갱신합니다.
  ///
  /// 토큰 만료 5분 전부터 갱신을 시도합니다.
  /// 갱신 후 DB의 strava_connections 테이블을 업데이트합니다.
  ///
  /// 반환: 유효한 access_token
  Future<String> _getValidAccessToken(StravaConnection connection) async {
    final now = DateTime.now();
    final expiresAt = connection.tokenExpiresAt;
    final bufferTime = expiresAt.subtract(const Duration(minutes: 5));

    // 아직 유효한 토큰
    if (now.isBefore(bufferTime)) {
      return connection.accessToken;
    }

    // 토큰 갱신
    return await _refreshToken(connection);
  }

  /// Refresh Token으로 새 Access Token을 발급받습니다.
  Future<String> _refreshToken(StravaConnection connection) async {
    final tokenDio = Dio();
    try {
      final response = await tokenDio.post(
        _authUrl,
        data: {
          'client_id': _clientId,
          'client_secret': _clientSecret,
          'refresh_token': connection.refreshToken,
          'grant_type': 'refresh_token',
        },
      );

      final data = response.data as Map<String, dynamic>;

      final newAccessToken = data['access_token'] as String;
      final newRefreshToken = data['refresh_token'] as String;
      final expiresAt = data['expires_at'] as int;

      final newTokenExpiresAt =
          DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000);

      // DB 업데이트
      await _supabaseClient
          .from('strava_connections')
          .update({
            'access_token': newAccessToken,
            'refresh_token': newRefreshToken,
            'token_expires_at': newTokenExpiresAt.toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', connection.id);

      return newAccessToken;
    } finally {
      tokenDio.close();
    }
  }

  /// Strava 연동을 해제합니다 (비활성화).
  Future<void> disconnect(String userId) async {
    await _supabaseClient
        .from('strava_connections')
        .update({
          'is_active': false,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('user_id', userId);
  }

  // ---------------------------------------------------------------------------
  // Activity 데이터 조회
  // ---------------------------------------------------------------------------

  /// 사용자의 최근 러닝 Activity 목록을 가져옵니다.
  ///
  /// [userId] Supabase 사용자 ID
  /// [after] 이 시간 이후의 Activity만 (epoch seconds). null이면 최근 30개
  /// [page] 페이지 번호 (1부터 시작)
  /// [perPage] 페이지당 결과 수 (최대 200)
  ///
  /// 반환: WorkoutLog 목록
  Future<List<WorkoutLog>> getActivities({
    required String userId,
    DateTime? after,
    int page = 1,
    int perPage = 30,
  }) async {
    final connection = await getConnection(userId);
    if (connection == null) {
      throw const StravaServiceException('Strava 연결 정보를 찾을 수 없습니다.');
    }

    final accessToken = await _getValidAccessToken(connection);

    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'per_page': perPage,
      };

      if (after != null) {
        queryParams['after'] = after.millisecondsSinceEpoch ~/ 1000;
      }

      final response = await _dio.get(
        '/athlete/activities',
        queryParameters: queryParams,
        options: Options(
          headers: {'Authorization': 'Bearer $accessToken'},
        ),
      );

      final activities = response.data as List<dynamic>;
      debugPrint(
          '[StravaService] Strava API returned ${activities.length} total activities');

      // 러닝 Activity만 필터링하여 WorkoutLog로 변환
      final workoutLogs = <WorkoutLog>[];
      for (final activity in activities) {
        final activityMap = activity as Map<String, dynamic>;
        final type = activityMap['type'] as String?;
        debugPrint(
            '[StravaService] activity: id=${activityMap['id']}, type=$type, start=${activityMap['start_date_local']}');

        if (type == 'Run' || type == 'VirtualRun') {
          final log = _convertActivityToWorkoutLog(
            activity: activityMap,
            userId: userId,
          );
          if (log != null) {
            workoutLogs.add(log);
          }
        }
      }

      return workoutLogs;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw const StravaServiceException('Strava 인증이 만료되었습니다. 다시 연동해주세요.');
      }
      if (e.response?.statusCode == 429) {
        throw const StravaServiceException('Strava API 호출 한도를 초과했습니다. 잠시 후 다시 시도해주세요.');
      }
      throw StravaServiceException('Strava Activity 조회 실패: ${e.message}');
    }
  }

  /// 마지막 동기화 이후의 새로운 Activity를 가져옵니다.
  ///
  /// strava_connections 테이블의 last_sync_at을 기준으로 합니다.
  /// [updateSyncTime]이 true이면 동기화 시간을 업데이트합니다.
  /// 호출부에서 워크아웃 저장 성공 후 [markSyncComplete]를 호출해야 합니다.
  Future<List<WorkoutLog>> getNewActivitiesSince({
    required String userId,
  }) async {
    final connection = await getConnection(userId);
    if (connection == null) {
      throw const StravaServiceException('Strava 연결 정보를 찾을 수 없습니다.');
    }

    // last_sync_at에서 1일을 빼서 겹침 버퍼를 둠
    // → 동기화 타이밍 차이로 누락되는 활동 방지
    final rawSyncAt = connection.lastSyncAt;
    final after = rawSyncAt != null
        ? rawSyncAt.subtract(const Duration(days: 1))
        : DateTime.now().subtract(const Duration(days: 30));

    debugPrint('[StravaService] last_sync_at=$rawSyncAt');
    debugPrint(
        '[StravaService] fetching activities after=$after (with 1-day overlap, epoch=${after.millisecondsSinceEpoch ~/ 1000})');

    final workoutLogs = await getActivities(
      userId: userId,
      after: after,
    );

    debugPrint(
        '[StravaService] API returned ${workoutLogs.length} running activities');
    return workoutLogs;
  }

  /// 동기화 완료 후 last_sync_at 업데이트
  ///
  /// 워크아웃 저장 성공 후 호출해야 합니다.
  Future<void> markSyncComplete(String userId) async {
    final connection = await getConnection(userId);
    if (connection != null) {
      await _updateLastSyncAt(connection.id);
    }
  }

  /// 특정 Activity의 상세 정보를 가져옵니다.
  ///
  /// splits, streams(심박수, 케이던스, 고도) 등 상세 데이터를 포함합니다.
  Future<WorkoutLog?> getActivityDetail({
    required String userId,
    required int activityId,
  }) async {
    final connection = await getConnection(userId);
    if (connection == null) {
      throw const StravaServiceException('Strava 연결 정보를 찾을 수 없습니다.');
    }

    final accessToken = await _getValidAccessToken(connection);

    try {
      // Activity 상세 정보
      final activityResponse = await _dio.get(
        '/activities/$activityId',
        options: Options(
          headers: {'Authorization': 'Bearer $accessToken'},
        ),
      );

      final activityData = activityResponse.data as Map<String, dynamic>;

      // Streams (심박수, 케이던스) 가져오기
      Map<String, dynamic>? streams;
      try {
        final streamsResponse = await _dio.get(
          '/activities/$activityId/streams',
          queryParameters: {
            'keys': 'heartrate,cadence,altitude,velocity_smooth,distance',
            'key_by_type': true,
          },
          options: Options(
            headers: {'Authorization': 'Bearer $accessToken'},
          ),
        );
        streams = streamsResponse.data as Map<String, dynamic>?;
      } catch (_) {
        // Streams 조회 실패 시 무시 (권한 부족 등)
      }

      return _convertDetailedActivityToWorkoutLog(
        activity: activityData,
        streams: streams,
        userId: userId,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      throw StravaServiceException(
          'Strava Activity 상세 조회 실패: ${e.message}');
    }
  }

  /// last_sync_at 업데이트
  Future<void> _updateLastSyncAt(String connectionId) async {
    await _supabaseClient
        .from('strava_connections')
        .update({
          'last_sync_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', connectionId);
  }

  // ---------------------------------------------------------------------------
  // Strava OAuth URL 생성
  // ---------------------------------------------------------------------------

  /// Strava OAuth 인증 URL을 생성합니다.
  ///
  /// [redirectUri] OAuth 콜백 URI (앱의 딥링크)
  String getAuthorizationUrl({required String redirectUri}) {
    return 'https://www.strava.com/oauth/authorize'
        '?client_id=$_clientId'
        '&response_type=code'
        '&redirect_uri=${Uri.encodeComponent(redirectUri)}'
        '&approval_prompt=auto'
        '&scope=read,activity:read';
  }

  // ---------------------------------------------------------------------------
  // 내부 변환 로직
  // ---------------------------------------------------------------------------

  /// Strava Activity (목록용 간이 데이터)를 WorkoutLog로 변환합니다.
  WorkoutLog? _convertActivityToWorkoutLog({
    required Map<String, dynamic> activity,
    required String userId,
  }) {
    try {
      final activityId = activity['id'] as int;
      // start_date_local: 사용자 로컬 타임존 기준 시간 (날짜 정확도 보장)
      // start_date: UTC 기준 시간 (시간 정밀도용)
      final localDateStr = activity['start_date_local'] as String?;
      final utcDateStr = activity['start_date'] as String;
      final startDate = DateTime.parse(utcDateStr);
      final localStartDate = localDateStr != null
          ? DateTime.parse(localDateStr)
          : startDate.toLocal();
      final movingTime = activity['moving_time'] as int; // seconds
      final distanceM = (activity['distance'] as num).toDouble(); // meters
      final distanceKm = distanceM / 1000.0;

      // 60초 미만 또는 100m 미만은 무시
      if (movingTime < 60 || distanceKm < 0.1) return null;

      final endDate = startDate.add(Duration(
        seconds: activity['elapsed_time'] as int? ?? movingTime,
      ));

      // 평균 페이스 계산 (초/km)
      final avgPaceSecondsPerKm = distanceKm > 0
          ? (movingTime / distanceKm).round()
          : null;

      // 심박수
      final avgHeartRate =
          (activity['average_heartrate'] as num?)?.round();
      final maxHeartRate =
          (activity['max_heartrate'] as num?)?.round();

      // 고도
      final totalElevationGain =
          (activity['total_elevation_gain'] as num?)?.toDouble();

      // 칼로리 (Strava가 제공할 때만)
      final totalCalories =
          (activity['calories'] as num?)?.round();

      // 케이던스 (Strava는 cadence를 spm/2로 제공하므로 *2)
      final avgCadence =
          (activity['average_cadence'] as num?)?.round();
      final adjustedCadence =
          avgCadence != null ? avgCadence * 2 : null;

      // Splits
      final splits = _convertStravaSplits(
        activity['splits_metric'] as List<dynamic>?,
      );

      // Route polyline
      final map = activity['map'] as Map<String, dynamic>?;
      final polyline = map?['summary_polyline'] as String?;

      final now = DateTime.now();

      return WorkoutLog(
        id: '', // DB가 생성
        userId: userId,
        sessionId: null,
        source: 'strava',
        externalId: activityId.toString(),
        workoutDate: DateTime(
            localStartDate.year, localStartDate.month, localStartDate.day),
        startedAt: startDate,
        endedAt: endDate,
        distanceKm: double.parse(distanceKm.toStringAsFixed(2)),
        durationSeconds: movingTime,
        avgPaceSecondsPerKm: avgPaceSecondsPerKm,
        avgHeartRate: avgHeartRate,
        maxHeartRate: maxHeartRate,
        totalCalories: totalCalories,
        avgCadence: adjustedCadence,
        totalElevationGainM: totalElevationGain,
        splits: splits,
        heartRateData: null, // 목록 조회에서는 심박수 시계열 없음
        routePolyline: polyline,
        weatherTempC: null,
        weatherHumidity: null,
        weatherCondition: null,
        memo: null,
        createdAt: now,
        updatedAt: now,
      );
    } catch (e) {
      return null;
    }
  }

  /// Strava Activity 상세 데이터 + Streams를 WorkoutLog로 변환합니다.
  WorkoutLog? _convertDetailedActivityToWorkoutLog({
    required Map<String, dynamic> activity,
    Map<String, dynamic>? streams,
    required String userId,
  }) {
    // 기본 변환
    final baseLog = _convertActivityToWorkoutLog(
      activity: activity,
      userId: userId,
    );
    if (baseLog == null) return null;

    // Streams에서 심박수 + 고도 + 속도 시계열 통합 추출
    List<Map<String, dynamic>>? heartRateData;
    if (streams != null) {
      final hrStream = streams['heartrate'] as Map<String, dynamic>?;
      final hrData = hrStream?['data'] as List<dynamic>?;
      final altStream = streams['altitude'] as Map<String, dynamic>?;
      final altData = altStream?['data'] as List<dynamic>?;
      final velStream = streams['velocity_smooth'] as Map<String, dynamic>?;
      final velData = velStream?['data'] as List<dynamic>?;
      final distStream = streams['distance'] as Map<String, dynamic>?;
      final distData = distStream?['data'] as List<dynamic>?;

      // 가장 긴 스트림의 길이 사용
      final maxLen = [
        hrData?.length ?? 0,
        altData?.length ?? 0,
        velData?.length ?? 0,
        distData?.length ?? 0,
      ].reduce((a, b) => a > b ? a : b);

      if (maxLen > 0) {
        final startTime = baseLog.startedAt;
        final timeStream = streams['time'] as Map<String, dynamic>?;
        final timeData = timeStream?['data'] as List<dynamic>?;

        heartRateData = [];
        for (int i = 0; i < maxLen; i++) {
          final secondsOffset =
              (timeData != null && i < timeData.length)
                  ? (timeData[i] as num).toInt()
                  : i;
          final point = <String, dynamic>{
            'timestamp': startTime
                .add(Duration(seconds: secondsOffset))
                .toIso8601String(),
          };

          if (hrData != null && i < hrData.length) {
            point['bpm'] = (hrData[i] as num).round();
          }
          if (altData != null && i < altData.length) {
            point['altitude_m'] = (altData[i] as num).toDouble();
          }
          if (velData != null && i < velData.length) {
            point['velocity_mps'] = (velData[i] as num).toDouble();
          }
          if (distData != null && i < distData.length) {
            point['distance_m'] = (distData[i] as num).toDouble();
          }

          heartRateData.add(point);
        }
      }
    }

    // 케이던스를 streams에서 더 정확한 평균 가져오기
    int? avgCadence = baseLog.avgCadence;
    if (streams != null && streams.containsKey('cadence')) {
      final cadStream = streams['cadence'] as Map<String, dynamic>?;
      final cadData = cadStream?['data'] as List<dynamic>?;
      if (cadData != null && cadData.isNotEmpty) {
        final sum = cadData.fold<num>(
          0,
          (prev, val) => prev + (val as num),
        );
        // Strava cadence는 spm/2이므로 *2
        avgCadence = ((sum / cadData.length) * 2).round();
      }
    }

    // splits_metric (km별 구간) 우선, 없으면 laps 사용
    // laps는 자동랩 설정에 따라 1개만 있을 수 있어 km별 데이터로 부적합
    final splitsMetric = _convertStravaSplits(
      activity['splits_metric'] as List<dynamic>?,
    );
    final detailedSplits = splitsMetric ?? baseLog.splits;

    final now = DateTime.now();

    return WorkoutLog(
      id: baseLog.id,
      userId: baseLog.userId,
      sessionId: baseLog.sessionId,
      source: baseLog.source,
      externalId: baseLog.externalId,
      workoutDate: baseLog.workoutDate,
      startedAt: baseLog.startedAt,
      endedAt: baseLog.endedAt,
      distanceKm: baseLog.distanceKm,
      durationSeconds: baseLog.durationSeconds,
      avgPaceSecondsPerKm: baseLog.avgPaceSecondsPerKm,
      avgHeartRate: baseLog.avgHeartRate,
      maxHeartRate: baseLog.maxHeartRate,
      totalCalories: baseLog.totalCalories,
      avgCadence: avgCadence,
      totalElevationGainM: baseLog.totalElevationGainM,
      splits: detailedSplits,
      heartRateData: heartRateData ?? baseLog.heartRateData,
      routePolyline: baseLog.routePolyline,
      weatherTempC: baseLog.weatherTempC,
      weatherHumidity: baseLog.weatherHumidity,
      weatherCondition: baseLog.weatherCondition,
      memo: baseLog.memo,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Strava splits_metric를 앱 형식으로 변환합니다.
  ///
  /// Strava: [{"distance": 1000.0, "moving_time": 330, "split": 1}, ...]
  /// 앱: [{"km": 1, "pace_seconds": 330}, ...]
  List<Map<String, dynamic>>? _convertStravaSplits(
    List<dynamic>? stravaSplits,
  ) {
    if (stravaSplits == null || stravaSplits.isEmpty) return null;

    return stravaSplits.map((split) {
      final splitMap = split as Map<String, dynamic>;
      final splitNum = splitMap['split'] as int? ?? 0;
      final movingTime = splitMap['moving_time'] as int? ?? 0;
      final distanceM = (splitMap['distance'] as num?)?.toDouble() ?? 1000.0;
      final distanceKm = distanceM / 1000.0;

      // 1km 기준 페이스 보정
      final paceSeconds = distanceKm > 0
          ? (movingTime / distanceKm).round()
          : movingTime;

      final result = <String, dynamic>{
        'km': splitNum,
        'pace_seconds': paceSeconds,
      };

      // 마지막 split이 1km 미만일 수 있음
      if (distanceM < 950) {
        result['distance_km'] = double.parse(distanceKm.toStringAsFixed(2));
      }

      // 평균 심박수가 있으면 포함
      final avgHr = splitMap['average_heartrate'] as num?;
      if (avgHr != null) {
        result['avg_heart_rate'] = avgHr.round();
      }

      // 고도 차이
      final elevDiff = splitMap['elevation_difference'] as num?;
      if (elevDiff != null) {
        result['elevation_diff_m'] = elevDiff.toDouble();
      }

      return result;
    }).toList();
  }


}

/// Strava 서비스 예외
class StravaServiceException implements Exception {
  final String message;

  const StravaServiceException(this.message);

  @override
  String toString() => 'StravaServiceException: $message';
}
