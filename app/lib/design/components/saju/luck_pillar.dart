import 'package:flutter/material.dart';
import 'package:myungli_diary/core/api/gen/model/five_element.dart';
import 'package:myungli_diary/design/components/component_spec.dart';
import 'package:myungli_diary/design/components/feedback/skeleton.dart';
import 'package:myungli_diary/design/components/saju/luck_label.dart';
import 'package:myungli_diary/design/components/saju/tag_slot.dart';
import 'package:myungli_diary/design/components/sentence/term_token.dart';
import 'package:myungli_diary/design/elements/highlight_current.dart';
import 'package:myungli_diary/design/elements/ohaeng_cell.dart';
import 'package:myungli_diary/design/elements/skeleton_bone.dart';
import 'package:myungli_diary/design/elements/status_tag.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

/// 기둥 한 칸의 간지: 천간과 지지의 오행과 한자 한 글자씩(`ohaeng.cell` 입력).
///
/// design 계층이 features 모델을 몰라도 되도록 화면이 자기 간지를 이 값으로 바꿔 넘깁니다.
@immutable
final class LuckGanji {
  /// 천간 칸과 지지 칸의 오행과 한자로 만듭니다.
  const new({
    required this.stemElement,
    required this.stemHanja,
    required this.branchElement,
    required this.branchHanja,
  });

  /// 천간 오행.
  final FiveElement stemElement;

  /// 천간 한자 한 글자.
  final String stemHanja;

  /// 지지 오행.
  final FiveElement branchElement;

  /// 지지 한자 한 글자.
  final String branchHanja;

  OhaengCell _stemCell() => OhaengCell(
    element: stemElement,
    hanja: stemHanja,
    size: OhaengCellSize.small,
  );

  OhaengCell _branchCell() => OhaengCell(
    element: branchElement,
    hanja: branchHanja,
    size: OhaengCellSize.small,
  );
}

/// 대운, 세운 기둥 한 칸(`luck-pillar`, V77, V90).
///
/// [LuckPillar.column]은 사주 표 대운·세운 줄의 기둥입니다: 위 나이 또는 연도, 천간 십성, 천간
/// 칸, 지지 칸(`ohaeng.cell` `small`), 지지 십성, 12운성, 시작 연도. 지금(`current`)이면
/// `highlight.current` 바탕이 칸들을 덮고, 꼬리표(`tag.status`)는 바탕 밖 아래에 두어 이웃 기둥
/// 아래로 넘쳐도 됩니다(V53).
///
/// [LuckPillar.compact]는 나 탭 올해와 지금 카드의 한 줄입니다: 왼쪽에 천간·지지 칸을 세로로,
/// 오른쪽에 머리(꼬리표 + 용어 칩), 기간, 십성 칩. 강조 바탕이 없습니다.
///
/// 글자 크기는 1.3배에서 멈춥니다(`textScaleMax`).
class LuckPillar extends StatelessWidget {
  /// 사주 표 줄의 기둥입니다.
  ///
  /// [top]은 나이 또는 연도, [tenGod]은 천간 십성입니다. [currentTag]를 주면 꼬리표 자리를 늘
  /// 남기고(줄 높이가 흔들리지 않게) [current]일 때만 보입니다. 줄 양 끝 기둥은 [tagEdge]로
  /// 꼬리표가 줄 밖으로 나가지 않게 합니다. 줄 높이 맞춤은 줄이 맡습니다.
  const new column({
    required this.pillar,
    required this.top,
    required this.tenGod,
    required this.semanticLabel,
    this.branchTenGod,
    this.twelveStage,
    this.startYear,
    this.current = false,
    this.currentTag,
    this.tagEdge = TagEdge.none,
    super.key,
  }) : _compact = false,
       tagLabel = null,
       kindLabel = null,
       onKindTap = null,
       period = null,
       tenGods = const [];

