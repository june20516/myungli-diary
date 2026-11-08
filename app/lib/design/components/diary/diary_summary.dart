import 'package:flutter/material.dart';
import 'package:myungli_diary/core/api/gen/model/day_kind.dart';
import 'package:myungli_diary/core/api/gen/model/diary_stats.dart';
import 'package:myungli_diary/core/api/gen/model/tag.dart';
import 'package:myungli_diary/core/api/gen/model/tag_count.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/component_spec.dart';
import 'package:myungli_diary/design/components/feedback/skeleton.dart';
import 'package:myungli_diary/design/components/sentence/hanja_glyphs.dart';
import 'package:myungli_diary/design/components/sentence/hanja_tag.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

/// 태그 키 → 보일 이름. 사전에 이름이 없으면 null입니다(그 태그는 그리지 않습니다).
typedef DiaryTagNameOf = String? Function(Tag tag);

/// 나 탭 명리일기 회고 카드(`diary-summary`, V76, S146, A119).
///
/// 위에서부터 쓴 편수, 날의 성격 막대 넷, 자주 붙은 태그입니다. 편수는 편 단위이고 막대와
/// 태그의 수는 날짜 단위입니다(S146). 쓴 편수가 [fewThreshold]편 미만이면 막대를 숨기고
/// 안내 한 줄을 둡니다(0편도 같음). 태그가 없으면 머리와 줄을 그리지 않습니다. 태그를 누르면
/// [onTagTap]이 불립니다(뜻 시트 열기는 화면 몫). 글자 배율은 [textScaleMax]까지만 따릅니다.
class DiarySummary extends StatelessWidget {
  /// 집계 [stats]로 카드를 만듭니다.
  const new({
    required this.stats,
    required this.tagNameOf,
    required this.onTagTap,
    super.key,
  });

  /// 불러오는 중 뼈(`states.loading.skeleton`). 머리 글자는 바로 보입니다.
  static Widget skeleton({bool animated = true}) =>
      _DiarySummarySkeleton(animated: animated);

  /// 명세 대조용 요약.
  static const ComponentSpec spec = ComponentSpec('diary-summary', {}, {
    'few',
    'loading',
  });

  /// 기록이 적을 때의 편수 경계(`states.few.threshold`).
  static const int fewThreshold = 5;

  /// 보이는 태그 상한(`parts.tags.tag.max`).
  static const int maxTags = 3;

  /// 글자 배율 상한(`a11y.textScaleMax`).
  static const double textScaleMax = 1.3;

  /// 막대 줄 순서(`parts.dayKinds.order`).
  static const List<DayKind> dayKindOrder = [
    DayKind.yongsinDay,
    DayKind.gwiinDay,
    DayKind.ordinaryDay,
    DayKind.gisinDay,
  ];

  /// 이름 칸 폭(`parts.dayKinds.name.width` 72px).
  static const double nameWidth = 72;

  /// 막대 높이(`parts.dayKinds.bar.height` 8px).
  static const double barHeight = 8;

  /// 수 칸 폭(`parts.dayKinds.count.width` 28px).
  static const double countWidth = 28;

  /// 줄 최소 높이(`parts.dayKinds.row.minHeight` 24px).
  static const double rowMinHeight = 24;

  /// 편수 글자 크기(`parts.count.fontSize` 28px).
  static const double countFontSize = 28;

  /// 막대 트랙을 찾는 테스트용 키(줄 순서대로 `index`).
  static Key trackKey(int index) => ValueKey('diary-summary-track-$index');

  /// 막대 채움을 찾는 테스트용 키(줄 순서대로 `index`).
  static Key fillKey(int index) => ValueKey('diary-summary-fill-$index');

  /// 기록이 적을 때 안내 글줄을 찾는 테스트용 키.
  static const Key fewNoticeKey = ValueKey('diary-summary-few');

  /// 집계.
  final DiaryStats stats;

  /// 태그 이름. 사전에 없으면 null.
  final DiaryTagNameOf tagNameOf;

  /// 태그를 눌렀을 때.
  final void Function(Tag tag) onTagTap;

