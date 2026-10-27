import 'package:flutter/material.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/component_spec.dart';
import 'package:myungli_diary/design/elements/skeleton_bone.dart';
import 'package:myungli_diary/design/elements/status_tag.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

/// 구매 한 건의 표시 값(`purchase-row`). 문자열은 모두 화면이 ARB에서 만들어 넘깁니다.
final class PurchaseRowData {
  /// 구매 한 건을 만듭니다. [status]가 null이면 상태 자리가 없습니다.
  const new({
    required this.product,
    required this.purchased,
    this.period,
    this.status,
    this.active = false,
  });

  /// 상품 이름(`ui.purchase.product`). 길면 말줄임 없이 감깁니다.
  final String product;

  /// 상태 낱말(`ui.purchase.status`). null이면 보이지 않습니다.
  final String? status;

  /// true면 상태를 `tag.status` 꼬리표로, 아니면 바탕 없는 글자로 그립니다.
  final bool active;

  /// 구매일 줄(`ui.purchase.meta`의 `purchaseMetaPurchased`).
  final String purchased;

  /// 사용 기간 줄(`ui.purchase.meta`의 `purchaseMetaPeriod`). null이면 보이지 않습니다.
  ///
  /// 구매일과 한 줄로 잇지 않고 그 아래 [PurchaseRowGroup.periodGap]에 둡니다
  /// (writing W44, design V47).
  final String? period;
}

/// 산 상품 줄들을 카드 한 장에 담은 묶음(`purchase-row`, D88 ②, V45).
///
/// 줄은 누를 수 없고(눌림 상태 없음) 줄 사이에만 1px `line` 구분선이 있습니다. 순서는
/// 넘겨받은 [rows] 그대로이며 다시 정렬하지 않습니다. 스크린리더는 한 줄을 상품 이름, 상태, 구매일,
/// 사용 기간 한 덩어리로 읽습니다.
class PurchaseRowGroup extends StatelessWidget {
  /// 묶음을 만듭니다.
  const new({
    required List<PurchaseRowData> this.rows,
    this.animated = true,
    super.key,
  });

  /// 불러오는 중: 줄 세 개 자리(상품 이름 줄 + 구매일 줄 + 사용 기간 줄 뼈, V47).
  /// 스크린리더는 읽지 않습니다.
  const new loading({this.animated = true, super.key}) : rows = null;

  /// 명세 대조용 요약.
  static const ComponentSpec spec = ComponentSpec('purchase-row', {}, {
    'loading',
  });

  /// 줄을 찾는 테스트용 키.
  static const Key rowKey = ValueKey('purchase-row');

  /// 줄 사이 구분선을 찾는 테스트용 키.
  static const Key dividerKey = ValueKey('purchase-row-divider');

  /// 상태 자리를 찾는 테스트용 키.
  static const Key statusKey = ValueKey('purchase-row-status');

  /// 묶음 좌우 안쪽 여백(`parts.group.paddingX`, `space.16`).
  static const double paddingX = Space.s16;

  /// 줄 위아래 안쪽 여백(`parts.row.paddingY`, `space.16`).
  static const double rowPaddingY = Space.s16;

  /// 상품 이름과 상태 사이(`parts.status.gap`, `space.12`).
  static const double statusGap = Space.s12;

  /// 상품 줄과 meta 줄 사이(`parts.meta.marginTop`, `space.4`).
  static const double metaGap = Space.s4;

  /// 구매일 줄과 사용 기간 줄 사이(`parts.meta.period.marginTop`, `space.2`).
  static const double periodGap = Space.s2;

  /// 상태 글자 최대 폭(`parts.status.maxWidth`).
  static const double statusMaxWidth = 80;

  static const int _skeletonRowCount = 3;
  static const double _productBoneWidth = 160;
  static const double _purchasedBoneWidth = 120;
  static const double _periodBoneWidth = 200;
  static const double _boneHeight = SkeletonBone.lineHeight;

  /// loading에서 상품 줄 뼈와 구매일 줄 뼈 사이(실제 줄 높이 차이를 뼈 높이로 어림).
  static const double _skeletonLineGap = metaGap + Space.s8;

