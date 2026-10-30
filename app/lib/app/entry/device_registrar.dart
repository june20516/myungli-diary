import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myungli_diary/app/entry/entry_providers.dart';
import 'package:myungli_diary/app/entry/entry_state.dart';
import 'package:myungli_diary/core/platform/crash_reporter.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';
import 'package:myungli_diary/core/storage/device_flags.dart';
import 'package:myungli_diary/features/onboarding/application/notify_ask_controller.dart';
import 'package:uuid/uuid.dart';

/// 알림 기기 등록 시점과 로그아웃 때 해제를 맡습니다(#347 ②, 계약 `registerDevice`·
/// `deleteDevice`).
///
/// 로그인한 기기를 실행 때와 FCM 토큰이 바뀔 때 등록합니다(계약: "앱을 실행할 때와 FCM
/// 토큰이 바뀔 때"). 알림을 보낼지는 server가 프로필 알림 설정으로 거르므로(S13) 여기서는
/// 프로필을 보지 않습니다. 사본을 받으면 앱 언어와 시간대처럼 사본을 따르는 상태가 화면과
/// 상관없이 바뀌기 때문입니다. 호출은 하나씩 차례로 돌고, 실패는 던지지 않고 예상 밖 오류만
/// 요약 보고합니다(D64).
final class DeviceRegistrar {
  /// [_ref]로 저장소와 상태를 읽습니다.
  new(this._ref);

  final Ref _ref;
  Future<void> _queue = Future.value();

  /// 로그아웃 해제를 부른 뒤 진입이 `ready`를 벗어날 때까지 참입니다. 그사이 대기 중이던
  /// 동기화와 토큰 변경이 해제한 기기를 다시 등록하지 않게 합니다.
  bool _signingOut = false;

  /// 앞서 건 동기화와 해제가 모두 끝나면 완료됩니다.
  Future<void> get idle => _queue;

  /// 로그인, 약관 동의를 마친 상태(진입 `ready`)이고 OS 알림 권한이 허락돼 있으며 토큰이
  /// 있으면 지금 토큰을 등록합니다. 이번 실행에서 같은 토큰을 이미 등록했고 저장된 id가
  /// 있으면 건너뜁니다. 돌려받은 id가 전에 저장된 id와 다르면 이전 id를 해제합니다(앱이
  /// 꺼진 사이 토큰이 바뀐 경우 포함). 이 해제가 실패하면 저장 키가 이미 새 id라 다시 해제할
  /// 길이 없습니다. 이전 토큰은 무효라 그 기기로 알림이 가지 않으므로 그대로 둡니다.
  Future<void> sync() => _enqueue(_sync);

  /// 로그아웃 전에 부릅니다. 저장된 기기 id가 있으면 해제하고, 성공 여부와 상관없이 지웁니다.
  /// 부른 뒤로는 진입이 `ready`를 벗어날 때까지 동기화하지 않습니다.
  Future<void> releaseForSignOut() {
    _signingOut = true;
    return _enqueue(_release);
  }

  /// 진입이 바뀔 때 provider가 부릅니다.
  void _onEntry(EntryState? previous, EntryState? next) {
    if (next != EntryState.ready) {
      _signingOut = false;
    } else if (previous != EntryState.ready) {
      unawaited(sync());
    }
  }

  Future<void> _sync() async {
    if (_signingOut || _ref.read(entryProvider) != EntryState.ready) return;
    final push = _ref.read(pushMessagingProvider);
    // 알림 권한을 거절했거나 아직 묻지 않은 기기는 등록하지 않습니다(notify-ask, 설정의
    // 거절과 같은 결과). 다시 로그인이나 재설치 뒤에도 권한은 기기에 남아 있습니다.
    if (!await push.hasPermission()) return;
    final token = await push.token();
    if (token == null) return;
    final devices = _ref.read(deviceRepositoryProvider);
    final flags = _ref.read(deviceFlagsStoreProvider);
    final previous = await flags.readString(registeredDeviceIdKey);
    if (previous != null && token == devices.lastRegisteredToken) return;
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
/// 붙들어 둡니다(`_onEntry`는 같은 라이브러리라 여기서 넘깁니다).
final deviceRegistrarProvider = Provider<DeviceRegistrar>((ref) {
  final registrar = DeviceRegistrar(ref);
  ref.listen<EntryState?>(
    entryProvider,
    registrar._onEntry,
    fireImmediately: true,
  );
  final subscription = ref
      .watch(pushMessagingProvider)
      .tokenRefreshes
      .listen((_) => unawaited(registrar.sync()));
  ref.onDispose(subscription.cancel);
  return registrar;
});