  /// 나 탭 올해와 지금 카드의 한 줄입니다.
  ///
  /// [tagLabel]은 "지금"/"올해", [kindLabel]은 용어 칩 "대운"/"세운"([onKindTap]이 없으면 글자만), [period]는 기간 줄,
  /// [tenGods]는 천간, 지지 순 십성(세운은 하나)입니다.
  const new compact({
    required this.pillar,
    required this.tagLabel,
    required this.kindLabel,
    required this.period,
    required this.tenGods,
    required this.semanticLabel,
    this.onKindTap,
    super.key,
  }) : _compact = true,
       top = null,
       tenGod = null,
       branchTenGod = null,
       twelveStage = null,
       startYear = null,
       current = true,
       currentTag = null,
       tagEdge = TagEdge.none;

  /// 명세 대조용 요약.
  static const ComponentSpec spec = ComponentSpec(
    'luck-pillar',
    {'column', 'compact'},
    {'current', 'thisYear', 'loading'},
  );

  /// 기둥 폭(`luck-pillar` `parts.container.width`).
  static const double columnWidth = 52;

  /// 기둥 안쪽 여백(`parts.container.padding` `space.4`).
  static const double columnPadding = Space.s4;

  /// 꼬리표 최대 폭: 기둥 둘과 그 사이 간격(`parts.currentTag.maxWidth`, 줄 간격 4).
  static const double tagMaxWidth = columnWidth * 2 + Space.s4;

  /// 강조 바탕을 찾는 테스트용 키(`column` 지금).
  static const Key highlightKey = ValueKey('luck-pillar-highlight');

  /// 꼬리표 자리를 찾는 테스트용 키.
  static const Key tagKey = ValueKey('luck-pillar-tag');

  /// 기간 줄을 찾는 테스트용 키(`compact`).
  static const Key periodKey = ValueKey('luck-pillar-period');

