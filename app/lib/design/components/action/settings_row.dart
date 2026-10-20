import 'dart:async';

import 'package:flutter/material.dart';
import 'package:myungli_diary/design/components/component_spec.dart';
import 'package:myungli_diary/design/components/sentence/press_ink_target.dart';
import 'package:myungli_diary/design/elements/app_icon.dart';
import 'package:myungli_diary/design/interaction/haptics.dart';
import 'package:myungli_diary/design/interaction/motion_prefs.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';
import 'package:phosphor_glyphs/phosphor_glyphs.dart';

const AppGlyph _caretRight = AppGlyph(
  light: PhosphorIconsLight.caretRight,
  regular: PhosphorIconsRegular.caretRight,
);

/// [SettingsRow] 변형(`settings-row` `variants`).
enum SettingsRowVariant {
  /// 다음 화면으로(오른쪽 화살표).
  navigate,

  /// 값을 고름(값 + 화살표, 시트를 엶).
  value,

  /// 켜고 끔(스위치, 화살표 없음).
  toggle,

  /// 로그아웃·계정 삭제(`mark.caution` + 굵은 글자, 화살표 없음, 빨간색 없음).
  destructive,
}

/// 설정 한 줄(`settings-row`).
///
/// 줄 전체가 하나의 눌리는 자리(`press.ink`)이고 높이는 52 이상(글자가 커지면 늘어남),
/// 좌우 16입니다.
/// 스크린리더는 "글자 + 값"을 버튼으로 읽고, `toggle`은 스위치(켜짐 상태)로 읽습니다.
///
/// * `navigate`·`value`·`destructive`는 [onTap], `toggle`은 [onToggle]을 씁니다.
///   둘 다 null이면 `disabled`(글자 `color.disabled.fg`, 누를 수 없음)입니다.
/// * `toggle`을 켜고 끌 때 selection 햅틱이 한 번 나갑니다.
class SettingsRow extends StatelessWidget {
  /// 설정 줄을 만듭니다. [value]는 `value` 변형의 값 글자, [toggled]는 `toggle`의 켜짐입니다.
  const new({
    required this.variant,
    required this.label,
    this.value,
    this.toggled = false,
    this.onTap,
    this.onToggle,
    this.identifier,
    super.key,
  }) : assert(
         variant != SettingsRowVariant.toggle || onTap == null,
         'toggle은 onToggle을 씁니다.',
       );

  /// 명세 대조용 요약.
  static const ComponentSpec spec = ComponentSpec(
    'settings-row',
    {'navigate', 'value', 'toggle', 'destructive'},
    {'pressed', 'disabled'},
  );

  /// 오른쪽 화살표를 찾는 테스트용 키.
  static const Key chevronKey = ValueKey('settings-row-chevron');

  /// 스위치를 찾는 테스트용 키.
  static const Key toggleKey = ValueKey('settings-row-toggle');

  /// 줄 최소 높이(`row.minHeight`).
  static const double minHeight = 52;

  /// 변형.
  final SettingsRowVariant variant;

  /// 줄 글자.
  final String label;

  /// `value` 변형의 값 글자. 다른 변형에서는 그리지 않습니다.
  final String? value;

  /// `toggle` 변형의 켜짐.
  final bool toggled;

  /// 눌렀을 때(`navigate`·`value`·`destructive`). null이면 disabled입니다.
  final VoidCallback? onTap;

  /// 켜고 끌 때 새 값을 줍니다(`toggle`). null이면 disabled입니다.
  final ValueChanged<bool>? onToggle;

  /// IA 슬롯 id. 있으면 Semantics `identifier`로 붙입니다.
  final String? identifier;

  bool get _enabled =>
      variant == SettingsRowVariant.toggle ? onToggle != null : onTap != null;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final enabled = _enabled;
    final destructive = variant == SettingsRowVariant.destructive;
    final labelStyle = tokens.typography.bodyUi.copyWith(
      color: enabled ? colors.textPrimary : colors.disabledFg,
      fontWeight: destructive ? FontWeight.w600 : null,
    );
    final valueText = variant == SettingsRowVariant.value ? value : null;
    final chevron =
        variant == SettingsRowVariant.navigate ||
        variant == SettingsRowVariant.value;

    final row = LayoutBuilder(
      builder: (context, constraints) => _content(
        constraints.maxWidth / 2,
        labelStyle: labelStyle,
        valueText: valueText,
        chevron: chevron,
        enabled: enabled,
        destructive: destructive,
      ),
    );

