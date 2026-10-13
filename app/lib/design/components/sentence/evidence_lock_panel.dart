import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show OverflowBoxFit;
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/sentence/depth_link.dart';
import 'package:myungli_diary/design/components/sentence/press_ink_target.dart';
import 'package:myungli_diary/design/components/sentence/vertical_hit_slop.dart';
import 'package:myungli_diary/design/interaction/motion_prefs.dart';
import 'package:myungli_diary/design/interaction/patterns.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';
import 'package:phosphor_glyphs/phosphor_glyphs.dart';

/// 근거 시트 아래에 고정되는 잠금 안내 영역(시안 B, `lockPanel`).
///
/// 위 1px `line`, 바탕 `bg.sheet`. 자물쇠 + 안내 → 보상 고지(버튼보다 먼저) → 광고 버튼 →
/// 광고 제거권 링크 순서입니다. [DepthLinkState.lockedNoAd]면 버튼이 꺼지고 안내가 붙으며,
/// [DepthLinkState.unlocking]이면 버튼 글자 자리에 점 세 개가 숨 쉽니다(스피너 금지).
///
/// 가로로는 시트 안쪽 여백(`space.20`)만큼 밖으로 나가 시트 폭을 꽉 채웁니다.
class EvidenceLockPanel extends StatelessWidget {
  /// 안내 영역을 만듭니다. [state]는 `locked`·`lockedNoAd`·`unlocking` 중 하나입니다.
  const new({
    required this.state,
    this.onWatchAd,
    this.onPass,
    this.animated = true,
    super.key,
  }) : assert(state != DepthLinkState.unlocked, '권한이 있으면 안내 영역을 그리지 않습니다.');

  /// 광고 버튼을 찾는 테스트용 키.
  static const Key ctaKey = ValueKey('evidence-lock-cta');

  /// 처리 중 점을 찾는 테스트용 키.
  static const Key dotsKey = ValueKey('evidence-lock-dots');

  static const double _iconSize = 16;
  static const double _gap = 6;
  static const double _ctaHeight = 52;

  /// 열람 상태.
  final DepthLinkState state;

  /// 광고 보고 열기. `locked`에서만 불립니다.
  final VoidCallback? onWatchAd;

  /// 광고 제거권 링크(`ad-free`로 이동).
  final VoidCallback? onPass;

  /// false면 점이 숨 쉬지 않고 정지 상태로 그립니다(golden).
  final bool animated;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = context.tokens;
    final colors = tokens.colors;
    final typography = tokens.typography;
    // 시트 안쪽 여백만큼 양옆으로 나가 시트 폭을 채웁니다.
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth + Space.s20 * 2;
        return OverflowBox(
          fit: OverflowBoxFit.deferToChild,
          minWidth: width,
          maxWidth: width,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.bgSheet,
              border: Border(top: BorderSide(color: colors.line)),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.s20,
                Space.s16,
                Space.s20,
                Space.s24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        PhosphorIconsRegular.lockSimple,
                        size: _iconSize,
                        color: colors.statusFg,
                      ),
                      const SizedBox(width: _gap),
                      Flexible(
                        child: Text(
                          l10n.evidenceSheetLockHead,
                          style: typography.labelLg.copyWith(
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: _gap),
                  // 보상 고지는 광고 버튼보다 먼저 보입니다(AdMob 보상 고지).
                  Text(
                    l10n.evidenceSheetLockReward,
                    style: typography.captionLg.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: Space.s12),
                  _buildCta(context),
                  if (state == DepthLinkState.lockedNoAd)
                    Padding(
                      padding: const EdgeInsets.only(top: Space.s8),
                      child: Text(
                        l10n.evidenceSheetLockUnavailable,
                        textAlign: TextAlign.center,
                        style: typography.captionLg.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                  if (onPass != null)
                    Padding(
                      padding: const EdgeInsets.only(top: Space.s12),
                      child: VerticalHitSlop(
                        child: Center(
                          child: PressInkTarget(
                            link: true,
                            semanticLabel: l10n.evidenceSheetLockPass,
                            onTap: onPass!,
                            borderRadius: const BorderRadius.all(
                              Radius.circular(Radii.xs),
                            ),
                            inkColor: colors.actionPrimary,
                            child: Text(
                              l10n.evidenceSheetLockPass,
                              textAlign: TextAlign.center,
                              style: typography.labelMd.copyWith(
                                color: colors.actionPrimary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// 임시: 계획 2에서 `primary-button` `filled`(`disabled`·`loading`)로 교체합니다.
  Widget _buildCta(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = context.tokens;
    final colors = tokens.colors;
    const radius = BorderRadius.all(Radius.circular(Radii.md));
    final label = l10n.evidenceSheetLockCta;
    final enabled = state == DepthLinkState.locked && onWatchAd != null;
    final busy = state == DepthLinkState.unlocking;
    final fg = enabled || busy ? colors.actionOnPrimary : colors.disabledFg;
    final face = SizedBox(
      key: ctaKey,
      height: _ctaHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: enabled || busy ? colors.actionPrimary : colors.disabledBg,
          borderRadius: radius,
        ),
        child: Center(
          child: busy
              ? _BreathingDots(color: fg, animated: animated)
              : Text(
                  label,
                  style: tokens.typography.labelLg.copyWith(color: fg),
                ),
        ),
      ),
    );
    if (enabled) {
      return PressInkTarget(
        semanticLabel: label,
        onTap: onWatchAd!,
        borderRadius: radius,
        inkColor: colors.actionOnPrimary,
        child: face,
      );
    }
    // 꺼짐·처리 중에는 눌러도 아무 일이 없고, 처리 중은 "확인 중"으로 읽습니다.
    return Semantics(
      container: true,
      button: true,
      enabled: false,
      label: busy ? l10n.evidenceSheetA11yChecking : label,
      child: ExcludeSemantics(child: face),
    );
  }
}

/// 버튼 글자 자리의 점 세 개(6px, 간격 6px). 너비는 그대로, 줄 사이 150ms씩 어긋나 숨 쉽니다.
class _BreathingDots extends StatefulWidget {
  const new({required this.color, required this.animated});

  final Color color;
  final bool animated;

  @override
  State<_BreathingDots> createState() => _BreathingDotsState();
}

class _BreathingDotsState extends State<_BreathingDots>
    with SingleTickerProviderStateMixin {
  static const int _count = 3;
  static const double _size = 6;
  static const double _gap = 6;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: InteractionPattern.loadingBreathe.duration,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.animated) {
      if (!_controller.isAnimating) _controller.repeat(reverse: true);
    } else {
      _controller.stop();
    }
  }

  @override
  void didUpdateWidget(_BreathingDots oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animated != widget.animated) didChangeDependencies();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prefs = MotionPrefs.of(context);
    return Row(
      key: EvidenceLockPanel.dotsKey,
      mainAxisSize: MainAxisSize.min,
      spacing: _gap,
      children: [
        for (var i = 0; i < _count; i++)
          animate(
            InteractionPattern.loadingBreathe,
            t: _controller,
            prefs: prefs,
            options: PatternOptions(index: i),
            child: SizedBox.square(
              dimension: _size,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: widget.color,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
