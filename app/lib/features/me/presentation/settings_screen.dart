import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:myungli_diary/app/entry/entry_providers.dart';
import 'package:myungli_diary/app/router/app_router.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/gen/model/ad_free.dart';
import 'package:myungli_diary/core/api/gen/model/city.dart';
import 'package:myungli_diary/core/api/gen/model/language.dart';
import 'package:myungli_diary/core/api/gen/model/notification_setting.dart';
import 'package:myungli_diary/core/api/gen/model/profile.dart';
import 'package:myungli_diary/core/clock/clock.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/error_messages.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/action/settings_row.dart';
import 'package:myungli_diary/design/components/feedback/dialog.dart';
import 'package:myungli_diary/design/components/feedback/toast.dart';
import 'package:myungli_diary/design/components/frame/app_bar.dart';
import 'package:myungli_diary/design/components/frame/sheet.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';
import 'package:myungli_diary/features/me/application/settings_controller.dart';
import 'package:myungli_diary/features/me/presentation/settings_sheets.dart';
import 'package:myungli_diary/features/profile/application/profile_providers.dart';

/// IA `settings`의 출구 대상. `welcome`은 로그아웃 뒤 진입이 다시 계산돼 라우터 redirect가
/// 보내는 곳이고, `birthplace`는 언어 변경 뒤 출생지 안내에서 엽니다.
const Set<String> settingsExits = {
  ScreenIds.adFree,
  ScreenIds.profileEdit,
  ScreenIds.birthplace,
  ScreenIds.calcBasis,
  ScreenIds.accountDelete,
  ScreenIds.legal,
  ScreenIds.welcome,
};

/// 알림 값 글자: 켜짐이면 그 언어의 시각(예 "오전 8:00"), 아니면 "꺼짐"입니다.
String notificationLabel(AppLocalizations l10n, NotificationSetting setting) {
  final time = notifyTimeOf(setting.time);
  if (setting.status != NotificationSettingStatusEnum.enabled || time == null) {
    return l10n.settingsNotifyOff;
  }
  return DateFormat.jm(l10n.localeName)
      .format(DateTime(2000, 1, 1, time.hour, time.minute));
}

/// 광고 제거 줄의 남은 기간 글자(`settingsAdFreeLabelActive`). 활성이 아니면 null입니다.
///
/// 만료 시각(UTC)을 프로필 시간대의 날짜로 보입니다.
String? adFreeLabel(AppLocalizations l10n, AdFree? adFree, String timezone) {
  final expiresAt = adFree?.expiresAt;
  if (adFree == null || !adFree.active || expiresAt == null) {
    return null;
  }
  final local = localTimeIn(expiresAt, timezone);
  final date = DateFormat.yMMMd(l10n.localeName)
      .format(DateTime(local.year, local.month, local.day));
  return l10n.settingsAdFreeLabelActive(date);
}

/// 설정(`settings`, 결정 A59·A60·A63, D79).
///
/// 묶음 네 개(`settings-row`): ① 알림 시각·언어(값 줄, 시트를 엶) ② 광고 제거(활성이면 만료
/// 날짜) ③ 정보 수정·계산 기준·약관·정책 ④ 로그아웃·계정 삭제(`destructive`). 기본 깊이 줄은
/// 없습니다(D79).
///
/// * 알림 시각·언어 값은 프로필 사본(없으면 `getProfile`로 받음)입니다. 받는 동안 그 두 줄은 값
///   없이 비활성이고, 받지 못하면 오류 toast를 보이고 두 줄 중 하나를 누르면 다시 받습니다.
///   저장 중에는 그 줄이 비활성이고, 실패하면 오류 toast와 이전 값입니다.
/// * 시트·다음 화면이 열리는 동안(닫히기 전) 다른 줄을 다시 눌러도 또 열지 않고, 로그아웃
///   중에는 모든 줄이 비활성입니다.
/// * 언어를 한국어가 아닌 말로 바꾸는 데 성공하고 출생지를 묻지 않았으면 출생지 안내 시트를
///   띄웁니다. 버튼은 `birthplace` 수정 모드를 열고, 고른 도시는 무거운 변경이라(A6) 저장하지
///   않고 `profile-edit`에 `extra`로 넘깁니다(확인 창은 그 화면이 띄움).
/// * 로그아웃은 확인 창(`settings.logout.confirm`) 뒤 `revokeAndSignOut`입니다.
class SettingsScreen extends ConsumerStatefulWidget {
  /// settings 화면을 만듭니다.
  const new({super.key});

  /// 알림 시각 줄.
  static const Key notifyRowKey = ValueKey('settings.row.notify');

  /// 언어 줄.
  static const Key languageRowKey = ValueKey('settings.row.language');

