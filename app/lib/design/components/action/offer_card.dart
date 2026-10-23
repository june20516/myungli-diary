import 'package:flutter/material.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/action/primary_button.dart';
import 'package:myungli_diary/design/components/component_spec.dart';
import 'package:myungli_diary/design/components/feedback/seep_on_change.dart';
import 'package:myungli_diary/design/components/sentence/press_ink_target.dart';
import 'package:myungli_diary/design/components/sentence/vertical_hit_slop.dart';
import 'package:myungli_diary/design/elements/app_icon.dart';
import 'package:myungli_diary/design/elements/status_tag.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';
import 'package:phosphor_glyphs/phosphor_glyphs.dart';

/// 광고 제거권 카드의 상태(`offer-card` `states`).
enum OfferCardState {
  /// 살 수 있음. 구매 버튼이 보입니다.
  available,

  /// 이용 중. 구매 버튼 대신 꼬리표와 남은 기간이 보입니다(`appear.seep`).
  active,

  /// 구매 처리 중. 구매 버튼에서 점이 숨 쉽니다.
  purchasing,

  /// 오프라인. 구매 버튼이 꺼집니다(화면 위 notice-banner `offline`은 화면이 둠).
  offline,
}

/// [OfferCard] 부품별 IA 슬롯 id. 있는 것만 그 부품의 Semantics `identifier`로 붙습니다.
///
/// 화면이 `SlotIds`(예 `ad-free.offer.head`)를 넘깁니다. 카드 묶음이 함께 읽는
/// [head]·[price]·[period]는 읽기에서 빠진 글자라, 찾기용 빈 노드에 identifier만 답니다.
@immutable
final class OfferCardIdentifiers {
  /// 부품별 슬롯 id를 정합니다. 모두 선택입니다.
  const new({
    this.head,
    this.price,
    this.period,
    this.remaining,
    this.buy,
    this.history,
    this.legal,
  });

  /// [OfferCard.head] 슬롯.
  final String? head;

  /// [OfferCard.price] 슬롯.
  final String? price;

  /// [OfferCard.period] 슬롯.
  final String? period;

  /// [OfferCard.remaining] 슬롯.
  final String? remaining;

  /// 구매 버튼 슬롯.
  final String? buy;

  /// 구매 내역 버튼 슬롯.
  final String? history;

  /// 약관 안내 슬롯.
  final String? legal;
}

/// 광고 제거권 카드(`offer-card`, D53·D54).
///
/// 위에서 아래로 아이콘 → [head] → [price] → [period] →
/// (이용 중이면 [statusLabel]·[remaining], 아니면 구매 버튼) → 구매 내역 조용한 버튼 →
/// 약관 안내입니다. 가격·기간·자동 갱신 아님 고지([price]·[period])는 구매 버튼보다 위,
/// 같은 카드 안에 둡니다. 구매 내역 버튼은 [state]와 관계없이 늘 보입니다(따로 누르는
/// 구매 복원 버튼은 없음, D88 ②).
///
/// 문구는 모두 화면이 ARB에서 읽어 넘깁니다. 구매 완료 햅틱(light)도 화면의 몫입니다.
/// 스크린리더는 카드를 한 묶음으로 보고 [head]·[price]·[period]를 함께 읽으며,
/// 버튼은 따로 읽습니다.
class OfferCard extends StatelessWidget {
  /// 카드를 만듭니다. [statusLabel]("사용 중")과 [remaining]은 [state]가 `active`일 때 씁니다.
  /// [animated]가 false면 구매 버튼의 점이 정지 상태로 그려집니다(golden).
  const new({
    required this.state,
    required this.head,
    required this.buyLabel,
    required this.historyLabel,
    required this.legalNotice,
    this.price,
    this.period,
    this.statusLabel,
    this.remaining,
    this.onBuy,
    this.onHistory,
    this.onLegal,
    this.identifiers = const OfferCardIdentifiers(),
    this.animated = true,
    super.key,
  });

  /// 명세 대조용 요약.
  static const ComponentSpec spec = ComponentSpec('offer-card', {}, {
    'available',
    'active',
    'purchasing',
    'offline',
  });

  /// 카드 묶음을 찾는 테스트용 키.
  static const Key cardKey = ValueKey('offer-card');

  /// 구매 버튼을 찾는 테스트용 키.
  static const Key buyKey = ValueKey('offer-card-buy');

  /// 구매 내역 버튼을 찾는 테스트용 키.
  static const Key historyKey = ValueKey('offer-card-history');

  /// 약관 안내를 찾는 테스트용 키.
  static const Key legalKey = ValueKey('offer-card-legal');

  /// 카드 안쪽 여백(`parts.container.padding`, `space.20`).
  static const double padding = Space.s20;

  /// 아이콘 크기(`parts.icon.size`).
  static const double iconSize = 28;

  /// 아이콘과 [head] 사이(`parts.head.marginTop`, `space.12`).
  static const double headGap = Space.s12;

  /// [head]와 [price] 사이(`parts.price.marginTop`, `space.16`).
  static const double priceGap = Space.s16;

  /// [price]와 [period] 사이. 명세에 값이 없어 purchase-row 보조 줄 간격
  /// (`PurchaseRowGroup.metaGap`, `space.4`)을 따릅니다.
  static const double periodGap = Space.s4;

  /// 마지막 안내(가격·기간)와 구매 버튼·이용 중 표시 사이(`parts.buy.marginTop`, `space.20`).
  static const double buyGap = Space.s20;

  /// 구매 내역 버튼과 약관 안내 사이(`parts.legal.marginTop`, `space.12`).
  static const double legalGap = Space.s12;

