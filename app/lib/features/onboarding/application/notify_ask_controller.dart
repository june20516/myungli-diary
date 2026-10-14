import 'dart:async';

import 'package:flutter/material.dart' show TargetPlatform, TimeOfDay;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myungli_diary/app/entry/entry_providers.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/gen/model/device.dart';
import 'package:myungli_diary/core/api/gen/model/device_platform.dart';
import 'package:myungli_diary/core/api/gen/model/notification_setting.dart';
import 'package:myungli_diary/core/api/gen/model/profile_patch.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';
import 'package:myungli_diary/core/storage/device_flags.dart';
import 'package:myungli_diary/features/onboarding/data/device_repository.dart';
import 'package:myungli_diary/features/profile/application/profile_providers.dart';
import 'package:uuid/uuid.dart';

/// 기기 등록 저장소.
final deviceRepositoryProvider = Provider<DeviceRepository>(
  (ref) => DeviceRepository(
    ref.watch(restClientProvider),
    ref.watch(deviceFlagsStoreProvider),
  ),
);

/// 알림 시각을 계약의 `HH:MM` 문자열로 만듭니다.
String formatNotificationTime(TimeOfDay time) =>
    '${time.hour.toString().padLeft(2, '0')}:'
    '${time.minute.toString().padLeft(2, '0')}';

/// notify-ask 화면의 동작입니다(D18 ⑨, 결정 A17).
///
/// * 허락: 권한 요청 → 허락이면 기기 토큰을 등록(`registerDevice`)하고 `enabled`와 시각을
///   저장합니다. 거절하거나 토큰을 받지 못하면 `disabled`를 저장합니다.
/// * 건너뛰기: 권한을 묻지 않고 `disabled`를 저장합니다.
///
/// 저장에 성공하면 알림 허락 대기 플래그를 끄고 **진입을 다시 계산**합니다. 이동은 라우터
/// redirect가 정합니다(광고 동의 → today). 실패하면 플래그를 그대로 두고 오류를 돌려줍니다.
///
/// `Idempotency-Key`는 허락 동작 하나마다 하나이고, 실패 뒤 같은 토큰으로 다시 누르면
/// 같은 키를 씁니다. 이미 등록한 기기는 다시 등록하지 않습니다. 처리 중에 다시 부르면 새
/// 요청 없이 진행 중인 시도의 결과를 돌려줍니다.
class NotifyAskController extends Notifier<void> {
  @override
  void build() {}

  Future<AppError?>? _inFlight;

  /// 등록에 쓴 토큰과 그 요청의 키. 같은 토큰의 재시도가 같은 키를 쓰게 둡니다.
  ({String token, String key})? _registerKey;

  /// 이번 화면에서 등록을 마친 기기. 프로필 저장만 실패했을 때 다시 등록하지 않게 합니다.
  Device? _registered;

  /// 알림을 켜고 [time]에 받습니다. 실패하면 그 오류를, 아니면 null을 돌려줍니다.
  Future<AppError?> allow(TimeOfDay time) => _run(() => _allow(time));

  /// 알림을 받지 않고 넘어갑니다. 실패하면 그 오류를, 아니면 null을 돌려줍니다.
  Future<AppError?> skip() => _run(_saveDisabled);

  Future<AppError?> _run(Future<void> Function() action) {
    final running = _inFlight;
    if (running != null) {
      return running;
    }
    final attempt = _guard(action).whenComplete(() => _inFlight = null);
    _inFlight = attempt;
    return attempt;
  }

  Future<AppError?> _guard(Future<void> Function() action) async {
    try {
      await action();
      return null;
    } on AppError catch (error) {
      return error;
    } on Object catch (error) {
      // 플랫폼 SDK 오류 등. 원인은 돌려 주고 화면은 일반 안내를 보입니다.
      return UnexpectedError(error);
    }
  }

  Future<void> _allow(TimeOfDay time) async {
    final push = ref.read(pushMessagingProvider);
    if (!await push.requestPermission()) {
      await _saveDisabled();
      return;
    }
    final token = await push.token();
    if (token == null) {
      // 허락했지만 토큰을 받지 못하면 보낼 곳이 없어 끈 것으로 저장합니다.
      await _saveDisabled();
      return;
    }
    if (_registered == null) {
      var registerKey = _registerKey;
      if (registerKey == null || registerKey.token != token) {
        registerKey = (token: token, key: const Uuid().v4());
        _registerKey = registerKey;
      }
      _registered = await ref
          .read(deviceRepositoryProvider)
          .register(
            fcmToken: token,
            platform: _platformOf(ref.read(targetPlatformProvider)),
            idempotencyKey: registerKey.key,
          );
    }
    await _saveAndFinish(
      NotificationSetting(
        status: NotificationSettingStatusEnum.enabled,
        time: formatNotificationTime(time),
      ),
    );
  }

  Future<void> _saveDisabled() => _saveAndFinish(
    NotificationSetting(status: NotificationSettingStatusEnum.disabled),
  );

  Future<void> _saveAndFinish(NotificationSetting setting) async {
    // 진입 갱신으로 화면이 닫혀 이 controller가 버려져도 끝맺도록 의존성을 먼저 잡아 둡니다.
    final profiles = ref.read(profileRepositoryProvider);
    final flags = ref.read(deviceFlagsStoreProvider);
    final entry = ref.read(entryStateProvider.notifier);
    await profiles.update(ProfilePatch(notification: setting));
    await flags.writeBool(notifyAskPendingKey, value: false);
    await entry.refresh();
  }
}

DevicePlatform _platformOf(TargetPlatform platform) => switch (platform) {
  TargetPlatform.iOS => DevicePlatform.ios,
  TargetPlatform.android => DevicePlatform.android,
  _ => throw UnsupportedError('푸시 알림은 iOS와 Android만 지원합니다.'),
};

/// notify-ask 화면 동작. 화면이 보이는 동안만 둡니다.
final NotifierProvider<NotifyAskController, void> notifyAskControllerProvider =
    NotifierProvider.autoDispose<NotifyAskController, void>(
      NotifyAskController.new,
    );
