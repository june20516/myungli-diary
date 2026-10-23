import 'package:flutter/material.dart';
import 'package:myungli_diary/core/api/gen/model/language.dart';
import 'package:myungli_diary/core/api/gen/model/notification_setting.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/core/platform/device_locale.dart';
import 'package:myungli_diary/design/components/action/primary_button.dart';
import 'package:myungli_diary/design/components/action/settings_row.dart';
import 'package:myungli_diary/design/components/frame/sheet.dart';
import 'package:myungli_diary/design/components/input/time_picker.dart';
import 'package:myungli_diary/design/interaction/motion_prefs.dart';
import 'package:myungli_diary/design/theme/app_theme.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';
import 'package:myungli_diary/features/onboarding/application/notify_ask_controller.dart';

/// 언어마다 그 언어로 쓴 자기 이름. 번역하지 않는 고유 이름이라 코드 상수입니다(A64).
const Map<Language, String> languageNames = {
  Language.ko: '한국어',
  Language.en: 'English',
  Language.ja: '日本語',
};

/// [language]의 자기 이름. 계약에 없는 언어는 기본 언어로 봅니다(A78, [knownLanguageOf]).
String languageNameOf(Language language) =>
    languageNames[knownLanguageOf(language)]!;

/// 언어 시트에서 고를 수 있는 언어(계약이 아는 값).
final List<Language> _selectableLanguages = [
  for (final language in Language.values)
    if (language.isKnown) language,
];

/// 알림을 처음 켤 때 휠이 가리키는 시각(notify-ask와 같은 08:00).
const TimeOfDay defaultNotifyTime = TimeOfDay(hour: 8, minute: 0);

/// 꺼진 휠의 투명도(`time-picker` 모름과 같은 0.35).
const double _offOpacity = 0.35;

/// 계약의 `HH:MM`(분은 5의 배수)을 휠 값으로 읽습니다. 읽을 수 없으면 null입니다.
TimeOfDay? notifyTimeOf(String? hhmm) {
  final match = RegExp(r'^(\d{2}):(\d{2})$').firstMatch(hhmm ?? '');
  if (match == null) return null;
  final hour = int.parse(match[1]!);
  final minute = int.parse(match[2]!);
  if (hour > 23 || minute > 59) return null;
  // 휠은 5분 단위라 그 밖의 분은 아래 칸으로 맞춥니다(계약상 5의 배수).
  return TimeOfDay(hour: hour, minute: minute - minute % 5);
}

/// 알림 시각 시트(A59, `time-picker` `notify` half): 켜고 끄는 줄, 5분 단위 휠, 저장 버튼.
///
/// 저장을 누르면 고른 값을 [NotificationSetting]으로 돌려주며 닫힙니다(켜짐이면 `enabled` +
/// 시각, 꺼짐이면 `disabled`). 처음 값과 같으면 null을 돌려줘 저장하지 않습니다. 꺼져 있으면
/// 휠은 흐리게 두고 돌릴 수 없습니다. 권한 묻기와 저장은 화면(controller)이 합니다.
class NotifyTimeSheet extends StatefulWidget {
  /// 지금 값 [initial]로 시트를 만듭니다.
  const new({required this.initial, super.key = sheetKey});

  /// 시트를 찾는 테스트용 키.
  static const Key sheetKey = ValueKey('settings.notify.sheet');

  /// 저장 버튼을 찾는 테스트용 키.
  static const Key saveKey = ValueKey('settings.notify.save');

  /// 지금 알림 값.
  final NotificationSetting initial;

  @override
  State<NotifyTimeSheet> createState() => _NotifyTimeSheetState();
}

class _NotifyTimeSheetState extends State<NotifyTimeSheet> {
  late bool _on =
      widget.initial.status == NotificationSettingStatusEnum.enabled;
  late TimeOfDay _time = notifyTimeOf(widget.initial.time) ?? defaultNotifyTime;

  NotificationSetting get _chosen => _on
      ? NotificationSetting(
          status: NotificationSettingStatusEnum.enabled,
          time: formatNotificationTime(_time),
        )
      : NotificationSetting(status: NotificationSettingStatusEnum.disabled);