  /// 이용 중 꼬리표와 남은 기간 사이.
  static const double _statusGap = Space.s8;

  static const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

  static const AppGlyph _sparkle = AppGlyph(
    light: PhosphorIconsLight.sparkle,
    regular: PhosphorIconsRegular.sparkle,
  );

  /// 카드 상태.
  final OfferCardState state;

  /// 주는 것 한 줄(`ad-free.offer.head`).
  final String head;

  /// 가격 한 줄(`ad-free.offer.price`, 고정폭 숫자). 스토어가 준 가격 문자열 그대로입니다.
  ///
  /// null이면 가격 줄과 그 간격을 그리지 않습니다(상품을 받지 못한 오프라인 등).
  final String? price;

  /// 기간과 자동 갱신 아님 고지(`ad-free.offer.period`). 가격 아래 작은 글씨입니다.
  ///
  /// 가격과 상관없는 고지라 [price]가 null이어도 보입니다. null이면 그리지 않습니다.
  final String? period;

  /// 구매 버튼 문구.
  final String buyLabel;

  /// 구매 내역 버튼 문구(`ad-free.history.cta`).
  final String historyLabel;

  /// 약관·정책 안내(`ad-free.legal.notice`).
  final String legalNotice;

  /// 이용 중 꼬리표 문구("사용 중", `tag.status`).
  final String? statusLabel;

  /// 남은 기간·만료일 문장(`ad-free.status.remaining`).
  final String? remaining;

  /// 구매 버튼을 눌렀을 때. `purchasing`에서는 불리지 않고 `offline`에서는 버튼이 꺼집니다.
  final VoidCallback? onBuy;

  /// 구매 내역 버튼을 눌렀을 때.
  final VoidCallback? onHistory;

  /// 약관 안내를 눌렀을 때.
  final VoidCallback? onLegal;

  /// 부품별 IA 슬롯 id.
  final OfferCardIdentifiers identifiers;

  /// false면 구매 버튼의 점이 정지 상태로 그려집니다.
  final bool animated;

  /// 카드 묶음이 읽는 글자([child])에 찾기용 [identifier]를 답니다. 없으면 [child] 그대로입니다.
  static Widget _identified(String? identifier, Widget child) =>
      identifier == null
      ? child
      : Semantics(container: true, identifier: identifier, child: child);

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final l10n = AppLocalizations.of(context);
    final active = state == OfferCardState.active;

    return Semantics(
      key: cardKey,
      container: true,
      explicitChildNodes: true,
      label: [head, ?price, ?period].join(l10n.a11yListSeparator),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.bgSheet,
          borderRadius: const BorderRadius.all(Radius.circular(Radii.lg)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: ExcludeSemantics(
                  child: AppIcon(
                    _sparkle,
                    size: AppIconSize.state,
                    color: colors.actionPrimary,
                  ),
                ),
              ),
              const SizedBox(height: headGap),
              _identified(
                identifiers.head,
                ExcludeSemantics(
                  child: Text(
                    head,
                    style: tokens.typography.subtitle.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                ),
              ),
              if (price != null) ...[
                const SizedBox(height: priceGap),
                _identified(
                  identifiers.price,
                  ExcludeSemantics(
                    child: Text(
                      price!,
                      style: tokens.typography.title.copyWith(
                        color: colors.textPrimary,
                        fontFeatures: _tabular,
                      ),
                    ),
                  ),
                ),
              ],
              if (period != null) ...[
                // 가격이 없으면 head 바로 아래에서 시작하므로 가격 자리의 간격을 씁니다.
                SizedBox(height: price != null ? periodGap : priceGap),
                _identified(
                  identifiers.period,
                  ExcludeSemantics(
                    child: Text(
                      period!,
                      style: tokens.typography.captionLg.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: buyGap),
              SeepOnChange(
                changeKey: active,
                child: active ? _activeStatus(context) : _buyButton(),
              ),
              PrimaryButton(
                key: historyKey,
                label: historyLabel,
                variant: PrimaryButtonVariant.quiet,
                identifier: identifiers.history,
                onPressed: onHistory,
                animated: animated,
              ),
              const SizedBox(height: legalGap),
              _legal(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buyButton() => PrimaryButton(
    key: buyKey,
    label: buyLabel,
    loading: state == OfferCardState.purchasing,
    identifier: identifiers.buy,
    // offline은 꺼짐(null), purchasing은 PrimaryButton이 눌림을 무시합니다.
    onPressed: state == OfferCardState.offline ? null : onBuy,
    animated: animated,
  );

  /// 이용 중: `tag.status` 꼬리표 + 남은 기간·만료일.
  Widget _activeStatus(BuildContext context) {
    final tokens = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: _statusGap,
      children: [
        if (statusLabel != null) StatusTag(statusLabel!),
        if (remaining != null)
          Semantics(
            identifier: identifiers.remaining,
            child: Text(
              remaining!,
              style: tokens.typography.bodyUi.copyWith(
                color: tokens.colors.textPrimary,
                fontFeatures: _tabular,
              ),
            ),
          ),
      ],
    );
  }

  Widget _legal(BuildContext context) {
    final tokens = context.tokens;
    return VerticalHitSlop(
      minHeight: 48,
      child: PressInkTarget(
        key: legalKey,
        semanticLabel: legalNotice,
        identifier: identifiers.legal,
        link: true,
        onTap: onLegal,
        borderRadius: const BorderRadius.all(Radius.circular(Radii.sm)),
        inkColor: tokens.colors.textSecondary,
        child: Text(
          legalNotice,
          style: tokens.typography.captionMd.copyWith(
            color: tokens.colors.textSecondary,
          ),
        ),
      ),
    );
  }
}