  /// 불러오는 중 뼈(`compact`): 칸 두 개와 십성 칩(너비 36).
  static Widget skeleton({int index = 0, bool animated = true}) => Builder(
    builder: (context) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          spacing: Space.s4,
          children: [
            for (var i = 0; i < 2; i++)
              SkeletonBone(
                width: OhaengCell.smallSide,
                height: OhaengCell.smallSide,
                borderRadius: Radii.sm,
                index: index + i,
                animated: animated,
              ),
          ],
        ),
        const SizedBox(width: Space.s12),
        SkeletonChip(
          width: _chipSkeletonWidth,
          height: _chipSkeletonHeight(context),
          index: index + 2,
          animated: animated,
        ),
      ],
    ),
  );

  // 십성 칩 뼈 너비(luck-pillar states.loading skeleton tenGods width 36px).
  static const double _chipSkeletonWidth = 36;

  static double _chipSkeletonHeight(BuildContext context) =>
      context.tokens.typography.captionMd.fontSize! *
      context.tokens.typography.captionMd.height!;

  /// 간지.
  final LuckGanji pillar;

  final bool _compact;

  /// 위 나이 또는 연도(`column`).
  final String? top;

  /// 천간 십성 칩(`column`).
  final LuckLabel? tenGod;

  /// 지지 십성 칩(`column`, 대운만).
  final LuckLabel? branchTenGod;

  /// 12운성 칩(`column`, 대운만).
  final LuckLabel? twelveStage;

  /// 시작 연도(`column`, 대운만).
  final String? startYear;

  /// 지금 대운, 올해 세운이면 true(`column`). `compact`는 늘 지금이지만 바탕을 칠하지 않습니다.
  final bool current;

  /// 꼬리표 글자 "지금"/"올해"(`column`). null이면 꼬리표 자리를 두지 않습니다.
  final String? currentTag;

  /// 꼬리표가 놓인 기둥이 줄 어느 끝인지(`column`).
  final TagEdge tagEdge;

  /// 머리 꼬리표 글자(`compact`).
  final String? tagLabel;

  /// 머리 용어 칩 글자 "대운"/"세운"(`compact`).
  final String? kindLabel;

  /// 용어 칩을 누르면(`compact`).
  final VoidCallback? onKindTap;

  /// 기간 줄 글자(`compact`).
  final String? period;

  /// 십성 칩(`compact`, 천간 다음 지지).
  final List<LuckLabel> tenGods;

  /// 스크린리더 그룹 라벨(나이 또는 연도, 천간 십성, 간지, 지지 십성).
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context)
        .clamp(maxScaleFactor: OhaengCell.textScaleMax);
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: scaler),
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        label: current && currentTag != null
            ? '$semanticLabel, $currentTag'
            : semanticLabel,
        child: _compact ? _buildCompact(context) : _buildColumn(context),
      ),
    );
  }

  Widget _buildColumn(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final topStyle = tokens.typography.numericTable.copyWith(
      color: current ? colors.actionPrimary : colors.textSecondary,
      fontWeight: current ? FontWeight.w700 : null,
    );
    final numberStyle = tokens.typography.numericTable.copyWith(
      color: colors.textSecondary,
    );
    const innerWidth = columnWidth - columnPadding * 2;
    // 누를 수 있는 칩은 별도 포커스(button)로 남기고, 글자뿐인 라벨은 그룹 라벨이 읽습니다.
    Widget label(LuckLabel value, double gapBefore) {
      final view = LuckLabelView(label: value, width: innerWidth);
      return Padding(
        padding: EdgeInsets.only(top: gapBefore),
        child: value.onTap == null ? ExcludeSemantics(child: view) : view,
      );
    }

    final body = Padding(
      padding: const EdgeInsets.all(columnPadding),
      child: Column(
        children: [
          ExcludeSemantics(child: Text(top!, style: topStyle)),
          label(tenGod!, Space.s4),
          const SizedBox(height: Space.s4),
          pillar._stemCell(),
          const SizedBox(height: Space.s4),
          pillar._branchCell(),
          if (branchTenGod != null) label(branchTenGod!, Space.s4),
          if (twelveStage != null) label(twelveStage!, Space.s2),
          if (startYear != null) ...[
            const SizedBox(height: Space.s4),
            ExcludeSemantics(child: Text(startYear!, style: numberStyle)),
          ],
        ],
      ),
    );
    final radius = BorderRadius.circular(Radii.md);
    final tag = currentTag;
    return SizedBox(
      width: columnWidth,
      child: Column(
        children: [
          if (current)
            ClipRRect(
              key: highlightKey,
              borderRadius: radius,
              child: HighlightCurrent(
                child: SizedBox(width: columnWidth, child: body),
              ),
            )
          else
            body,
          if (tag != null) ...[
            const SizedBox(height: Space.s4),
            // 꼬리표 자리는 모든 기둥이 같은 높이로 둡니다. 넘치면 이웃 아래 빈 자리로 갑니다.
            ExcludeSemantics(
              child: TagSlot(
                key: tagKey,
                maxWidth: tagMaxWidth,
                edge: tagEdge,
                child: Visibility.maintain(
                  visible: current,
                  child: StatusTag(tag),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 용어 칩. [onTap]이 없으면(한자 대체 등) 글자만 두고 그룹 라벨이 읽습니다. 누를 수 있으면
  /// 별도 포커스(button)로 남습니다.
  static Widget _chip(String text, VoidCallback? onTap, MyungliTokens tokens) {
    if (onTap == null) {
      return ExcludeSemantics(
        child: Text(
          text,
          style: tokens.typography.captionMd.copyWith(
            color: tokens.colors.textSecondary,
          ),
        ),
      );
    }
    return TermToken(
      label: text,
      variant: TermTokenVariant.label,
      onTap: onTap,
    );
  }

  Widget _buildCompact(BuildContext context) {
    final tokens = context.tokens;
    final periodStyle = tokens.typography.captionLg.copyWith(
      color: tokens.colors.textSecondary,
      // 기간 숫자는 고정폭(계약 parts.period.fontFeatures tnum).
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          spacing: Space.s4,
          children: [pillar._stemCell(), pillar._branchCell()],
        ),
        const SizedBox(width: Space.s12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: Space.s4,
                runSpacing: Space.s4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ExcludeSemantics(child: StatusTag(tagLabel!)),
                  _chip(kindLabel!, onKindTap, tokens),
                ],
              ),
              const SizedBox(height: Space.s4),
              ExcludeSemantics(
                child: Text(period!, key: periodKey, style: periodStyle),
              ),
              if (tenGods.isNotEmpty) ...[
                const SizedBox(height: Space.s4),
                Wrap(
                  spacing: Space.s4,
                  runSpacing: Space.s4,
                  children: [
                    for (final god in tenGods)
                      _chip(god.text, god.onTap, tokens),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