  bool get _changed {
    final initial = widget.initial;
    final wasOn = initial.status == NotificationSettingStatusEnum.enabled;
    if (_on != wasOn) return true;
    return _on && formatNotificationTime(_time) != initial.time;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = context.tokens;
    final duration = MotionPrefs.of(context).reduceMotion
        ? Duration.zero
        : Motion.short;
    // 글자가 커져 내용이 시트를 넘으면 휠 쪽만 스크롤하고 저장 버튼은 아래에 둡니다.
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: Space.s16),
                SheetHeading(
                  child: Text(
                    l10n.settingsNotifyLabel,
                    style: tokens.typography.title.copyWith(
                      color: tokens.colors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: Space.s12),
                SettingsGroup(
                  children: [
                    SettingsRow(
                      variant: SettingsRowVariant.toggle,
                      // 줄 이름은 notify-ask 화면 이름 원고("알림")를 다시 씁니다(A64).
                      label: l10n.notifyAskBarTitle,
                      toggled: _on,
                      onToggle: (value) => setState(() => _on = value),
                    ),
                  ],
                ),
                IgnorePointer(
                  ignoring: !_on,
                  child: AnimatedOpacity(
                    duration: duration,
                    curve: Motion.seep,
                    opacity: _on ? 1 : _offOpacity,
                    child: ExcludeSemantics(
                      excluding: !_on,
                      child: TimePicker(
                        variant: TimePickerVariant.notify,
                        value: _time,
                        onChanged: (value) => setState(() => _time = value),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Space.s20),
        PrimaryButton(
          key: NotifyTimeSheet.saveKey,
          label: l10n.onboardingSave,
          onPressed: () => Navigator.of(context).pop(_changed ? _chosen : null),
        ),
      ],
    );
  }
}

/// 언어 시트(A60): 세 언어를 `settings-row`로 늘어놓고, 누르면 그 언어를 돌려주며 닫힙니다.
///
/// 지금 언어 줄은 고를 수 없게(disabled) 둡니다. 화면의 언어 줄이 지금 값을 보이므로 시트는 바꿀
/// 곳만 엽니다.
class LanguageSheet extends StatelessWidget {
  /// 지금 언어 [current]로 시트를 만듭니다.
  const new({required this.current, super.key = sheetKey});

  /// 시트를 찾는 테스트용 키.
  static const Key sheetKey = ValueKey('settings.language.sheet');

  /// [language] 줄을 찾는 테스트용 키.
  static Key rowKey(Language language) =>
      ValueKey('settings.language.${language.value}');

  /// 지금 언어.
  final Language current;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = context.tokens;
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: Space.s16),
          SheetHeading(
            child: Text(
              l10n.settingsLanguageLabel,
              style: tokens.typography.title.copyWith(
                color: tokens.colors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: Space.s12),
          SettingsGroup(
            children: [
              for (final language in _selectableLanguages)
                // 언어 이름은 그 언어의 글꼴로 그립니다(한국어 글꼴에는 日本語 글자가 없음).
                Theme(
                  data: buildTheme(
                    brightness: Theme.of(context).brightness,
                    locale: Locale(language.value),
                  ),
                  child: SettingsRow(
                    key: rowKey(language),
                    variant: SettingsRowVariant.navigate,
                    label: languageNameOf(language),
                    onTap: language == knownLanguageOf(current)
                        ? null
                        : () => Navigator.of(context).pop(language),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 출생지 안내 시트(`settings.language.birthplace-notice`, A60·D29): 한국 밖에서 태어났으면
/// 출생지를 입력하라는 안내와 "출생지 입력하기" 버튼. 버튼을 누르면 true를 돌려주며 닫힙니다.
class BirthplaceNoticeSheet extends StatelessWidget {
  /// 안내 시트를 만듭니다.
  const new({
    super.key = const ValueKey(SlotIds.settingsLanguageBirthplaceNotice),
  });

  /// "출생지 입력하기" 버튼을 찾는 테스트용 키.
  static const Key ctaKey = ValueKey('settings.language.birthplace-notice.cta');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = context.tokens;
    return Semantics(
      identifier: SlotIds.settingsLanguageBirthplaceNotice,
      container: true,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: Space.s16),
            SheetHeading(
              child: Text(
                l10n.settingsLanguageBirthplaceNotice,
                style: tokens.typography.subtitle.copyWith(
                  color: tokens.colors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: Space.s24),
            PrimaryButton(
              key: ctaKey,
              label: l10n.settingsLanguageBirthplaceNoticeCta,
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
      ),
    );
  }
}
