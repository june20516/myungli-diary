import 'package:flutter/material.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/action/breathing_dots.dart';
import 'package:myungli_diary/design/components/component_spec.dart';
import 'package:myungli_diary/design/components/sentence/press_ink_target.dart';
import 'package:myungli_diary/design/components/sentence/vertical_hit_slop.dart';
import 'package:myungli_diary/design/elements/app_icon.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

/// 주 동작 버튼 변형(`primary-button` `variants`).
enum PrimaryButtonVariant {
  /// 화면의 주 동작. 면이 `action.primary`입니다.
  filled(52),

  /// 보조 동작(다시 입력, 건너뛰기, 다시 시도). 바탕 없이 글자만입니다.
  quiet(44),

  /// 되돌릴 수 없는 동작. 면이 `text.primary`이고 글자 앞에 경고 표시가 붙습니다.
  destructive(52);

  new(this.height);

  /// 면 최소 높이(px).
  final double height;
}

/// 주 동작 버튼(`primary-button`).
///
/// [onPressed]가 null이면 `disabled`, [loading]이면 글자 자리에 점 세 개가 숨 쉽니다
/// (스피너 금지). 처리 중에는 너비가 그대로이고 다시 눌리지 않으며, 스크린리더는
/// [busyLabel](기본 "처리 중")을 읽습니다. 눌림은 글자 둘레에서만 번지는 `press.ink`이고
/// Material의 물결·그림자·표면 색조는 쓰지 않습니다. 눌림 영역은 최소 48px입니다.
class PrimaryButton extends StatelessWidget {
  /// 버튼을 만듭니다.
  ///
  /// [identifier]는 IA 슬롯 id(Semantics `identifier`), [busyIdentifier]는 처리 중일 때
  /// 바꿔 붙일 슬롯 id입니다. [animated]가 false면 점이 정지 상태로 그려집니다(golden).
  const new({
    required this.label,
    required this.onPressed,
    this.variant = PrimaryButtonVariant.filled,
    this.loading = false,
    this.busyLabel,
    this.identifier,
    this.busyIdentifier,
    this.labelColor,
    this.animated = true,
    super.key,
  });

  /// 명세 대조용 요약.
  static const ComponentSpec spec = ComponentSpec(
    'primary-button',
    {'filled', 'quiet', 'destructive'},
    {'pressed', 'disabled', 'loading'},
  );

  /// 버튼 면을 찾는 테스트용 키.
  static const Key faceKey = ValueKey('primary-button-face');

  /// 처리 중 점을 찾는 테스트용 키.
  static const Key dotsKey = ValueKey('primary-button-dots');

  static const double _minTarget = 48;
  static const double _dotsGap = 6;
  static const double _dotSize = 6;
  static const int _dotCount = 3;

  /// 버튼 글자(스크린리더 라벨도 같습니다).
  final String label;

  /// 눌렀을 때. null이면 꺼짐입니다.
  final VoidCallback? onPressed;

  /// 변형.
  final PrimaryButtonVariant variant;

  /// 처리 중. 글자를 숨기고 점을 보이며 누름을 무시합니다.
  final bool loading;

  /// 처리 중일 때 스크린리더가 읽을 문구. 없으면 "처리 중".
  final String? busyLabel;

  /// IA 슬롯 id. 있으면 Semantics `identifier`로 붙입니다.
  final String? identifier;

  /// 처리 중일 때 `identifier` 대신 붙일 슬롯 id.
  final String? busyIdentifier;

  /// 글자색을 바꿉니다(예: 도장 위 `seal.on-soft`). 꺼짐일 때는 무시하고 `disabled.fg`입니다.
  /// 눌림 번짐 색도 이 색을 따릅니다.
  final Color? labelColor;

  /// false면 점이 숨 쉬지 않고 정지 상태로 그립니다.
  final bool animated;

  bool get _disabled => onPressed == null;

  @override
  Widget build(BuildContext context) {
    final colors = context.tokens.colors;
    final quiet = variant == PrimaryButtonVariant.quiet;
    final destructive = variant == PrimaryButtonVariant.destructive;
    final fg = _disabled
        ? colors.disabledFg
        : switch (variant) {
            PrimaryButtonVariant.filled => labelColor ?? colors.actionOnPrimary,
            PrimaryButtonVariant.quiet => labelColor ?? colors.actionPrimary,
            PrimaryButtonVariant.destructive => labelColor ?? colors.bgSheet,
          };
    final bg = _disabled
        ? (quiet ? null : colors.disabledBg)
        : switch (variant) {
            PrimaryButtonVariant.filled => colors.actionPrimary,
            PrimaryButtonVariant.quiet => null,
            PrimaryButtonVariant.destructive => colors.textPrimary,
          };
    const radius = BorderRadius.all(Radius.circular(Radii.md));
    final labelStyle = context.tokens.typography.labelLg.copyWith(color: fg);

    final face = ConstrainedBox(
      key: faceKey,
      // 명세 높이는 최소값입니다. 글자 배율이 크면 잘리지 않고 면이 커집니다.
      constraints: BoxConstraints(minHeight: variant.height),
      child: DecoratedBox(
        decoration: BoxDecoration(color: bg, borderRadius: radius),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Space.s20,
            vertical: Space.s8,
          ),
          child: Center(
            heightFactor: 1,
            child: loading
                ? BreathingDots(
                    key: dotsKey,
                    color: fg,
                    animated: animated,
                    count: _dotCount,
                    size: _dotSize,
                    gap: _dotsGap,
                  )
                : DefaultTextStyle(
                    style: labelStyle,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (destructive) ...[
                          const AppIcon.caution(),
                          const SizedBox(width: Space.s8),
                        ],
                        Flexible(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: labelStyle,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
    // 면은 width fill입니다.
    final wide = SizedBox(width: double.infinity, child: face);

    if (_disabled || loading) {
      // 꺼짐·처리 중에는 눌러도 아무 일이 없고, 처리 중은 busyLabel로 읽습니다.
      final busyText = busyLabel ?? AppLocalizations.of(context).actionBusy;
      return Semantics(
        container: true,
        button: true,
        enabled: false,
        identifier: loading ? busyIdentifier ?? identifier : identifier,
        label: loading ? busyText : label,
        child: ExcludeSemantics(child: wide),
      );
    }
    return VerticalHitSlop(
      minHeight: _minTarget,
      child: PressInkTarget(
        semanticLabel: label,
        identifier: identifier,
        onTap: onPressed!,
        borderRadius: radius,
        inkColor: fg,
        child: wide,
      ),
    );
  }
}
