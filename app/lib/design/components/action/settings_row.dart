import 'dart:async';

import 'package:flutter/material.dart';
import 'package:myungli_diary/design/components/component_spec.dart';
import 'package:myungli_diary/design/components/sentence/press_ink_target.dart';
import 'package:myungli_diary/design/elements/app_icon.dart';
import 'package:myungli_diary/design/elements/list_divider.dart';
import 'package:myungli_diary/design/interaction/haptics.dart';
import 'package:myungli_diary/design/interaction/motion_prefs.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';
import 'package:phosphor_glyphs/phosphor_glyphs.dart';

const AppGlyph _caretRight = AppGlyph(
  light: PhosphorIconsLight.caretRight,
  regular: PhosphorIconsRegular.caretRight,
);

const AppGlyph _check = AppGlyph(
  light: PhosphorIconsLight.check,
  regular: PhosphorIconsRegular.check,
);

/// [SettingsRow] 변형(`settings-row` `variants`).
enum SettingsRowVariant {
  /// 다음 화면으로(오른쪽 화살표).
  navigate,

  /// 값을 고름(값 + 화살표, 시트를 엶).
  value,

  /// 켜고 끔(스위치, 화살표 없음).
  toggle,

  /// 시트 안에서 하나 고르기(언어 등). 누르면 바로 값이 바뀌고, 꺾쇠 없이 고른 줄 끝에 체크가
  /// 붙습니다(V58).
  select,

  /// 누를 수 없는 정보 줄(V122). 이름 왼쪽, 값 오른쪽이고 화살표, 눌림 표시, 터치 넓힘이
  /// 없습니다. 값은 줄 안쪽 폭의 절반까지 쓰고 넘치면 값 쪽이 오른쪽 맞춤으로 줄을 바꿉니다.
  /// 스크린리더는 버튼이 아닌 글자로 이름 다음에 값을 이어 읽습니다.
  readonly,

  /// 로그아웃·계정 삭제. 경고 표시 없이 자기 앞 아이콘(Regular)과 600 글자로 구분하고
  /// 화살표와 빨간색이 없습니다(V58).
  destructive,
}

/// 설정 한 줄(`settings-row`).
///
/// 줄 전체가 하나의 눌리는 자리(`press.ink`, `readonly`는 없음)이고 높이는 52 이상(글자가
/// 커지면 늘어남), 좌우 16입니다.
/// 스크린리더는 "글자 + 값"을 버튼으로 읽고, `toggle`은 스위치(켜짐 상태)로, `readonly`는
/// 버튼이 아닌 글자로 읽습니다.
///
/// * `navigate`·`value`·`destructive`는 [onTap], `toggle`은 [onToggle]을 씁니다.
///   둘 다 null이면 `disabled`(글자 `color.disabled.fg`, 누를 수 없음)입니다.
/// * `readonly`는 누르는 자리가 없어 [onTap]과 [onToggle]을 받지 않고, 늘 본문색입니다.
/// * `toggle`을 켜고 끌 때 selection 햅틱이 한 번 나갑니다.
class SettingsRow extends StatelessWidget {
  /// 설정 줄을 만듭니다. [value]는 `value`, `readonly` 변형의 값 글자, [toggled]는 `toggle`의
  /// 켜짐입니다.
  const new({
    required this.variant,
    required this.label,
    this.value,
    this.toggled = false,
    this.selected = false,
    this.leading,
    this.onTap,
    this.onToggle,
    this.identifier,
    super.key,
  }) : assert(
         variant != SettingsRowVariant.toggle || onTap == null,
         'toggle은 onToggle을 씁니다.',
       ),
       assert(
         variant != SettingsRowVariant.readonly ||
             (onTap == null && onToggle == null),
         'readonly는 누를 수 없습니다.',
       );

  /// 명세 대조용 요약.
  static const ComponentSpec spec = ComponentSpec(
    'settings-row',
    {'navigate', 'value', 'toggle', 'select', 'readonly', 'destructive'},
    {'pressed', 'disabled'},
  );

  /// 오른쪽 화살표를 찾는 테스트용 키.
  static const Key chevronKey = ValueKey('settings-row-chevron');

  /// 스위치를 찾는 테스트용 키.
  static const Key toggleKey = ValueKey('settings-row-toggle');

  /// 고른 줄 끝 체크를 찾는 테스트용 키.
  static const Key checkKey = ValueKey('settings-row-check');

  /// 앞 아이콘을 찾는 테스트용 키.
  static const Key leadingKey = ValueKey('settings-row-leading');

  /// 줄 최소 높이(`row.minHeight`).
  static const double minHeight = 52;

  /// 줄 좌우 안쪽 여백(`row.paddingX`).
  static const double paddingX = Space.s16;

  /// 변형.
  final SettingsRowVariant variant;

  /// 줄 글자.
  final String label;

  /// `value`, `readonly` 변형의 값 글자. 다른 변형에서는 그리지 않습니다. 비었으면 이름만
  /// 그리고 이름만 읽습니다.
  final String? value;

  /// `toggle` 변형의 켜짐.
  final bool toggled;

  /// `select` 변형에서 고른 줄이면 true: 끝에 체크가 붙고 스크린리더가 선택됨으로 읽습니다.
  final bool selected;

