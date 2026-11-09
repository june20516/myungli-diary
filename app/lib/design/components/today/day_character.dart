import 'package:flutter/material.dart';
import 'package:myungli_diary/core/api/gen/model/day_kind.dart';
import 'package:myungli_diary/core/api/gen/model/rendered_text.dart';
import 'package:myungli_diary/core/api/rendered_text_plain.dart';
import 'package:myungli_diary/design/components/component_spec.dart';
import 'package:myungli_diary/design/components/feedback/skeleton.dart';
import 'package:myungli_diary/design/components/sentence/rendered_text_view.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

/// 날의 성격 변형(`day-character` `variants`).
enum DayCharacterVariant {
  /// 용신의 날(`YONGSIN_DAY`). 앱에서는 "좋은 날"로 강조합니다(D20).
  good,

  /// 귀인의 날(`GWIIN_DAY`).
  gwiin,

  /// 기신의 날(`GISIN_DAY`).
  gisin,

  /// 평범한 날(`ORDINARY_DAY`). 바탕 없이 테두리만입니다.
  ordinary,
}

/// 서버가 내려 준 날의 성격을 배지 변형으로 옮깁니다.
DayCharacterVariant dayCharacterVariantOf(DayKind kind) => switch (kind) {
  DayKind.yongsinDay => DayCharacterVariant.good,
  DayKind.gwiinDay => DayCharacterVariant.gwiin,
  DayKind.gisinDay => DayCharacterVariant.gisin,
  DayKind.ordinaryDay => DayCharacterVariant.ordinary,
};

/// 날의 성격 배지 색(V8 매핑): 바탕(없으면 null), 글자, 테두리(평범한 날만).
///
/// `day-character`의 배지와 `hanja-tag` `emphasis`가 같은 매핑을 씁니다.
({Color? bg, Color fg, Color? border}) dayCharacterBadgeColors(
  DayCharacterVariant variant,
  ColorTokens colors,
) => switch (variant) {
  DayCharacterVariant.good => (
    bg: colors.badgeGoodBg,
    fg: colors.badgeGoodFg,
    border: null,
  ),
  DayCharacterVariant.gwiin => (
    bg: colors.badgeGwiinBg,
    fg: colors.badgeGwiinFg,
    border: null,
  ),
  DayCharacterVariant.gisin => (
    bg: colors.badgeGisinBg,
    fg: colors.badgeGisinFg,
    border: null,
  ),
  DayCharacterVariant.ordinary => (
    bg: null,
    fg: colors.badgeOrdinaryFg,
    border: colors.badgeOrdinaryBorder,
  ),
};

/// 날의 성격 배지와 이유 한 줄(`day-character`).
///
/// 배지는 글자([label])로 날의 성격을 말합니다. 색만으로 전하지 않습니다.
/// [reason]은 server가 렌더한 문장 조각이고, 이유 줄 끝에 [reasonTrailing]
/// (`depth-link` `inline-end`)을 붙입니다. 배지 높이 26은 최소값이라 기기 글자가
/// 커지면 함께 커집니다. 스크린리더는 "배지 글자, 이유"를 한 번에 읽습니다.
class DayCharacter extends StatelessWidget {
  /// 배지와 이유 줄을 만듭니다.
  const new({
    required this.variant,
    required this.label,
    this.reason,
    this.reasonSlotId,
    this.reasonTrailing,
    super.key,
  });

  /// 명세 대조용 요약.
  static const ComponentSpec spec = ComponentSpec(
    'day-character',
    {'good', 'gwiin', 'gisin', 'ordinary'},
    {'loading'},
  );

  /// 뼈 `badge` 너비(`states.loading.skeleton` `badge.width` 72px).
  static const double skeletonBadgeWidth = 72;

  /// 뼈 `reason` 폭 비율(`states.loading.skeleton` `reason.width` 80%).
  static const double skeletonReasonWidthFactor = 0.8;

