import 'package:dio/dio.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/gen/api/default_api.dart';
import 'package:myungli_diary/core/api/gen/model/device.dart';
import 'package:myungli_diary/core/api/gen/model/device_input.dart';
import 'package:myungli_diary/core/api/gen/model/device_platform.dart';
import 'package:myungli_diary/core/storage/device_flags.dart';

/// 푸시 알림 기기 등록 server 요청입니다(`registerDevice`).
///
/// 실패는 [AppError]입니다. 같은 `Idempotency-Key`의 요청이 진행 중이면 409
/// `idempotency.in_progress`, 같은 키에 다른 본문이면 422 `idempotency.mismatch`입니다.
final class DeviceRepository {
  /// [_api]로 요청하고 성공한 기기 id를 [_flags]에 둡니다.
  const new(this._api, this._flags);

  final DefaultApi _api;
  final DeviceFlagsStore _flags;

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
    return device;
  }
}