  /// 보일 태그: 수 많은 순(같으면 응답 순서) 가운데 이름과 한자가 있는 앞의 [maxTags]개.
  ///
  /// 표에 없는 태그는 건너뜁니다.
  static List<TagCount> shownTags(DiaryStats stats, DiaryTagNameOf tagNameOf) {
    // List.sort는 안정적이지 않아 같은 수는 응답 순서(원래 인덱스)를 보조 키로 씁니다.
    final indexed = [...stats.topTags.indexed]
      ..sort((a, b) {
        final byDays = b.$2.days.compareTo(a.$2.days);
        return byDays != 0 ? byDays : a.$1.compareTo(b.$1);
      });
    final sorted = [for (final (_, count) in indexed) count];
    return [
      for (final count in sorted)
        if (_isShown(count.tag, tagNameOf)) count,
    ].take(maxTags).toList();
  }

  /// 그리지 못해 건너뛴 태그 키(이름이나 한자가 없음). 화면이 비치명으로 보고합니다(A112).
  static List<String> skippedTagKeys(
    DiaryStats stats,
    DiaryTagNameOf tagNameOf,
  ) => [
    for (final count in stats.topTags)
      if (!_isShown(count.tag, tagNameOf)) count.tag.key,
  ];

  static bool _isShown(Tag tag, DiaryTagNameOf tagNameOf) =>
      tagNameOf(tag) != null && HanjaGlyphs.forTagKey(tag.key) != null;

