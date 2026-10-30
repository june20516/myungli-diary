import 'package:dio/dio.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/gen/api/default_api.dart';
import 'package:myungli_diary/core/api/gen/model/device.dart';
import 'package:myungli_diary/core/api/gen/model/device_input.dart';
import 'package:myungli_diary/core/api/gen/model/device_platform.dart';
import 'package:myungli_diary/core/storage/device_flags.dart';

/// 푸시 알림 기기 등록·해제 server 요청입니다(`registerDevice`, `deleteDevice`).
///
/// 실패는 [AppError]입니다. 같은 `Idempotency-Key`의 요청이 진행 중이면 409
/// `idempotency.in_progress`, 같은 키에 다른 본문이면 422 `idempotency.mismatch`입니다.
final class DeviceRepository {
  /// [_api]로 요청하고 성공한 기기 id를 [_flags]에 둡니다.
  new(this._api, this._flags);

  final DefaultApi _api;
  final DeviceFlagsStore _flags;

  /// 이번 실행에서 마지막으로 등록에 성공한 토큰. 같은 토큰을 실행 중에 다시 등록하지
  /// 않게 `DeviceRegistrar`가 봅니다(notify-ask, 설정이 막 등록한 뒤 등).
  String? lastRegisteredToken;

  /// 기기 토큰 [fcmToken]을 등록하고 기기 id를 [registeredDeviceIdKey]에 저장합니다.
  ///
  /// [idempotencyKey]는 사용자 동작 하나마다 하나이고, 재시도에도 같은 값을 넘깁니다.
  Future<Device> register({
    required String fcmToken,
    required DevicePlatform platform,
    required String idempotencyKey,
  }) async {
    final Device? device;
    try {
      device = (await _api.registerDevice(
        deviceInput: DeviceInput(fcmToken: fcmToken, platform: platform),
        idempotencyKey: idempotencyKey,
      )).data;
    } on DioException catch (e) {
      throw appErrorFrom(e);
    }
    if (device == null) {
      throw UnexpectedError(StateError('빈 응답'));
    }
    await _flags.writeString(registeredDeviceIdKey, value: device.id);
    lastRegisteredToken = fcmToken;
    return device;
  }

  /// 기기 [deviceId]를 해제합니다(`deleteDevice`). 404 `device.not_found`는 이미 없는
  /// 것이라 성공으로 봅니다. 저장된 id는 건드리지 않습니다(새 등록이 이미 새 id로
  /// 덮어썼을 수 있음).
  Future<void> delete(String deviceId) async {
    try {
      await _api.deleteDevice(id: deviceId);
    } on DioException catch (e) {
      final error = appErrorFrom(e);
      if (error is ProblemError && error.code == _deviceNotFound) return;
      throw error;
    }
  }

  static const String _deviceNotFound = 'device.not_found';
}
