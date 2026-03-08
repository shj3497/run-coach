import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// 날씨 데이터 모델
///
/// OpenWeatherMap Current Weather API 응답을 파싱한 결과입니다.
class WeatherData {
  final double temperatureC;
  final double feelsLikeC;
  final int humidityPercent;
  final String condition;
  final String conditionDetail;
  final String iconCode;
  final double windSpeedMs;
  final String cityName;
  final DateTime timestamp;

  const WeatherData({
    required this.temperatureC,
    required this.feelsLikeC,
    required this.humidityPercent,
    required this.condition,
    required this.conditionDetail,
    required this.iconCode,
    required this.windSpeedMs,
    required this.cityName,
    required this.timestamp,
  });

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    final main = json['main'] as Map<String, dynamic>;
    final weather =
        (json['weather'] as List<dynamic>).first as Map<String, dynamic>;
    final wind = json['wind'] as Map<String, dynamic>;

    return WeatherData(
      temperatureC: (main['temp'] as num).toDouble(),
      feelsLikeC: (main['feels_like'] as num).toDouble(),
      humidityPercent: (main['humidity'] as num).toInt(),
      condition: weather['main'] as String? ?? '',
      conditionDetail: weather['description'] as String? ?? '',
      iconCode: weather['icon'] as String? ?? '01d',
      windSpeedMs: (wind['speed'] as num).toDouble(),
      cityName: json['name'] as String? ?? '',
      timestamp: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'temperature_c': temperatureC,
        'feels_like_c': feelsLikeC,
        'humidity_percent': humidityPercent,
        'condition': condition,
        'condition_detail': conditionDetail,
        'icon_code': iconCode,
        'wind_speed_ms': windSpeedMs,
        'city_name': cityName,
        'timestamp': timestamp.toIso8601String(),
      };

  @override
  String toString() =>
      'WeatherData($cityName: ${temperatureC.toStringAsFixed(1)}C, $conditionDetail)';
}

