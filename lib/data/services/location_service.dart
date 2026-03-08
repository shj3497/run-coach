import 'package:geolocator/geolocator.dart';

/// 위치 서비스
///
/// 디바이스의 현재 GPS 위치를 가져오고 위치 권한을 관리합니다.
class LocationService {
  const LocationService();

  /// 위치 서비스 활성화 여부 및 권한 상태를 확인합니다.
  Future<bool> checkPermission() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return false;

      final permission = await Geolocator.checkPermission();
      return permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
    } catch (e) {
      return false;
    }
  }

  /// 위치 권한을 요청합니다.
  ///
  /// 이미 권한이 있으면 true를 바로 반환합니다.
  /// 영구 거부 상태이면 false를 반환합니다.
  Future<bool> requestPermission() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return false;

      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        return false;
      }

      return permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
    } catch (e) {
      return false;
    }
  }

  /// 위치 권한이 영구 거부 상태인지 확인합니다.
  Future<bool> isPermissionDeniedForever() async {
    try {
      final permission = await Geolocator.checkPermission();
      return permission == LocationPermission.deniedForever;
    } catch (e) {
      return false;
    }
  }

  /// 앱 설정 화면을 엽니다 (영구 거부 시 사용).
  Future<bool> openAppSettings() async {
    try {
      return await Geolocator.openAppSettings();
    } catch (e) {
      return false;
    }
  }

  /// 현재 위치를 가져옵니다.
  ///
  /// 권한이 없거나 위치 서비스가 비활성화된 경우 null을 반환합니다.
  Future<Position?> getCurrentPosition() async {
    try {
      final hasPermission = await checkPermission();
      if (!hasPermission) return null;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 10),
        ),
      );

      return position;
    } catch (e) {
      return null;
    }
  }

  /// 마지막으로 알려진 위치를 가져옵니다.
  ///
  /// GPS를 활성화하지 않아도 캐시된 위치를 반환할 수 있습니다.
  Future<Position?> getLastKnownPosition() async {
    try {
      final hasPermission = await checkPermission();
      if (!hasPermission) return null;

      return await Geolocator.getLastKnownPosition();
    } catch (e) {
      return null;
    }
  }
}