  /// 광고 제거 줄.
  static const Key adFreeRowKey = ValueKey(SlotIds.settingsAdFreeLabel);

  /// 정보 수정 줄.
  static const Key profileEditRowKey = ValueKey('settings.row.profile-edit');

  /// 계산 기준 줄.
  static const Key calcBasisRowKey = ValueKey('settings.row.calc-basis');

  /// 약관·정책 줄.
  static const Key legalRowKey = ValueKey('settings.row.legal');

  /// 로그아웃 줄.
  static const Key logoutRowKey = ValueKey('settings.row.logout');

  /// 계정 삭제 줄.
  static const Key accountDeleteRowKey = ValueKey(
    'settings.row.account-delete',
  );

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  SettingsController get _controller =>
      ref.read(settingsControllerProvider.notifier);

  /// 줄을 눌러 연 시트·화면이 아직 닫히지 않았는지. 빠른 두 번 누르기로 두 번 열지 않게 합니다.
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    // 프로필을 받지 못하면 이유를 알립니다(다시 받을 때마다 새 오류면 다시 알림).
    ref.listenManual<AsyncValue<Profile?>>(profileProvider, (previous, next) {
      final error = next.error;
      if (next.isLoading ||
          error == null ||
          identical(error, previous?.error)) {
        return;
      }
      showMyungliToast(
        context,
        errorMessage(
          AppLocalizations.of(context),
          error is AppError ? error : UnexpectedError(error),
        ),
      );
    });
  }

  /// [action](시트·화면 열기와 그 뒤 처리)이 끝날 때까지 다른 열기를 받지 않습니다.
  void _guarded(Future<void> Function() action) {
    if (_opening) return;
    _opening = true;
    unawaited(action().whenComplete(() => _opening = false));
  }

  /// 받지 못한 프로필을 다시 받습니다.
  void _reloadProfile() => ref.invalidate(profileProvider);

  /// [action]을 기다리고, 실패하면 오류 toast를 보입니다. 성공하면 true입니다.
  Future<bool> _save(Future<void> Function() action) async {
    try {
      await action();
      return true;
    } on AppError catch (error) {
      if (mounted) {
        showMyungliToast(
          context,
          errorMessage(AppLocalizations.of(context), error),
        );
      }
      return false;
    }
  }

  Future<void> _editNotification(Profile profile) async {
    final chosen = await showMyungliSheet<NotificationSetting>(
      context,
      size: SheetSize.half,
      semanticLabel: AppLocalizations.of(context).settingsNotifyLabel,
      builder: (_) => NotifyTimeSheet(initial: profile.notification),
    );
    if (chosen == null || !mounted) return;
    await _save(() => _controller.setNotification(chosen));
  }

  Future<void> _editLanguage(Profile profile) async {
    final chosen = await showMyungliSheet<Language>(
      context,
      size: SheetSize.half,
      semanticLabel: AppLocalizations.of(context).settingsLanguageLabel,
      builder: (_) => LanguageSheet(current: profile.language),
    );
    if (chosen == null || !mounted) return;
    // 언어만 바꾸므로 출생지는 바꾸기 전 사본 그대로입니다.
    final place = profile.birth.place.status;
    final saved = await _save(() => _controller.setLanguage(chosen));
    // 저장이 실패하면 언어도 안내도 그대로입니다(Review Focus 3).
    if (!saved || !mounted || !offersBirthplaceNotice(chosen, place)) return;
    await _offerBirthplace();
  }

  Future<void> _offerBirthplace() async {
    final enter = await showMyungliSheet<bool>(
      context,
      size: SheetSize.half,
      semanticLabel: AppLocalizations.of(context).birthplaceBarTitle,
      builder: (_) => const BirthplaceNoticeSheet(),
    );
    if (enter != true || !mounted) return;
    final city = await context.push<City>(editModePathOf(ScreenIds.birthplace));
    if (city == null || !mounted) return;
    // 출생지는 무거운 변경(A6)이라 여기서 저장하지 않고, 확인 창을 띄우는 정보 수정에 넘깁니다.
    await context.push<void>(pathOf(ScreenIds.profileEdit), extra: city);
  }

  Future<void> _logout() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showMyungliDialog(
      context,
      variant: DialogVariant.confirm,
      title: l10n.settingsLogoutConfirm,
      confirm: l10n.settingsLogoutConfirmLogout,
      cancel: l10n.settingsLogoutConfirmCancel,
      identifier: SlotIds.settingsLogoutConfirm,
    );
    if (!confirmed || !mounted) return;
    // 성공하면 진입이 다시 계산돼 라우터가 welcome으로 보냅니다.
    await _save(_controller.signOut);
  }

  void _open(String screenId) =>
      _guarded(() => context.push<void>(pathOf(screenId)));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final saving = ref.watch(settingsControllerProvider);
    final profileState = ref.watch(profileProvider);
    final profile = profileState.value;
    final profileFailed =
        profile == null && profileState.hasError && !profileState.isLoading;
    final adFree = adFreeLabel(
      l10n,
      ref.watch(meProvider)?.adFree,
      ref.watch(profileTimezoneProvider),
    );
    final bottom = MediaQuery.viewPaddingOf(context).bottom;

    // 로그아웃 중에는 모든 줄, 저장 중에는 그 값의 줄이 비활성입니다.
    final signingOut = saving.contains(SettingsField.signOut);
    VoidCallback? whenIdle(VoidCallback action, {SettingsField? field}) =>
        signingOut || (field != null && saving.contains(field)) ? null : action;

    /// 프로필 값 줄: 값이 있으면 [edit], 받지 못했으면 다시 받기, 받는 중이면 비활성.
    VoidCallback? profileRow(
      SettingsField field,
      Future<void> Function(Profile profile) edit,
    ) {
      if (profile != null) {
        return whenIdle(() => _guarded(() => edit(profile)), field: field);
      }
      return profileFailed ? whenIdle(_reloadProfile) : null;
    }

    return Semantics(
      identifier: ScreenIds.settings,
      child: Scaffold(
        key: const ValueKey(ScreenIds.settings),
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MyungliAppBar.inner(
                title: l10n.settingsBarTitle,
                titleIdentifier: SlotIds.settingsBarTitle,
                // 스택 바닥(딥링크·복원)이면 돌아갈 곳이 없어 숨깁니다.
                showBack: MyungliAppBar.canGoBack(context),
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    Space.s20,
                    Space.s8,
                    Space.s20,
                    Space.s24 + bottom,
                  ),
                  children: [
                    SettingsGroup(
                      children: [
                        SettingsRow(
                          key: SettingsScreen.notifyRowKey,
                          variant: SettingsRowVariant.value,
                          label: l10n.settingsNotifyLabel,
                          value: profile == null
                              ? null
                              : notificationLabel(l10n, profile.notification),
                          onTap: profileRow(
                            SettingsField.notification,
                            _editNotification,
                          ),
                        ),
                        SettingsRow(
                          key: SettingsScreen.languageRowKey,
                          variant: SettingsRowVariant.value,
                          label: l10n.settingsLanguageLabel,
                          value: profile == null
                              ? null
                              : languageNames[profile.language],
                          onTap: profileRow(
                            SettingsField.language,
                            _editLanguage,
                          ),
                        ),
                      ],
                    ),
                    SettingsGroup(
                      children: [
                        SettingsRow(
                          key: SettingsScreen.adFreeRowKey,
                          identifier: SlotIds.settingsAdFreeLabel,
                          variant: adFree == null
                              ? SettingsRowVariant.navigate
                              : SettingsRowVariant.value,
                          label: l10n.settingsAdFreeLabel,
                          value: adFree,
                          onTap: whenIdle(() => _open(ScreenIds.adFree)),
                        ),
                      ],
                    ),
                    SettingsGroup(
                      children: [
                        // 다른 화면 제목과 같은 줄 이름은 그 화면 제목 원고를 씁니다(A64).
                        SettingsRow(
                          key: SettingsScreen.profileEditRowKey,
                          variant: SettingsRowVariant.navigate,
                          label: l10n.profileEditBarTitle,
                          onTap: whenIdle(() => _open(ScreenIds.profileEdit)),
                        ),
                        SettingsRow(
                          key: SettingsScreen.calcBasisRowKey,
                          variant: SettingsRowVariant.navigate,
                          label: l10n.calcBasisBarTitle,
                          onTap: whenIdle(() => _open(ScreenIds.calcBasis)),
                        ),
                        SettingsRow(
                          key: SettingsScreen.legalRowKey,
                          variant: SettingsRowVariant.navigate,
                          label: l10n.legalBarTitle,
                          onTap: whenIdle(() => _open(ScreenIds.legal)),
                        ),
                      ],
                    ),
                    SettingsGroup(
                      children: [
                        SettingsRow(
                          key: SettingsScreen.logoutRowKey,
                          variant: SettingsRowVariant.destructive,
                          label: l10n.settingsLogoutLabel,
                          onTap: whenIdle(() => _guarded(_logout)),
                        ),
                        SettingsRow(
                          key: SettingsScreen.accountDeleteRowKey,
                          variant: SettingsRowVariant.destructive,
                          label: l10n.accountDeleteBarTitle,
                          onTap: whenIdle(() => _open(ScreenIds.accountDelete)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