/// OpenWeatherMap API 연동 서비스
///
/// 30분 인메모리 캐시를 지원하며, 위도/경도 기반으로 조회합니다.
class WeatherService {
  WeatherService({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: _baseUrl,
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10),
            ));

  final Dio _dio;

  static const String _baseUrl = 'https://api.openweathermap.org/data/2.5';
  static const Duration _cacheDuration = Duration(minutes: 30);
  static const double _cacheDistanceThresholdKm = 5.0;

  // 인메모리 캐시
  WeatherData? _cachedData;
  double? _cachedLatitude;
  double? _cachedLongitude;
  DateTime? _cachedAt;

  String get _apiKey => dotenv.env['OPENWEATHERMAP_API_KEY'] ?? '';

  /// 현재 날씨를 조회합니다.
  ///
  /// 같은 위치(약 5km 이내)에서 30분 이내 재요청 시 캐시된 데이터를 반환합니다.
  Future<WeatherData> getCurrentWeather({
    required double latitude,
    required double longitude,
  }) async {
    final cached = _getCachedIfValid(latitude, longitude);
    if (cached != null) return cached;

    if (_apiKey.isEmpty) {
      throw const WeatherServiceException(
        'OpenWeatherMap API 키가 설정되지 않았습니다.',
      );
    }

    try {
      final response = await _dio.get(
        '/weather',
        queryParameters: {
          'lat': latitude,
          'lon': longitude,
          'appid': _apiKey,
          'units': 'metric',
          'lang': 'kr',
        },
      );

      final data = response.data as Map<String, dynamic>;
      final weatherData = WeatherData.fromJson(data);
      _updateCache(weatherData, latitude, longitude);
      return weatherData;
    } on DioException catch (e) {
      if (e.response != null) {
        final statusCode = e.response!.statusCode;
        if (statusCode == 401) {
          throw const WeatherServiceException(
            'OpenWeatherMap API 키가 유효하지 않습니다.',
          );
        }
        if (statusCode == 429) {
          throw const WeatherServiceException(
            'OpenWeatherMap API 호출 한도를 초과했습니다.',
          );
        }
        throw WeatherServiceException(
          '날씨 정보 조회 실패 (HTTP $statusCode)',
        );
      }
      throw WeatherServiceException(
        '날씨 정보 조회 실패: ${e.message}',
      );
    }
  }

  void clearCache() {
    _cachedData = null;
    _cachedLatitude = null;
    _cachedLongitude = null;
    _cachedAt = null;
  }

  // ---------------------------------------------------------------------------
  // 정적 유틸리티
  // ---------------------------------------------------------------------------

  /// OpenWeather 아이콘 코드를 이모지로 매핑
  static String getWeatherEmoji(String iconCode) {
    final code = iconCode.replaceAll(RegExp(r'[dn]$'), '');

    switch (code) {
      case '01':
        return iconCode.endsWith('d') ? '☀️' : '🌙';
      case '02':
        return iconCode.endsWith('d') ? '⛅' : '☁️';
      case '03':
        return '☁️';
      case '04':
        return '☁️';
      case '09':
        return '🌧️';
      case '10':
        return iconCode.endsWith('d') ? '🌦️' : '🌧️';
      case '11':
        return '⛈️';
      case '13':
        return '❄️';
      case '50':
        return '🌫️';
      default:
        return '🌤️';
    }
  }

  /// 러닝 관점에서의 날씨 설명 메시지
  static String getWeatherDescription(WeatherData weather) {
    final parts = <String>[];

    if (weather.temperatureC < 0) {
      parts.add('영하의 추운 날씨입니다. 방한에 유의하세요.');
    } else if (weather.temperatureC < 5) {
      parts.add('쌀쌀한 날씨입니다. 겹쳐 입는 것을 권장합니다.');
    } else if (weather.temperatureC < 15) {
      parts.add('러닝하기 적당한 기온입니다.');
    } else if (weather.temperatureC < 25) {
      parts.add('쾌적한 기온입니다.');
    } else if (weather.temperatureC < 30) {
      parts.add('더운 날씨입니다. 충분한 수분 섭취가 필요합니다.');
    } else {
      parts.add('매우 더운 날씨입니다. 열사병에 주의하세요.');
    }

    if (weather.humidityPercent > 80) {
      parts.add('습도가 높아 체감 온도가 올라갈 수 있습니다.');
    }

    if (weather.windSpeedMs > 10) {
      parts.add('강풍이 불고 있어 주의가 필요합니다.');
    } else if (weather.windSpeedMs > 5) {
      parts.add('바람이 다소 강합니다.');
    }

    final condition = weather.condition.toLowerCase();
    if (condition.contains('rain') || condition.contains('drizzle')) {
      parts.add('비가 오고 있으니 미끄럼에 주의하세요.');
    } else if (condition.contains('snow')) {
      parts.add('눈이 오고 있어 노면 상태에 주의하세요.');
    } else if (condition.contains('thunderstorm')) {
      parts.add('천둥번개가 있으니 실내 운동을 권장합니다.');
    }

    return parts.join(' ');
  }

  // ---------------------------------------------------------------------------
  // 캐시 로직
  // ---------------------------------------------------------------------------

  WeatherData? _getCachedIfValid(double latitude, double longitude) {
    if (_cachedData == null ||
        _cachedAt == null ||
        _cachedLatitude == null ||
        _cachedLongitude == null) {
      return null;
    }

    final elapsed = DateTime.now().difference(_cachedAt!);
    if (elapsed > _cacheDuration) return null;

    final distanceKm = _approximateDistanceKm(
      _cachedLatitude!,
      _cachedLongitude!,
      latitude,
      longitude,
    );
    if (distanceKm > _cacheDistanceThresholdKm) return null;

    return _cachedData;
  }

  void _updateCache(
    WeatherData data,
    double latitude,
    double longitude,
  ) {
    _cachedData = data;
    _cachedLatitude = latitude;
    _cachedLongitude = longitude;
    _cachedAt = DateTime.now();
  }

  /// 두 좌표 간 대략적인 거리 (km) - 캐시 비교용
  static double _approximateDistanceKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const kmPerDegreeLat = 111.0;
    final avgLatRad = ((lat1 + lat2) / 2) * 3.141592653589793 / 180.0;
    final cosLat = 1 - (avgLatRad * avgLatRad) / 2;
    final kmPerDegreeLon = 111.0 * cosLat;

    final dLat = (lat2 - lat1) * kmPerDegreeLat;
    final dLon = (lon2 - lon1) * kmPerDegreeLon;

    final distSq = dLat * dLat + dLon * dLon;
    if (distSq <= 0) return 0;
    // Newton's method for sqrt
    double x = distSq;
    for (int i = 0; i < 5; i++) {
      x = (x + distSq / x) / 2;
    }
    return x;
  }
}

/// 날씨 서비스 예외
class WeatherServiceException implements Exception {
  final String message;
  const WeatherServiceException(this.message);

  @override
  String toString() => 'WeatherServiceException: $message';
}
