import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myungli_diary/app/entry/entry_providers.dart';
import 'package:myungli_diary/app/entry/sign_out.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/gen/model/birth_place.dart';
import 'package:myungli_diary/core/api/gen/model/language.dart';
import 'package:myungli_diary/core/api/gen/model/notification_setting.dart';
import 'package:myungli_diary/core/api/gen/model/profile_patch.dart';
import 'package:myungli_diary/core/platform/crash_reporter.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';
import 'package:myungli_diary/core/storage/device_flags.dart';
import 'package:myungli_diary/features/onboarding/application/notify_ask_controller.dart';
import 'package:myungli_diary/features/profile/application/profile_providers.dart';
import 'package:uuid/uuid.dart';

/// 설정에서 저장하는 값. 저장 중인 값의 줄은 비활성입니다(A59).
enum SettingsField {
  /// 아침 알림(`Profile.notification`).
  notification,

  /// 앱 언어(`Profile.language`).
  language,

  /// 로그아웃.
  signOut,
}

/// 언어를 [language]로 바꾼 뒤 출생지 안내 시트를 띄울지(A60, D29).
///
/// 한국어가 아닌 언어로 바꾸고 출생지를 아직 묻지 않았을 때(`not_asked`)만입니다. 건너뛰었거나
/// (`skipped`) 이미 도시를 골랐으면 다시 묻지 않습니다.
bool offersBirthplaceNotice(Language language, BirthPlaceStatusEnum place) =>
    language != Language.ko && place == BirthPlaceStatusEnum.notAsked;

/// `settings` 화면의 저장 동작(결정 A59·A60·A63). 상태는 저장 중인 값입니다.
///
/// * 저장은 `updateProfile`(PATCH, 그 필드만)이고 응답이 새 사본이 됩니다. 사본이 바뀌면 화면 값과
///   앱 언어(`localeProvider`)가 따라 바뀝니다.
/// * 같은 값의 저장이 진행 중이면 다시 부르지 않고 진행 중인 시도를 돌려줍니다(두 번 누르기).
/// * 실패는 [AppError]로 던지고 사본은 그대로라 화면은 이전 값입니다. 예상 밖 오류(플랫폼 SDK)는
///   요약만 crash 기록에 남기고(D64) [UnexpectedError]로 던집니다.
class SettingsController extends Notifier<Set<SettingsField>> {
  @override
  Set<SettingsField> build() => const {};

  final Map<SettingsField, Future<void>> _inFlight = {};

  /// 아침 알림을 [setting]으로 저장합니다.
  ///
  /// 꺼진 상태(`not_asked`·`disabled`)에서 켜면 OS 알림 권한을 먼저 묻습니다(계획 2와 같은
  /// `PushMessaging`). 거절하거나 기기 토큰을 받지 못하면 `disabled`로 저장하고, 허락했고 이
  /// 기기를 아직 등록하지 않았으면 기기를 등록(`registerDevice`)한 뒤 저장합니다. 이미 켜진 채
  /// 시각만 바꾸면 권한을 다시 묻지 않습니다.
  Future<void> setNotification(NotificationSetting setting) =>
      _run(SettingsField.notification, () async {
        final profiles = ref.read(profileRepositoryProvider);
        final current = (await profiles.cached())?.notification.status;
        final turningOn =
            setting.status == NotificationSettingStatusEnum.enabled &&
            current != NotificationSettingStatusEnum.enabled;
        final target = turningOn ? await _enablePush(setting) : setting;
        await profiles.update(ProfilePatch(notification: target));
      });

  /// 앱 언어를 [language]로 저장합니다. 성공하면 앱 전체가 그 언어로 다시 그려집니다(A60).
  Future<void> setLanguage(Language language) => _run(
    SettingsField.language,
    () => ref
        .read(profileRepositoryProvider)
        .update(ProfilePatch(language: language)),
  );

  /// server에 refresh token 폐기를 시도한 뒤 로컬에서 로그아웃합니다(A63). 진입이 다시 계산돼
  /// 라우터가 `welcome`으로 보냅니다.
  Future<void> signOut() => _run(
    SettingsField.signOut,
    () => revokeAndSignOut(
      api: ref.read(restClientProvider),
      tokens: ref.read(tokenStoreProvider),
    ),
  );

  Future<void> _run(SettingsField field, Future<void> Function() action) {
    final running = _inFlight[field];
    if (running != null) {
      return running;
    }
    state = {...state, field};
    final attempt = _guard(action).whenComplete(() {
      // `remove`는 지운 Future를 돌려주므로 버리는 Future가 없게 removeWhere를 씁니다.
      _inFlight.removeWhere((key, _) => key == field);
      if (ref.mounted) {
        state = {...state}..remove(field);
      }
    });
    _inFlight[field] = attempt;
    return attempt;
  }

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } on AppError {
      rethrow;
    } on Object catch (error, stack) {
      ref.read(crashReporterProvider).record(CrashSummary.from(error), stack);
      throw UnexpectedError(error);
    }
  }

  /// 알림 권한을 묻고 기기를 등록해 저장할 값을 정합니다. 켤 수 없으면 `disabled`입니다.
  Future<NotificationSetting> _enablePush(NotificationSetting setting) async {
    final disabled = NotificationSetting(
      status: NotificationSettingStatusEnum.disabled,
    );
    final push = ref.read(pushMessagingProvider);
    if (!await push.requestPermission()) {
      return disabled;
    }
    final token = await push.token();
    if (token == null) {
      // 허락했지만 보낼 곳(토큰)이 없으면 끈 것으로 저장합니다(notify-ask와 같음).
      return disabled;
    }
    final flags = ref.read(deviceFlagsStoreProvider);
    if (await flags.readString(registeredDeviceIdKey) == null) {
      await ref
          .read(deviceRepositoryProvider)
          .register(
            fcmToken: token,
            platform: devicePlatformOf(ref.read(targetPlatformProvider)),
            // 켜기 동작 하나마다 새 키입니다. 실패하면 다시 누를 때 새 동작으로 다시 등록합니다.
            idempotencyKey: const Uuid().v4(),
          );
    }
    return setting;
  }
}

/// `settings` 화면의 저장 동작. 화면이 보이는 동안만 둡니다.
final NotifierProvider<SettingsController, Set<SettingsField>>
settingsControllerProvider =
    NotifierProvider.autoDispose<SettingsController, Set<SettingsField>>(
      SettingsController.new,
    );