  /// 날의 성격의 막대 길이 비율. 가장 큰 수가 0이면 모두 0입니다.
  static double barFraction(int days, int maxDays) =>
      maxDays <= 0 ? 0 : (days / maxDays).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = context.tokens;
    final daysOf = {for (final item in stats.dayKinds) item.dayKind: item.days};
    final rowDays = [for (final kind in dayKindOrder) daysOf[kind] ?? 0];
    final maxDays = rowDays.fold(0, (a, b) => a > b ? a : b);
    final few = stats.entryCount < fewThreshold;
    final tags = shownTags(stats, tagNameOf);
    final nameOfKind = _dayKindNames(l10n);

    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: textScaleMax,
      child: _Card(
        // 계약 a11y: role group(역할 값이 없어 container로 묶음).
        // label("편수, 날의 성격마다 이름과 수, 태그 이름과 수")은 자식
        // 낭독(편수 줄, 막대 줄마다 이름과 수, 태그 이름과 수)을 그대로 합성한 설명이라 따로
        // 붙이지 않고 group 묶음만 둡니다(같은 말을 두 번 읽지 않게).
        child: Semantics(
          container: true,
          explicitChildNodes: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MergeSemantics(
                child: _CountLine(
                  count: stats.entryCount,
                  unit: l10n.mySajuRecordCountUnit(stats.entryCount),
                ),
              ),
              if (few)
                Padding(
                  padding: const EdgeInsets.only(top: Space.s12),
                  child: Text(
                    l10n.mySajuRecordFew,
                    key: fewNoticeKey,
                    style: tokens.typography.captionLg.copyWith(
                      color: tokens.colors.textSecondary,
                    ),
                  ),
                )
              else ...[
                _Head(l10n.mySajuRecordDayKindHead),
                for (var i = 0; i < dayKindOrder.length; i++) ...[
                  if (i > 0) const SizedBox(height: Space.s8),
                  _BarRow(
                    index: i,
                    name: nameOfKind(dayKindOrder[i]),
                    days: rowDays[i],
                    fraction: barFraction(rowDays[i], maxDays),
                    fill: _fillOf(dayKindOrder[i], tokens.colors),
                  ),
                ],
              ],
              if (tags.isNotEmpty) ...[
                _Head(l10n.mySajuRecordTagHead),
                Wrap(
                  spacing: Space.s8,
                  runSpacing: Space.s8,
                  children: [
                    for (final count in tags)
                      HanjaTag(
                        glyph: HanjaGlyphs.forTagKey(count.tag.key)!,
                        label: tagNameOf(count.tag)!,
                        trailing: '${count.days}',
                        onTap: () => onTagTap(count.tag),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 막대 색: 날의 성격 톤의 진한 쪽(`parts.dayKinds.fill`).
  static Color _fillOf(DayKind kind, ColorTokens colors) => switch (kind) {
    DayKind.yongsinDay => colors.badgeGoodBg,
    DayKind.gwiinDay => colors.badgeGwiinFg,
    DayKind.ordinaryDay => colors.badgeOrdinaryBorder,
    DayKind.gisinDay => colors.badgeGisinFg,
  };

  static String Function(DayKind) _dayKindNames(AppLocalizations l10n) =>
      (kind) => switch (kind) {
        DayKind.yongsinDay => l10n.dayKindYongsinDay,
        DayKind.gwiinDay => l10n.dayKindGwiinDay,
        DayKind.ordinaryDay => l10n.dayKindOrdinaryDay,
        DayKind.gisinDay => l10n.dayKindGisinDay,
      };
}

/// 카드 바탕(`bg.sheet`, `radius.lg`, 안쪽 `space.16`).
class _Card extends StatelessWidget {
  const new({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: context.tokens.colors.bgSheet,
        borderRadius: const BorderRadius.all(Radius.circular(Radii.lg)),
      ),
      child: Padding(padding: const EdgeInsets.all(Space.s16), child: child),
    ),
  );
}

/// 편수: 28 700 고정폭 숫자 + 단위(숫자 기준선에 맞춤, 사이 `space.4`).
class _CountLine extends StatelessWidget {
  const new({required this.count, required this.unit});

  final int count;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          '$count',
          style: tokens.typography.bodyUi.copyWith(
            fontSize: DiarySummary.countFontSize,
            fontWeight: FontWeight.w700,
            color: tokens.colors.textPrimary,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(width: Space.s4),
        Text(
          unit,
          style: tokens.typography.labelLg.copyWith(
            color: tokens.colors.textPrimary,
          ),
        ),
      ],
    );
  }
}

/// 섹션 머리 글자(위 `space.16`, 아래 `space.8`).
class _Head extends StatelessWidget {
  const new(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(top: Space.s16, bottom: Space.s8),
      child: Text(
        text,
        style: tokens.typography.labelMd.copyWith(
          color: tokens.colors.textSecondary,
        ),
      ),
    );
  }
}

/// 막대 한 줄: 이름 칸 + 막대 + 수. 막대는 꾸밈이라 읽지 않고 이름과 수만 읽습니다.
class _BarRow extends StatelessWidget {
  const new({
    required this.index,
    required this.name,
    required this.days,
    required this.fraction,
    required this.fill,
  });

  final int index;
  final String name;
  final int days;
  final double fraction;
  final Color fill;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    const radius = BorderRadius.all(Radius.circular(Radii.full));
    return MergeSemantics(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: DiarySummary.rowMinHeight),
        child: Row(
          children: [
            SizedBox(
              width: DiarySummary.nameWidth,
              child: Text(
                name,
                style: tokens.typography.labelMd.copyWith(
                  color: tokens.colors.textPrimary,
                ),
              ),
            ),
            Expanded(
              child: ExcludeSemantics(
                child: DecoratedBox(
                  key: DiarySummary.trackKey(index),
                  decoration: BoxDecoration(
                    color: tokens.colors.bgBase,
                    borderRadius: radius,
                  ),
                  child: SizedBox(
                    height: DiarySummary.barHeight,
                    width: double.infinity,
                    child: fraction <= 0
                        ? null
                        : FractionallySizedBox(
                            alignment: AlignmentDirectional.centerStart,
                            widthFactor: fraction,
                            child: DecoratedBox(
                              key: DiarySummary.fillKey(index),
                              decoration: BoxDecoration(
                                color: fill,
                                borderRadius: radius,
                              ),
                            ),
                          ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: Space.s12),
            SizedBox(
              width: DiarySummary.countWidth,
              child: Text(
                '$days',
                textAlign: TextAlign.end,
                style: tokens.typography.numericTable.copyWith(
                  color: tokens.colors.textPrimary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 불러오는 중: 머리 글자는 바로 보이고, 편수 글줄 하나(96), 막대 글줄 넷, 태그 칩 셋(64).
class _DiarySummarySkeleton extends StatelessWidget {
  const new({required this.animated});

  /// false면 정지 상태로 그립니다(golden).
  final bool animated;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = context.tokens;
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: DiarySummary.textScaleMax,
      child: _Card(
        child: ExcludeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 96,
                child: SkeletonTextLines(
                  style: tokens.typography.bodyUi.copyWith(
                    fontSize: DiarySummary.countFontSize,
                  ),
                  widthFactor: 1,
                  animated: animated,
                ),
              ),
              _Head(l10n.mySajuRecordDayKindHead),
              SkeletonTextLines(
                lines: 4,
                style: tokens.typography.labelMd,
                widthFactor: 1,
                animated: animated,
              ),
              _Head(l10n.mySajuRecordTagHead),
              Wrap(
                spacing: Space.s8,
                children: [
                  for (var i = 0; i < 3; i++)
                    SkeletonChip(
                      width: HanjaTag.skeletonWidth,
                      height: HanjaTag.height,
                      index: i,
                      animated: animated,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