  /// loading에서 구매일 줄 뼈와 사용 기간 줄 뼈 사이(같은 어림).
  static const double _skeletonPeriodGap = periodGap + Space.s4;

  static const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

  /// 줄들. `loading`이면 null입니다.
  final List<PurchaseRowData>? rows;

  /// false면 loading 뼈가 정지 상태로 그려집니다(golden).
  final bool animated;

  @override
  Widget build(BuildContext context) {
    final data = rows;
    final children = data == null
        ? [for (var i = 0; i < _skeletonRowCount; i++) _skeletonRow(i)]
        : [for (final row in data) _row(context, row)];
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, child) in children.indexed) ...[
          if (index > 0) const _Divider(),
          // 같은 키를 가진 줄이 형제로 놓이지 않게 키 없는 Builder로 감쌉니다.
          Builder(builder: (_) => child),
        ],
      ],
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.tokens.colors.bgSheet,
        borderRadius: const BorderRadius.all(Radius.circular(Radii.lg)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: paddingX),
        child: data == null ? ExcludeSemantics(child: body) : body,
      ),
    );
  }

  Widget _row(BuildContext context, PurchaseRowData row) {
    final tokens = context.tokens;
    final l10n = AppLocalizations.of(context);
    final status = row.status;
    final period = row.period;
    final metaStyle = tokens.typography.captionLg.copyWith(
      color: tokens.colors.textSecondary,
      fontFeatures: _tabular,
    );
    return Semantics(
      key: rowKey,
      container: true,
      label: [
        row.product,
        ?status,
        row.purchased,
        ?period,
      ].join(l10n.a11yListSeparator),
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: rowPaddingY),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      row.product,
                      style: tokens.typography.subtitle.copyWith(
                        color: tokens.colors.textPrimary,
                      ),
                    ),
                  ),
                  if (status != null) ...[
                    const SizedBox(width: statusGap),
                    ConstrainedBox(
                      key: statusKey,
                      constraints: const BoxConstraints(
                        maxWidth: statusMaxWidth,
                      ),
                      child: _status(context, status, active: row.active),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: metaGap),
              Text(row.purchased, style: metaStyle),
              if (period != null) ...[
                const SizedBox(height: periodGap),
                Text(period, style: metaStyle),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 상태: 사용 중은 `tag.status`, 그 밖은 바탕 없는 `type.label.md` 글자.
  ///
  /// 상품 이름 첫 줄 높이 안에서 세로 가운데에 놓아 줄 높이가 다른 글자도 첫 줄과 맞춥니다
  /// (`align: product-first-line`).
  Widget _status(BuildContext context, String status, {required bool active}) {
    final tokens = context.tokens;
    final subtitle = tokens.typography.subtitle;
    final scaler = MediaQuery.textScalerOf(context);
    final firstLineHeight =
        scaler.scale(subtitle.fontSize ?? 0) * (subtitle.height ?? 1);
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: firstLineHeight),
      child: Center(
        widthFactor: 1,
        child: active
            ? StatusTag(status)
            : Text(
                status,
                textAlign: TextAlign.end,
                style: tokens.typography.labelMd.copyWith(
                  color: tokens.colors.textSecondary,
                ),
              ),
      ),
    );
  }

  Widget _skeletonRow(int index) => Padding(
    key: rowKey,
    padding: const EdgeInsets.symmetric(vertical: rowPaddingY),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SkeletonBone(
          width: _productBoneWidth,
          height: _boneHeight,
          borderRadius: Radii.xs,
          index: index,
          animated: animated,
        ),
        const SizedBox(height: _skeletonLineGap),
        SkeletonBone(
          width: _purchasedBoneWidth,
          height: _boneHeight,
          borderRadius: Radii.xs,
          index: index + 1,
          animated: animated,
        ),
        const SizedBox(height: _skeletonPeriodGap),
        SkeletonBone(
          width: _periodBoneWidth,
          height: _boneHeight,
          borderRadius: Radii.xs,
          index: index + 2,
          animated: animated,
        ),
      ],
    ),
  );
}

/// 줄 사이 선: 1px `line`.
class _Divider extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => ColoredBox(
    key: PurchaseRowGroup.dividerKey,
    color: context.tokens.colors.line,
    child: const SizedBox(height: 1, width: double.infinity),
  );
}
