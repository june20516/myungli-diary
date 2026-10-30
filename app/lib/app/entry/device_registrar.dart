import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myungli_diary/app/entry/entry_providers.dart';
import 'package:myungli_diary/app/entry/entry_state.dart';
import 'package:myungli_diary/core/api/gen/model/notification_setting.dart';
import 'package:myungli_diary/core/platform/crash_reporter.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';
import 'package:myungli_diary/core/storage/device_flags.dart';
import 'package:myungli_diary/features/onboarding/application/notify_ask_controller.dart';
import 'package:myungli_diary/features/profile/application/profile_providers.dart';
import 'package:uuid/uuid.dart';

/// 알림 기기 등록 시점과 로그아웃 때 해제를 맡습니다(#347 ②, 계약 `registerDevice`·
/// `deleteDevice`).
///
/// 처음 등록은 notify-ask와 설정이 사용자 동작으로 하고, 여기서는 이미 알림을 켠 계정의
/// 기기를 실행 때와 FCM 토큰이 바뀔 때 다시 등록합니다. 호출은 하나씩 차례로 돌고, 실패는
/// 던지지 않고 예상 밖 오류만 요약 보고합니다(D64).
final class DeviceRegistrar {
  /// [_ref]로 저장소와 상태를 읽습니다.
  new(this._ref);

  final Ref _ref;
  Future<void> _queue = Future.value();

  /// 앞서 건 동기화와 해제가 모두 끝나면 완료됩니다.
  Future<void> get idle => _queue;

  /// 로그인, 약관 동의를 마친 상태(진입 `ready`)이고 프로필 알림이 켜져 있으며 토큰이
  /// 있으면 지금 토큰을 등록합니다. 이번 실행에서 같은 토큰을 이미 등록했으면 건너뜁니다.
  /// 돌려받은 id가 전에 저장된 id와 다르면 이전 id를 해제합니다(앱이 꺼진 사이 토큰이
  /// 바뀐 경우 포함).
  Future<void> sync() => _enqueue(_sync);

  /// 로그아웃 전에 부릅니다. 저장된 기기 id가 있으면 해제하고, 성공 여부와 상관없이 지웁니다.
  Future<void> releaseForSignOut() => _enqueue(_release);

  Future<void> _sync() async {
    if (_ref.read(entryProvider) != EntryState.ready) return;
    final profile = await _ref.read(cachedProfileProvider.future);
    if (profile?.notification.status != NotificationSettingStatusEnum.enabled) {
      return;
    }
    final token = await _ref.read(pushMessagingProvider).token();
    final devices = _ref.read(deviceRepositoryProvider);
    if (token == null || token == devices.lastRegisteredToken) return;
    final flags = _ref.read(deviceFlagsStoreProvider);
    final previous = await flags.readString(registeredDeviceIdKey);
    final device = await devices.register(
      fcmToken: token,
      platform: devicePlatformOf(_ref.read(targetPlatformProvider)),
      // 실행이나 토큰 변경 하나마다 새 키입니다. 같은 토큰이면 server가 같은 id로 200입니다.
      idempotencyKey: const Uuid().v4(),
    );
    if (previous != null && previous != device.id) {
      await devices.delete(previous);
    }
  }

  Future<void> _release() async {
    final flags = _ref.read(deviceFlagsStoreProvider);
    final devices = _ref.read(deviceRepositoryProvider);
    final id = await flags.readString(registeredDeviceIdKey);
    devices.lastRegisteredToken = null;
    if (id == null) return;
    try {
      await devices.delete(id);
    } finally {
      await flags.remove(registeredDeviceIdKey);
    }
  }

  Future<void> _enqueue(Future<void> Function() step) {
    final next = _queue.then((_) => _guard(step));
    _queue = next;
    return next;
  }

  Future<void> _guard(Future<void> Function() step) async {
    try {
      await step();
    } on Object catch (error, stack) {
      recordUnlessAppError(_ref.read(crashReporterProvider), error, stack);
    }
  }
}

/// 진입이 `ready`가 될 때와 FCM 토큰이 바뀔 때 [DeviceRegistrar.sync]를 돌립니다. 앱 루트가
/// 붙들어 둡니다.
final deviceRegistrarProvider = Provider<DeviceRegistrar>((ref) {
  final registrar = DeviceRegistrar(ref);
  ref.listen(entryProvider, (previous, next) {
    if (next == EntryState.ready && previous != EntryState.ready) {
      unawaited(registrar.sync());
    }
  }, fireImmediately: true);
  final subscription = ref
      .watch(pushMessagingProvider)
      .tokenRefreshes
      .listen((_) => unawaited(registrar.sync()));
  ref.onDispose(subscription.cancel);
  return registrar;
});
