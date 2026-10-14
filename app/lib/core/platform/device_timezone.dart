import 'package:flutter_timezone/flutter_timezone.dart';

/// 기기의 현재 시간대.
abstract interface class DeviceTimezone {
  /// IANA 시간대 이름(예: `Asia/Seoul`).
  Future<String> current();
}

/// `flutter_timezone`으로 OS 설정을 읽는 실제 adapter.
final class FlutterDeviceTimezone implements DeviceTimezone {
  /// 실제 adapter를 만듭니다.
  const new();

  @override
  Future<String> current() async =>
      (await FlutterTimezone.getLocalTimezone()).identifier;
}
