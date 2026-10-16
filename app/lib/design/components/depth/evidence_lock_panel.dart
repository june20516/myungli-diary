import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show OverflowBoxFit;
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/action/primary_button.dart';
import 'package:myungli_diary/design/components/sentence/depth_link.dart';
import 'package:myungli_diary/design/components/sentence/link_label.dart';
import 'package:myungli_diary/design/components/sentence/press_ink_target.dart';
import 'package:myungli_diary/design/components/sentence/vertical_hit_slop.dart';
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
  static const Key ctaKey = ValueKey(SlotIds.evidenceSheetLockCta);

  static const double _iconSize = 16;
  static const double _gap = 6;

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
                  _slot(
                    SlotIds.evidenceSheetLockHead,
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
                  ),
                  const SizedBox(height: _gap),
                  // 보상 고지는 광고 버튼보다 먼저 보입니다(AdMob 보상 고지).
                  _slot(
                    SlotIds.evidenceSheetLockReward,
                    Text(
                      l10n.evidenceSheetLockReward,
                      style: typography.captionLg.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: Space.s12),
                  _buildCta(context),
                  if (state == DepthLinkState.lockedNoAd)
                    Padding(
                      padding: const EdgeInsets.only(top: Space.s8),
                      child: _slot(
                        SlotIds.evidenceSheetLockUnavailable,
                        Text(
                          l10n.evidenceSheetLockUnavailable,
                          textAlign: TextAlign.center,
                          style: typography.captionLg.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  if (onPass != null)
                    Padding(
                      padding: const EdgeInsets.only(top: Space.s12),
                      child: VerticalHitSlop(
                        child: KeyedSubtree(
                          key: const ValueKey(SlotIds.evidenceSheetLockPass),
                          child: Center(
                            child: PressInkTarget(
                              link: true,
                              identifier: SlotIds.evidenceSheetLockPass,
                              semanticLabel: l10n.evidenceSheetLockPass,
                              onTap: onPass!,
                              borderRadius: const BorderRadius.all(
                                Radius.circular(Radii.xs),
                              ),
                              inkColor: colors.actionPrimary,
                              // 끝 화살표는 문구가 아니라 컴포넌트가 그립니다
                              // (`lockPanel.pass.chevron`, 결정 V29).
                              child: LinkLabel(
                                label: l10n.evidenceSheetLockPass,
                                textAlign: TextAlign.center,
                                style: typography.labelMd.copyWith(
                                  color: colors.actionPrimary,
                                ),
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

  /// 슬롯 id를 Key와 Semantics `identifier`로 붙입니다(글자는 그대로 읽힙니다).
  static Widget _slot(String id, Widget child) => KeyedSubtree(
    key: ValueKey(id),
    child: Semantics(identifier: id, child: child),
  );

  Widget _buildCta(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final enabled = state == DepthLinkState.locked && onWatchAd != null;
    return PrimaryButton(
      key: ctaKey,
      label: l10n.evidenceSheetLockCta,
      onPressed: enabled ? onWatchAd : null,
      loading: state == DepthLinkState.unlocking,
      busyLabel: l10n.evidenceSheetA11yChecking,
      identifier: SlotIds.evidenceSheetLockCta,
      busyIdentifier: SlotIds.evidenceSheetA11yChecking,
      animated: animated,
    );
  }
}
