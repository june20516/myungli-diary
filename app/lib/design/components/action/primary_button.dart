import 'package:flutter/material.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/action/breathing_dots.dart';
import 'package:myungli_diary/design/components/component_spec.dart';
import 'package:myungli_diary/design/components/feedback/toast.dart';
import 'package:myungli_diary/design/components/sentence/press_ink_target.dart';
import 'package:myungli_diary/design/components/sentence/vertical_hit_slop.dart';
import 'package:myungli_diary/design/elements/app_icon.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

/// 주 동작 버튼 변형(`primary-button` `variants`).
enum PrimaryButtonVariant {
  /// 화면의 주 동작. 면이 `action.primary`입니다.
  filled(52),

  /// 보조 동작(다시 입력, 건너뛰기, 다시 시도). 바탕 없이 글자만이고 높이는 filled와 같습니다(V60).
  quiet(52),

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
    this.leadingIcon,
    this.showCaution = true,
    super.key,
  }) : compact = false,
       autofocus = false;

  /// 확인 창 버튼 줄 전용(`dialog` `actions`): 높이 44, 좌우 안쪽 `space.12`, 눌림 최소 44.
  /// 다른 곳에서 쓰지 않습니다. [autofocus]는 notice의 확인 버튼이 처음 초점을 받게 합니다.
  const new dialogAction({
    required this.label,
    required this.onPressed,
    this.variant = PrimaryButtonVariant.filled,
    this.autofocus = false,
    super.key,
  }) : loading = false,
       busyLabel = null,
       identifier = null,
       busyIdentifier = null,
       labelColor = null,
       animated = true,
       leadingIcon = null,
       showCaution = false,
       compact = true;

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

  /// 글자색을 바꿉니다(예: 도장 위 `seal.on-soft`). 모든 변형에 적용됩니다(지금 쓰는 곳은
  /// quiet뿐). 꺼짐일 때는 무시하고 `disabled.fg`입니다.
  /// 눌림 번짐 색도 이 색을 따릅니다.
  final Color? labelColor;

  /// false면 점이 숨 쉬지 않고 정지 상태로 그립니다.
  final bool animated;

  /// 글자 앞 아이콘(`parts.leadingIcon`). 옆 글자 단계(adjacent-text)에 글자 배율을 곱하고,
  /// Regular 굵기에 글자색과 같은 색이며 꾸밈이라 스크린리더가 읽지 않습니다.
  /// 처리 중에는 숨습니다. 아이콘과 글자 묶음은 버튼 가운데에 놓입니다.
  final AppGlyph? leadingIcon;

  /// destructive의 글자 앞 경고 표시. 확인 창(`dialog`)은 제목 앞에 경고 표시를 두므로
  /// 버튼에서는 끕니다(V65).
  final bool showCaution;

  /// 확인 창 안의 크기. 주의: [PrimaryButton.dialogAction]만 켭니다(일반 버튼은 항상 false).
  final bool compact;

  /// 확인 창 안 버튼 높이(px, `dialog.parts.actions.height`).
  static const double compactHeight = 44;

  /// 열릴 때 처음 초점을 받을지. 주의: [PrimaryButton.dialogAction]만 켤 수 있습니다.
  final bool autofocus;

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
      constraints: BoxConstraints(
        minHeight: compact ? compactHeight : variant.height,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(color: bg, borderRadius: radius),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? Space.s12 : Space.s20,
            vertical: Space.s8,
          ),
          child: Center(
            heightFactor: 1,
            child: loading
                ? BreathingDots(
                    key: dotsKey,
                    color: fg,
                    animated: animated,
                    count: BreathingDots.standardCount,
                    size: BreathingDots.standardSize,
                    gap: BreathingDots.standardGap,
                  )
                : DefaultTextStyle(
                    style: labelStyle,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (destructive && showCaution) ...[
                          const AppIcon.caution(),
                          const SizedBox(width: Space.s8),
                        ],
                        if (leadingIcon != null) ...[
                          ExcludeSemantics(
                            child: AppIcon(
                              leadingIcon!,
                              size: AppIconSize.adjacentText(
                                labelStyle.fontSize ?? kDefaultFontSize,
                              ),
                              weight: AppIconWeight.regular,
                              color: fg,
                              scalesWithText: true,
                            ),
                          ),
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
      minHeight: compact ? compactHeight : _minTarget,
      child: PressInkTarget(
        semanticLabel: label,
        identifier: identifier,
        autofocus: autofocus,
        onTap: onPressed,
        borderRadius: radius,
        inkColor: fg,
        child: wide,
      ),
    );
  }
}

/// 목록 화면의 아래 고정 주 동작(`primary-button` `floating`, V58).
///
/// 목록이 있을 때만 목록 위에 떠 있고, 빈 상태에서는 같은 버튼이 empty-state 안내 아래에
/// 놓이며, 불러오는 중과 오류에서는 그리지 않습니다(그 판단은 쓰는 화면이 합니다).
/// `Stack`의 마지막 자식으로 목록 위에 겹쳐 쓰고, 아래 고정 위치는 광고 배너·탭 바·아래 안전
/// 영역 가운데 먼저 있는 것 위 `space.16`입니다. 탭 셸은 그 높이를 화면의 아래 여백
/// (`MediaQuery.viewPadding`)으로 넘기므로 이 위젯은 그 값을 따릅니다. toast는 이 버튼 위
/// 16px에 뜹니다([ToastAnchor]).
class FloatingPrimaryButton extends StatelessWidget {
  /// 떠 있는 버튼을 만듭니다.
  const new({required this.button, super.key});

  /// 떠 있는 버튼 면을 찾는 테스트용 키.
  static const Key shadowKey = ValueKey('floating-primary-button-shadow');

  /// 목록 아래 여백: 버튼 높이 52 + `space.16` + `space.16`
  /// (`parts.floating.listPaddingBottom`). 마지막 줄이 버튼 위까지 올라오게 합니다.
  static const double listBottomInset = 52 + Space.s16 + Space.s16;

  /// 눌리는 버튼(보통 filled).
  final PrimaryButton button;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewPaddingOf(context).bottom;
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          Space.s20,
          0,
          Space.s20,
          Space.s16 + bottom,
        ),
        child: ToastAnchor(
          child: DecoratedBox(
            key: shadowKey,
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.all(Radius.circular(Radii.md)),
              boxShadow: Shadows.raised,
            ),
            child: button,
          ),
        ),
      ),
    );
  }
}