  /// 글자 앞 아이콘(`parts.leading`). 설정 화면 메뉴 줄에만 둡니다. 크기는 `size.icon.20`
  /// 고정이라 글자 배율을 곱하지 않고, 굵기는 Light(destructive만 Regular), 색은
  /// `text.primary`, 글자와 사이 `space.12`입니다. 꾸밈이라 스크린리더가 읽지 않습니다.
  final AppGlyph? leading;

  /// 눌렀을 때(`navigate`·`value`·`select`·`destructive`). null이면 disabled입니다.
  final VoidCallback? onTap;

  /// 켜고 끌 때 새 값을 줍니다(`toggle`). null이면 disabled입니다.
  final ValueChanged<bool>? onToggle;

  /// IA 슬롯 id. 있으면 Semantics `identifier`로 붙입니다.
  final String? identifier;

  bool get _enabled => switch (variant) {
    SettingsRowVariant.readonly => true,
    SettingsRowVariant.toggle => onToggle != null,
    _ => onTap != null,
  };

  bool get _showsValue =>
      variant == SettingsRowVariant.value ||
      variant == SettingsRowVariant.readonly;

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
    final valueText = _showsValue && (value?.isNotEmpty ?? false)
        ? value
        : null;
    final chevron =
        variant == SettingsRowVariant.navigate ||
        variant == SettingsRowVariant.value;

    final row = LayoutBuilder(
      builder: (context, constraints) => _content(
        _maxValueWidth(constraints.maxWidth),
        labelStyle: labelStyle,
        valueText: valueText,
        chevron: chevron,
        enabled: enabled,
        destructive: destructive,
      ),
    );

    final semanticLabel = valueText == null ? label : '$label, $valueText';
    if (variant == SettingsRowVariant.readonly) {
      // 누르는 자리 없이 글자 하나로 읽습니다(a11y.role text).
      return Semantics(
        identifier: identifier,
        container: true,
        label: semanticLabel,
        excludeSemantics: true,
        child: row,
      );
    }
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
      checked: variant == SettingsRowVariant.select ? selected : null,
      borderRadius: BorderRadius.zero,
      child: row,
    );
  }

  /// 값 글자가 쓸 수 있는 최대 폭. `readonly`는 계약대로 줄 안쪽 폭(좌우 여백을 뺀 폭)의
  /// 절반이고, `value`는 줄 너비의 절반입니다.
  double _maxValueWidth(double rowWidth) =>
      variant == SettingsRowVariant.readonly
      ? (rowWidth - paddingX * 2) / 2
      : rowWidth / 2;

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
            horizontal: paddingX,
            vertical: Space.s12,
          ),
          child: Row(
            children: [
              if (leading != null) ...[
                AppIcon(
                  leading!,
                  key: leadingKey,
                  size: AppIconSize.s20,
                  weight: destructive
                      ? AppIconWeight.regular
                      : AppIconWeight.light,
                  color: enabled ? colors.textPrimary : colors.disabledFg,
                ),
                const SizedBox(width: Space.s12),
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
                  size: AppIconSize.s16,
                  color: colors.textSecondary,
                ),
              ],
              if (variant == SettingsRowVariant.select && selected) ...[
                const SizedBox(width: Space.s8),
                AppIcon(
                  _check,
                  key: checkKey,
                  size: AppIconSize.s20,
                  weight: AppIconWeight.regular,
                  color: colors.actionPrimary,
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
/// `line`(안쪽 16), 아래로 24 띄움. [title]이 있으면 카드 위에 `caption.md`
/// `text.secondary` 묶음 제목이고, [note]가 있으면 같은 자리에 묶음 안내
/// 문장(`groupNote`, 두 줄까지, V50)입니다.
class SettingsGroup extends StatelessWidget {
  /// 묶음을 만듭니다. 제목과 안내는 같은 자리라 하나만 받습니다.
  const new({
    required this.children,
    this.title,
    this.note,
    this.noteIdentifier,
    super.key,
  }) : assert(title == null || note == null, '제목과 안내는 같은 자리입니다');

  /// 묶음 안 줄들(위에서 아래).
  final List<Widget> children;

  /// 묶음 제목.
  final String? title;

  /// 묶음 전체에 걸리는 안내 문장(`groupNote`). 늘 보이고 누르지 않습니다.
  final String? note;

  /// [note]의 IA 슬롯 id. 있으면 Key와 Semantics `identifier`로 붙입니다.
  final String? noteIdentifier;

  /// 묶음 안내의 최대 줄 수(`groupNote.maxLines`).
  static const int noteMaxLines = 2;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final rows = <Widget>[];
    for (final (index, child) in children.indexed) {
      if (index > 0) {
        rows.add(const ListDivider());
      }
      rows.add(child);
    }
    final heading = title;
    final note = this.note;
    final noteIdentifier = this.noteIdentifier;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.s24),
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
          if (note != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.s16,
                0,
                Space.s16,
                Space.s8,
              ),
              child: Semantics(
                identifier: noteIdentifier,
                container: true,
                child: Text(
                  note,
                  key: noteIdentifier == null
                      ? null
                      : ValueKey<String>(noteIdentifier),
                  maxLines: noteMaxLines,
                  overflow: TextOverflow.ellipsis,
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