  /// 불러오는 중 뼈: 배지 칩(72) 아래 [Space.s8]에 이유 글줄 한 줄(80%).
  static Widget skeleton({int index = 0, bool animated = true}) => Builder(
    builder: (context) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SkeletonChip(
          width: skeletonBadgeWidth,
          height: DayCharacterBadge.minHeight,
          index: index,
          animated: animated,
        ),
        const SizedBox(height: Space.s8),
        SkeletonTextLines(
          style: context.tokens.typography.captionLg,
          widthFactor: skeletonReasonWidthFactor,
          index: index + 1,
          animated: animated,
        ),
      ],
    ),
  );

  /// 배지 면을 찾는 테스트용 키.
  static const Key badgeKey = DayCharacterBadge.surfaceKey;

  /// 이유 줄을 찾는 테스트용 키.
  static const Key reasonKey = ValueKey('day-character-reason');

  /// 변형.
  final DayCharacterVariant variant;

  /// 배지 글자(날의 성격 이름, ARB 문구).
  final String label;

  /// 이유 문장. 없으면 이유 줄을 그리지 않습니다.
  final RenderedText? reason;

  /// 이유 줄이 채우는 IA 슬롯 id(`SlotIds`). 있으면 이유 줄에 Semantics
  /// `identifier`로 붙습니다(`SentenceBlock`의 `slotId`와 같은 방식). 읽기는
  /// 배지와 합친 라벨 하나 그대로입니다.
  final String? reasonSlotId;

  /// 이유 줄 끝에 붙는 위젯(`depth-link` `inline-end`).
  final Widget? reasonTrailing;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final badge = DayCharacterBadge(variant: variant, label: label);
    final reasonText = reason;
    final hasReason = reasonText != null && reasonText.segments.isNotEmpty;
    final spoken = hasReason ? '$label, ${plainTextOf(reasonText)}' : label;
    // 배지와 이유는 합친 라벨 하나로 읽고, 화면 글자(배지·이유)는 같은 말을 다시 읽지 않게
    // 숨깁니다. 이유 글자는 읽히지 않게 숨기고, 줄 끝에 끼운 링크(reasonTrailing)만
    // 자기 노드로 따로 초점을 받습니다.
    return Semantics(
      container: true,
      label: spoken,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: ExcludeSemantics(child: badge),
          ),
          if (hasReason)
            _withSlotId(
              reasonSlotId,
              Padding(
                key: reasonKey,
                padding: const EdgeInsets.only(top: Space.s8),
                child: RenderedTextView(
                  text: reasonText,
                  style: tokens.typography.captionLg.copyWith(
                    color: colors.textSecondary,
                  ),
                  trailing: reasonTrailing,
                  hideTextSemantics: true,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// [slotId]가 있으면 [child]를 그 identifier의 Semantics 노드로 감쌉니다.
  static Widget _withSlotId(String? slotId, Widget child) => slotId == null
      ? child
      : Semantics(identifier: slotId, container: true, child: child);
}

/// 날의 성격 배지 하나(`day-character` `badge`).
///
/// [DayCharacter]가 쓰고, 공유 이미지(`share-image` `badge`)가 배지만 따로 씁니다.
/// 높이 26은 최소값이라 기기 글자가 커지면 함께 커집니다.
class DayCharacterBadge extends StatelessWidget {
  /// 배지를 만듭니다.
  const new({required this.variant, required this.label, super.key});

  /// 배지 면을 찾는 테스트용 키.
  static const Key surfaceKey = ValueKey('day-character-badge');

  /// 배지 최소 높이(기본 글자 크기에서의 높이, V30). skeleton도 이 높이로 자리를 잡습니다.
  static const double minHeight = 26;
  static const double _paddingX = 10;

  /// 변형.
  final DayCharacterVariant variant;

  /// 배지 글자(날의 성격 이름, ARB 문구).
  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final (:bg, :fg, :border) = dayCharacterBadgeColors(variant, colors);
    return DecoratedBox(
      key: surfaceKey,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.all(Radius.circular(Radii.full)),
        border: border == null ? null : Border.all(color: border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: minHeight),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: _paddingX),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: Text(
              label,
              style: tokens.typography.labelMd.copyWith(color: fg),
            ),
          ),
        ),
      ),
    );
  }
}
