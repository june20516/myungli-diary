import 'package:flutter/material.dart';
import 'package:myungli_diary/design/components/component_spec.dart';
import 'package:myungli_diary/design/components/sentence/press_ink_target.dart';
import 'package:myungli_diary/design/components/sentence/vertical_hit_slop.dart';
import 'package:myungli_diary/design/elements/app_icon.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';
import 'package:phosphor_glyphs/phosphor_glyphs.dart';

const AppGlyph _export = AppGlyph(
  light: PhosphorIconsLight.export,
  regular: PhosphorIconsRegular.export,
);

/// 공유 버튼 변형(`share-button` `variants`).
enum ShareButtonVariant {
  /// `app-bar` 동작. 글자 없이 아이콘만이고 눌림 영역이 44x44입니다.
  icon,

  /// 본문 안 공유 입구(미리보기 화면). `status` 색 바탕의 둥근 사각입니다(결정 V26).
  soft,
}

/// 공유 버튼(`share-button`). 누르면 `share-preview` 시트를 엽니다.
///
/// [label]은 [ShareButtonVariant.soft]에서 글자로, [ShareButtonVariant.icon]에서
/// 스크린리더 라벨로만 쓰입니다. `soft` 높이 36은 최소값이라 기기 글자가 커지면 함께
/// 커지고, 눌림 영역은 위아래로 넓혀 최소 44를 지킵니다. 눌림은 `press.ink`입니다.
class ShareButton extends StatelessWidget {
  /// 버튼을 만듭니다. [identifier]는 IA 슬롯 id(Semantics `identifier`)입니다.
  const new({
    required this.variant,
    required this.label,
    required this.onPressed,
    this.identifier,
    super.key,
  });

  /// 명세 대조용 요약.
  static const ComponentSpec spec = ComponentSpec(
    'share-button',
    {'icon', 'soft'},
    {'pressed'},
  );

  /// 버튼 면을 찾는 테스트용 키.
  static const Key faceKey = ValueKey('share-button-face');

  static const double _iconTarget = 44;
  static const double _softMinHeight = 36;

  /// 변형.
  final ShareButtonVariant variant;

  /// 버튼 글자(`soft`) 또는 스크린리더 라벨(`icon`).
  final String label;

  /// 눌렀을 때.
  final VoidCallback onPressed;

  /// IA 슬롯 id. 있으면 Semantics `identifier`로 붙입니다.
  final String? identifier;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return switch (variant) {
      ShareButtonVariant.icon => PressInkTarget(
        semanticLabel: label,
        identifier: identifier,
        onTap: onPressed,
        borderRadius: const BorderRadius.all(Radius.circular(_iconTarget / 2)),
        inkColor: tokens.colors.textPrimary,
        child: SizedBox.square(
          key: faceKey,
          dimension: _iconTarget,
          child: Center(
            child: AppIcon(_export, color: tokens.colors.textPrimary),
          ),
        ),
      ),
      ShareButtonVariant.soft => VerticalHitSlop(
        child: PressInkTarget(
          semanticLabel: label,
          identifier: identifier,
          onTap: onPressed,
          borderRadius: const BorderRadius.all(Radius.circular(Radii.md)),
          inkColor: tokens.colors.statusFg,
          child: DecoratedBox(
            key: faceKey,
            decoration: BoxDecoration(
              color: tokens.colors.statusBg,
              borderRadius: const BorderRadius.all(Radius.circular(Radii.md)),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: _softMinHeight),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.s16),
                child: Center(
                  heightFactor: 1,
                  widthFactor: 1,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: Space.s8,
                    children: [
                      AppIcon(
                        _export,
                        size: AppIconSize.inline,
                        weight: AppIconWeight.regular,
                        color: tokens.colors.statusFg,
                      ),
                      Flexible(
                        child: Text(
                          label,
                          style: tokens.typography.labelMd.copyWith(
                            color: tokens.colors.statusFg,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    };
  }
}