    final semanticLabel = valueText == null ? label : '$label, $valueText';
    if (variant == SettingsRowVariant.toggle) {
      return Semantics(
        identifier: identifier,
        container: true,
        toggled: toggled,
        enabled: enabled,
        label: label,
        onTap: enabled ? _toggle : null,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? _toggle : null,
          child: row,
        ),
      );
    }
    return PressInkTarget(
      semanticLabel: semanticLabel,
      onTap: onTap,
      identifier: identifier,
      inkColor: colors.textPrimary,
      borderRadius: BorderRadius.zero,
      child: row,
    );
  }

  Widget _content(
    double maxValueWidth, {
    required TextStyle labelStyle,
    required String? valueText,
    required bool chevron,
    required bool enabled,
    required bool destructive,
  }) => Builder(
    builder: (context) {
      final tokens = context.tokens;
      final colors = tokens.colors;
      return ConstrainedBox(
        constraints: const BoxConstraints(minHeight: minHeight),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Space.s16,
            vertical: Space.s12,
          ),
          child: Row(
            children: [
              if (destructive) ...[
                DefaultTextStyle.merge(
                  style: labelStyle,
                  child: const AppIcon.caution(),
                ),
                const SizedBox(width: Space.s4),
              ],
              Expanded(child: Text(label, style: labelStyle)),
              if (valueText != null) ...[
                const SizedBox(width: Space.s8),
                // 값은 오른쪽 끝에 붙고 줄 너비의 절반까지만 씁니다(넘으면 줄을 바꿈).
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxValueWidth),
                  child: Text(
                    valueText,
                    textAlign: TextAlign.end,
                    style: tokens.typography.bodyUi.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              ],
              if (chevron) ...[
                const SizedBox(width: Space.s4),
                AppIcon(
                  _caretRight,
                  key: chevronKey,
                  size: AppIconSize.inline,
                  color: colors.textSecondary,
                ),
              ],
              if (variant == SettingsRowVariant.toggle) ...[
                const SizedBox(width: Space.s8),
                _Switch(key: toggleKey, on: toggled, enabled: enabled),
              ],
            ],
          ),
        ),
      );
    },
  );

  void _toggle() {
    unawaited(Haptics.selection());
    onToggle!(!toggled);
  }
}

/// 켜고 끄는 스위치(`toggle` 부품): 켜짐 트랙 `action.primary`, 꺼짐 트랙 `line`,
/// 손잡이 `bg.sheet`.
class _Switch extends StatelessWidget {
  const new({required this.on, required this.enabled, super.key});

  final bool on;
  final bool enabled;

  static const double _width = 44;
  static const double _height = 26;
  static const double _inset = 3;

  @override
  Widget build(BuildContext context) {
    final colors = context.tokens.colors;
    final duration = MotionPrefs.of(context).reduceMotion
        ? Duration.zero
        : Motion.short;
    final track = !enabled
        ? colors.disabledFg
        : on
        ? colors.actionPrimary
        : colors.line;
    return AnimatedContainer(
      duration: duration,
      curve: Motion.seep,
      width: _width,
      height: _height,
      padding: const EdgeInsets.all(_inset),
      decoration: BoxDecoration(
        color: track,
        borderRadius: BorderRadius.circular(Radii.full),
      ),
      child: AnimatedAlign(
        duration: duration,
        curve: Motion.seep,
        alignment: on ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: _height - _inset * 2,
          height: _height - _inset * 2,
          decoration: BoxDecoration(
            color: colors.bgSheet,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

/// 설정 줄 묶음 카드(`settings-row` `group`): `bg.sheet` `radius.md`, 줄 사이 1px
/// `line`(안쪽 16), 아래로 20 띄움. [title]이 있으면 카드 위에 `caption.md`
/// `text.secondary` 묶음 제목입니다.
class SettingsGroup extends StatelessWidget {
  /// 묶음을 만듭니다.
  const new({required this.children, this.title, super.key});

  /// 묶음 안 줄들(위에서 아래).
  final List<Widget> children;

  /// 묶음 제목.
  final String? title;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final rows = <Widget>[];
    for (final (index, child) in children.indexed) {
      if (index > 0) {
        rows.add(const SettingsGroupDivider());
      }
      rows.add(child);
    }
    final heading = title;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.s20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (heading != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.s16,
                0,
                Space.s16,
                Space.s8,
              ),
              child: Semantics(
                header: true,
                child: Text(
                  heading,
                  style: tokens.typography.captionMd.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ),
            ),
          ClipRRect(
            borderRadius: BorderRadius.circular(Radii.md),
            child: ColoredBox(
              color: colors.bgSheet,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: rows,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 묶음 안 줄 사이 선: 1px `line`, 시작 쪽 16 안으로 들임.
class SettingsGroupDivider extends StatelessWidget {
  /// 선을 만듭니다.
  const new({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(start: Space.s16),
    child: ColoredBox(
      color: context.tokens.colors.line,
      child: const SizedBox(height: 1, width: double.infinity),
    ),
  );
}
