import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart'
    show CustomSemanticsAction, SemanticsRole;
import 'package:intl/intl.dart';
import 'package:myungli_diary/core/api/gen/model/rendered_text.dart';
import 'package:myungli_diary/core/api/gen/model/segment.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/component_spec.dart';
import 'package:myungli_diary/design/components/feedback/skeleton.dart';
import 'package:myungli_diary/design/components/frame/scroll_hint.dart';
import 'package:myungli_diary/design/components/sentence/hanja_tag.dart';
import 'package:myungli_diary/design/components/sentence/press_ink_target.dart';
import 'package:myungli_diary/design/components/sentence/sentence_block.dart';
import 'package:myungli_diary/design/elements/app_icon.dart';
import 'package:myungli_diary/design/elements/seal.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';
import 'package:phosphor_glyphs/phosphor_glyphs.dart';

const AppGlyph _caretRight = AppGlyph(
  light: PhosphorIconsLight.caretRight,
  regular: PhosphorIconsRegular.caretRight,
);

/// 날짜 칸의 스크린리더 라벨("10월 12일 월요일"). [DiaryRow]와 [DiaryDayGroup]이 함께 씁니다.
String _dateLabel(BuildContext context, CalendarDate date) {
  final locale = Localizations.localeOf(context).toLanguageTag();
  return DateFormat.MMMMEEEEd(locale)
      .format(DateTime(date.year, date.month, date.day));
}

/// 일기 목록 한 줄(`diary-row` `day`): 흐름 줄 위 날짜 + 카드.
///
/// 그날 일기가 한 편일 때의 모양입니다. 두 편 이상이면 [DiaryDayGroup], 오늘·그날 시트는
/// [DiaryEntries]를 씁니다.
///
/// 왼쪽 날짜 열(44)에 숫자(옅은 도장 34 가운데)와 요일을 두고, 요일 아래에서 줄 끝까지
/// `rail.timeline`이 이어져 다음 줄 날짜와 만납니다([isLast]면 없음). 오른쪽 카드에는
/// 날의 성격 `hanja-tag`([dayKind], 없으면 그리지 않음) → 미리보기 두 줄 → 그날 사주 기운
/// 태그 줄([tags], 한 줄 가로 밀기, [DiaryRowTags])을 둡니다(V81, V103).
///
/// 카드 전체가 버튼([onTap])이고 스크린리더는 "날짜 요일, 날의 성격, 미리보기, 사주 기운
/// 태그들" 한 덩어리로 읽습니다. 카드 안 태그는 손가락으로는 따로 눌리고(뜻 시트), 스크린리더
/// 에서는 카드의 추가 동작(태그 이름)으로 닿습니다.
class DiaryRow extends StatelessWidget {
  /// 한 줄을 만듭니다. [excerpt]는 본문 앞부분(`DiarySummary.excerpt`)입니다.
  const new({
    required this.date,
    required this.excerpt,
    required this.onTap,
    this.dayKind,
    this.dayKindPending = false,
    this.tags = const [],
    this.isLast = false,
    this.identifier,
    super.key,
  });

  /// 명세 대조용 요약.
  static const ComponentSpec spec = ComponentSpec(
    'diary-row',
    {'day', 'entries'},
    {'pressed', 'loading'},
  );

  /// 날짜 열을 찾는 테스트용 키.
  static const Key dateColumnKey = ValueKey('diary-row-date');

  /// 흐름 줄을 찾는 테스트용 키.
  static const Key railKey = ValueKey('diary-row-rail');

  /// 카드 바탕을 찾는 테스트용 키.
  static const Key cardKey = ValueKey('diary-row-card');

  /// 날짜 열 너비(`parts.dateColumn.width`).
  static const double dateColumnWidth = 44;

  /// 날짜 열 글자 배율 상한. 폭이 고정된 열이라 칸 고정 표와 같은 1.3배입니다.
  static const double textScaleMax = 1.3;

  /// 묶음 카드에서 날의 성격 아래 entry 줄들까지의 간격(`day.parts.group.entriesMarginTop`).
  static const double entriesMarginTop = Space.s4;

  /// 묶음 카드에서 날의 성격 태그 아래 간격(`day.parts.group.dayKind.marginBottom`).
  static const double groupDayKindMarginBottom = Space.s4;

  /// 한 편 카드에서 날의 성격 태그와 미리보기 사이(`parts.preview.marginTop`, 날의 성격이 있을
  /// 때만).
  static const double previewMarginTop = Space.s8;

  /// 묶음 카드에서 마지막 줄 아래 태그 칩까지의 간격(`day.parts.group.tag.marginTop`).
  static const double groupTagMarginTop = Space.s8;

  /// 한 편 카드에서 미리보기와 태그 줄 사이(`parts.tag.marginTop`, `space.12`).
  /// 두 편 이상 묶음 카드는 [groupTagMarginTop]으로 덮어씁니다.
  static const double tagMarginTop = Space.s12;

  /// 태그 줄의 태그 사이(`parts.tag.gap`, `space.8`).
  static const double tagsGap = Space.s8;

  /// 태그 줄(가로로 미는 줄)을 찾는 테스트용 키.
  static const Key tagsKey = ValueKey('diary-row-tags');

  static const double _numberSize = 18;
  static const double _weekdayGap = 4;
  static const double _railWidth = 1.5;

  /// 일기 날짜.
  final CalendarDate date;

  /// 미리보기 글(본문 앞부분).
  final String excerpt;

  /// 그날 날의 성격 `hanja-tag`(길흉 톤). null이면 그리지 않습니다.
  final HanjaTag? dayKind;

  /// 그날 성격을 아직 받는 중이면 true. 태그 자리를 skeleton으로 잡아 둡니다(A46).
  final bool dayKindPending;

  /// 그날 사주 기운 태그들(`hanja-tag` `default`, 대표 태그 순위 순, D115). 비면 줄을 그리지
  /// 않습니다(`tag-diary` 안에서는 모아 본 태그만 빠짐).
  final List<HanjaTag> tags;

  /// 목록 마지막 줄이면 흐름 줄을 긋지 않습니다.
  final bool isLast;

  /// 카드를 눌렀을 때(일기 보기).
  final VoidCallback onTap;

  /// IA 슬롯 id. 있으면 Semantics `identifier`로 붙입니다.
  final String? identifier;

  String _semanticLabel(BuildContext context, AppLocalizations l10n) {
    return [
      _dateLabel(context, date),
      ?dayKind?.label,
      excerpt,
      for (final tag in tags) tag.label,
    ].join(l10n.a11yListSeparator);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final dayKind = this.dayKind;
    return _DayFrame(
      date: date,
      isLast: isLast,
      child: PressInkTarget(
        semanticLabel: _semanticLabel(context, l10n),
        identifier: identifier,
        onTap: onTap,
        inkColor: context.tokens.colors.textPrimary,
        borderRadius: const BorderRadius.all(Radius.circular(Radii.lg)),
        customActions: {
          for (final pill in [?dayKind, ...tags])
            CustomSemanticsAction(label: pill.label): ?pill.onTap,
        },
        child: _DiaryCard(
          children: [
            ..._dayKindSlot(
              dayKind: dayKind,
              pending: dayKindPending,
              gap: DiaryRow.previewMarginTop,
            ),
            SentenceBlock(
              variant: SentenceBlockVariant.preview,
              text: RenderedText(segments: [Segment(text: excerpt)]),
            ),
            if (tags.isNotEmpty) ...[
              const SizedBox(height: tagMarginTop),
              DiaryRowTags(tags: tags),
            ],
          ],
        ),
      ),
    );
  }
}

/// 같은 날 일기가 두 편 이상인 날의 묶음 카드(`diary-row` `day` 묶음).
///
/// 날짜 열·흐름 줄·카드 바탕은 [DiaryRow]와 같고, 카드 안은 날의 성격 `hanja-tag`(한 번,
/// 아래 `space.4`) → [entries] 줄들 → 사주 기운 태그 줄(한 번, 마지막 줄 아래 `space.8`)
/// 입니다.
/// 카드 전체는 버튼이 아닙니다. 스크린리더는 "날짜 요일, 날의 성격" 그룹으로 읽고, 누를 곳은
/// 줄마다([DiaryEntryData.onTap])와 두 태그입니다. 흐름 줄은 카드 높이만큼 이어집니다.
///
/// [entries]는 server 순서(작성 순) 그대로이고 다시 정렬하지 않습니다. 몇 편이든 모두 그립니다.
class DiaryDayGroup extends StatelessWidget {
  /// 묶음 카드를 만듭니다. [entries]는 두 편 이상이어야 합니다(한 편이면 [DiaryRow]).
  // 편수 검사(`entries.length`)는 const 식이 아니라 const 생성자로 둘 수 없습니다.
  // ignore: prefer_const_constructors_in_immutables
  new({
    required this.date,
    required this.entries,
    this.dayKind,
    this.dayKindPending = false,
    this.tags = const [],
    this.isLast = false,
    super.key,
  }) : assert(entries.length >= 2, '한 편인 날은 DiaryRow를 씁니다.');

  /// 일기 날짜.
  final CalendarDate date;

  /// 그날 일기 줄들(작성 순, 두 개 이상).
  final List<DiaryEntryData> entries;

  /// 그날 날의 성격 `hanja-tag`(길흉 톤). null이면 그리지 않습니다.
  final HanjaTag? dayKind;

  /// 그날 성격을 아직 받는 중이면 true(태그 자리 skeleton).
  final bool dayKindPending;

  /// 그날 사주 기운 태그들([DiaryRow.tags]와 같음). 비면 줄을 그리지 않습니다.
  final List<HanjaTag> tags;

  /// 목록 마지막 줄이면 흐름 줄을 긋지 않습니다.
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // 날의 성격 태그를 누를 수 있으면 자식 버튼 노드가 이름을 따로 읽으므로 그룹 라벨에서는
    // 뺍니다(같은 낱말을 두 번 읽지 않게). 누를 수 없으면 제외된 자식 대신 그룹이 읽습니다.
    final label = [
      _dateLabel(context, date),
      if (dayKind?.onTap == null) ?dayKind?.label,
    ].join(l10n.a11yListSeparator);
    return _DayFrame(
      date: date,
      isLast: isLast,
      // 명세 a11y `group`: 카드의 버튼 역할을 그룹으로 바꿉니다(Flutter에 group 역할이
      // 없어 라벨 있는 container).
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        label: label,
        child: _DiaryCard(
          children: [
            ..._dayKindSlot(
              dayKind: dayKind,
              pending: dayKindPending,
              gap: DiaryRow.groupDayKindMarginBottom,
              excludeInertSemantics: true,
            ),
            _EntryLines(entries: entries),
            if (tags.isNotEmpty) ...[
              const SizedBox(height: DiaryRow.groupTagMarginTop),
              DiaryRowTags(tags: tags),
            ],
          ],
        ),
      ),
    );
  }
}

/// 날짜 열(+ 흐름 줄)과 오른쪽 카드 자리. 카드는 날짜 열과 같은 높이로 늘어나 흐름 줄이
/// 카드 높이만큼 이어집니다.
class _DayFrame extends StatelessWidget {
  const new({required this.date, required this.isLast, required this.child});

  final CalendarDate date;
  final bool isLast;
  final Widget child;

  DateTime get _day => DateTime(date.year, date.month, date.day);

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _dateColumn(context),
          const SizedBox(width: Space.s12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: Space.s12),
              child: child,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateColumn(BuildContext context) {
    final tokens = context.tokens;
    final locale = Localizations.localeOf(context).toLanguageTag();
    // 날짜는 카드 라벨("날짜 요일, ...", 한 편·묶음 모두)이 읽으므로 숫자·요일은 따로 읽지 않습니다.
    return ExcludeSemantics(
      child: _DateColumn(
        isLast: isLast,
        number: Text(
          '${date.day}',
          maxLines: 1,
          softWrap: false,
          style: tokens.typography.bodyUi.copyWith(
            fontSize: DiaryRow._numberSize,
            fontWeight: FontWeight.w600,
            height: 1,
            color: tokens.colors.textPrimary,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        weekday: Text(
          DateFormat.E(locale).format(_day),
          style: tokens.typography.captionMd.copyWith(
            color: tokens.colors.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// 일기 줄 카드 아래 사주 기운 태그 줄(`diary-row.parts.tag`, D115, V103).
///
/// [tags]를 받은 순서(대표 태그 순위)대로 `space.8` 간격 한 줄에 둡니다. 줄을 늘리지 않고
/// 넘치면 그 줄 안에서 가로로 밀며, 더 있는 쪽 끝 24만 카드 바탕(`bg.sheet`)으로 흐립니다
/// (`scroll-hint`의 흐림만, 화살표 줄 없음). 스크린리더는 가로 밀기와 상관없이 태그를 목록으로
/// 차례로 읽습니다(한 편 카드에서는 카드 라벨이 이름을 읽고 태그는 카드의 추가 동작).
class DiaryRowTags extends StatefulWidget {
  /// 태그 줄을 만듭니다. [tags]가 비면 아무것도 그리지 않습니다.
  const new({required this.tags, super.key});

  /// 그날 사주 기운 태그들(순서 그대로).
  final List<HanjaTag> tags;

  @override
  State<DiaryRowTags> createState() => _DiaryRowTagsState();
}

class _DiaryRowTagsState extends State<DiaryRowTags> {
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tags = widget.tags;
    if (tags.isEmpty) return const SizedBox.shrink();
    return ScrollHint(
      controller: _scroll,
      showArrows: false,
      child: SingleChildScrollView(
        key: DiaryRow.tagsKey,
        controller: _scroll,
        scrollDirection: Axis.horizontal,
        child: Semantics(
          container: true,
          explicitChildNodes: true,
          role: SemanticsRole.list,
          child: Row(
            spacing: DiaryRow.tagsGap,
            children: [
              for (final tag in tags)
                Semantics(
                  container: true,
                  role: SemanticsRole.listItem,
                  child: tag,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 카드 바탕(`bg.sheet`, `radius.lg`, 안쪽 `space.16`) 안에 [children]을 세로로 놓습니다.
class _DiaryCard extends StatelessWidget {
  const new({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: DiaryRow.cardKey,
      decoration: BoxDecoration(
        color: context.tokens.colors.bgSheet,
        borderRadius: BorderRadius.circular(Radii.lg),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Space.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }
}

/// 카드 맨 위 날의 성격 자리. 태그가 있으면 태그와 [gap]을, 기다리는 중이면 같은 크기의
/// skeleton과 [gap]을, 둘 다 아니면 아무것도 그리지 않습니다(없을 때는 간격도 없음).
List<Widget> _dayKindSlot({
  required HanjaTag? dayKind,
  required bool pending,
  required double gap,
  bool excludeInertSemantics = false,
}) {
  if (dayKind != null) {
    return [
      Align(
        alignment: AlignmentDirectional.centerStart,
        // 누를 수 없는 태그의 이름은 묶음 그룹 라벨이 이미 읽습니다(두 번 읽지 않게).
        child: excludeInertSemantics && dayKind.onTap == null
            ? ExcludeSemantics(child: dayKind)
            : dayKind,
      ),
      SizedBox(height: gap),
    ];
  }
  if (pending) {
    return [
      const Align(
        alignment: AlignmentDirectional.centerStart,
        child: SkeletonChip(
          width: DiaryRowSkeleton.dayKindBoneWidth,
          height: HanjaTag.height,
        ),
      ),
      SizedBox(height: gap),
    ];
  }
  return const [];
}

/// 일기 목록의 달 머리(`diary-row` 규칙: 달이 바뀌는 자리에 `type.subtitle`).
class DiaryMonthHeader extends StatelessWidget {
  /// [label](예: "2026년 10월") 머리를 만듭니다.
  const new({required this.label, super.key});

  /// 달 이름.
  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Semantics(
      header: true,
      child: Text(
        label,
        style: tokens.typography.subtitle.copyWith(
          color: tokens.colors.textPrimary,
        ),
      ),
    );
  }
}

/// 날짜 열: [number]는 옅은 도장 가운데, 아래 [weekday], 그 아래 흐름 줄([isLast]면 없음).
class _DateColumn extends StatelessWidget {
  const new({
    required this.number,
    required this.weekday,
    required this.isLast,
  });

  final Widget number;
  final Widget weekday;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    // 폭이 고정된 열이라 글자는 1.3배에서 멈춥니다(칸 고정 표와 같은 규칙, `a11y.textScaleMax`).
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: DiaryRow.textScaleMax,
      child: _column(context),
    );
  }

  Widget _column(BuildContext context) {
    return SizedBox(
      key: DiaryRow.dateColumnKey,
      width: DiaryRow.dateColumnWidth,
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              const Seal(size: SealSize.row, variant: SealVariant.soft),
              number,
            ],
          ),
          const SizedBox(height: DiaryRow._weekdayGap),
          weekday,
          if (!isLast)
            Expanded(
              child: Center(
                child: ColoredBox(
                  key: DiaryRow.railKey,
                  color: context.tokens.colors.timelineLine,
                  child: const SizedBox(
                    width: DiaryRow._railWidth,
                    height: double.infinity,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 일기 목록을 받는 동안의 한 줄(`diary-row` `day` `loading`): 날짜 열은 도장 자리와 요일
/// 글줄 뼈, 카드는 날의 성격 칩(88), 미리보기 글줄 두 줄, 태그 칩(72) 뼈입니다.
/// 스크린리더는 읽지 않습니다.
class DiaryRowSkeleton extends StatelessWidget {
  /// skeleton 줄을 만듭니다. [index]는 숨쉬기 순서입니다.
  const new({this.index = 0, super.key});

  /// 숨쉬기 순서(여러 줄이 차례로 숨쉼).
  final int index;

  /// 뼈 `dayKind` 너비(`states.loading.skeleton` `dayKind.width` 88px).
  static const double dayKindBoneWidth = 88;

  /// 뼈 `tag` 너비(`states.loading.skeleton` `tag.width` 72px).
  static const double tagBoneWidth = 72;

  /// 요일 글줄 뼈 폭. 요일 한두 글자 폭입니다.
  static const double _weekdayBoneWidth = 16;

  @override
  Widget build(BuildContext context) {
    final typography = context.tokens.typography;
    return ExcludeSemantics(
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DateColumn(
              isLast: false,
              number: const SizedBox.shrink(),
              weekday: SizedBox(
                width: _weekdayBoneWidth,
                child: SkeletonTextLines(
                  style: typography.captionMd,
                  widthFactor: 1,
                  index: index,
                ),
              ),
            ),
            const SizedBox(width: Space.s12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: Space.s12),
                child: SkeletonCard(
                  padding: const EdgeInsets.all(Space.s16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: SkeletonChip(
                          width: dayKindBoneWidth,
                          height: HanjaTag.height,
                          index: index,
                        ),
                      ),
                      const SizedBox(height: Space.s8),
                      SentenceBlock.skeleton(
                        variant: SentenceBlockVariant.preview,
                        index: index + 1,
                      ),
                      const SizedBox(height: DiaryRow.tagMarginTop),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: SkeletonChip(
                          width: tagBoneWidth,
                          height: HanjaTag.height,
                          index: index + 3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// [DiaryEntryLine] 하나를 만드는 값(작성 시각, 본문 앞부분, 누르면 그 일기).
class DiaryEntryData {
  /// 줄 값을 만듭니다. [createdAt]은 고친 시각이 아니라 작성 시각입니다.
  const new({
    required this.createdAt,
    required this.excerpt,
    required this.onTap,
  });

  /// 작성 시각(`DiarySummary.createdAt`).
  final DateTime createdAt;

  /// 본문 앞부분(`DiarySummary.excerpt`).
  final String excerpt;

  /// 줄을 눌렀을 때(그 일기 보기).
  final VoidCallback onTap;
}

/// 같은 날 일기 한 편의 줄(`diary-row` `entry`): 시각 + 한 줄 미리보기 + 꺾쇠.
///
/// 묶음 카드([DiaryDayGroup])와 [DiaryEntries]가 같은 모양으로 씁니다. 줄 전체가 버튼이고
/// 눌림(`press.ink`)은 이 줄 안에서만 번집니다. 스크린리더는 "시각, 미리보기 첫 줄"을 읽고
/// 본문이 비면 시각만 읽습니다. [showDivider]면 줄 위에 1px 점선을 긋습니다(첫 줄은 false,
/// 줄과 줄 사이에만 있음).
class DiaryEntryLine extends StatelessWidget {
  /// 줄을 만듭니다. 시각은 [createdAt]을 기기 시간대로 바꿔 24시간제 `HH:mm`으로
  /// 그립니다(locale과 상관없음).
  const new({
    required this.createdAt,
    required this.excerpt,
    required this.onTap,
    this.showDivider = false,
    this.identifier,
    super.key,
  });

  /// 줄 위 점선을 찾는 테스트용 키(그려질 때만 있음).
  static const Key dividerKey = ValueKey('diary-entry-divider');

  /// 꺾쇠를 찾는 테스트용 키.
  static const Key chevronKey = ValueKey('diary-entry-chevron');

  /// 줄 최소 높이(`entry.minHeight`).
  static const double minHeight = 48;

  /// 줄 위아래 안쪽 여백(`entry.paddingY`).
  static const double paddingY = Space.s12;

  /// 시각과 미리보기 사이 간격(`entry.preview.marginStart`).
  static const double timeGap = Space.s12;

  /// 미리보기 줄 수(`entry.preview.maxLines`).
  static const int previewMaxLines = 1;

  /// 꺾쇠 크기(`entry.chevron.size`).
  static const double chevronSize = 16;

  /// 점선 두께(`entry.divider.width`).
  static const double dividerWidth = 1;

  /// 점선 대시 길이(`entry.divider.dashLength`).
  static const double dividerDashLength = 4;

  /// 점선 대시 사이 간격(`entry.divider.dashGap`).
  static const double dividerDashGap = 3;

  /// 미리보기와 꺾쇠 사이(`entry.chevron.marginStart`, `space.8`).
  static const double chevronGap = Space.s8;

  /// 작성 시각.
  final DateTime createdAt;

  /// 미리보기 글(본문 앞부분).
  final String excerpt;

  /// 줄을 눌렀을 때(일기 보기).
  final VoidCallback onTap;

  /// 줄 위에 점선을 그을지(줄과 줄 사이에만).
  final bool showDivider;

  /// IA 슬롯 id. 있으면 Semantics `identifier`로 붙입니다.
  final String? identifier;

  /// 스크린리더가 읽을 첫 줄. 본문이 비면 빈 문자열입니다.
  String get _firstLine {
    for (final line in excerpt.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isNotEmpty) return trimmed;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = context.tokens;
    final colors = tokens.colors;
    final time = DateFormat('HH:mm').format(createdAt.toLocal());
    final firstLine = _firstLine;
    final label = [
      time,
      if (firstLine.isNotEmpty) firstLine,
    ].join(l10n.a11yListSeparator);
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: paddingY),
      child: Row(
        children: [
          Expanded(
            // 시각과 미리보기 첫 줄의 기준선을 맞춥니다.
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  time,
                  maxLines: 1,
                  softWrap: false,
                  style: tokens.typography.captionMd.copyWith(
                    color: colors.textSecondary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: timeGap),
                Expanded(
                  child: SentenceBlock(
                    variant: SentenceBlockVariant.preview,
                    // 본문이 비어도 한 줄 높이를 지키도록 공백 하나를 둡니다.
                    text: RenderedText(
                      segments: [
                        Segment(text: firstLine.isEmpty ? ' ' : firstLine),
                      ],
                    ),
                    maxLines: previewMaxLines,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: chevronGap),
          AppIcon(
            _caretRight,
            key: chevronKey,
            size: AppIconSize.s16,
            color: colors.textSecondary,
          ),
        ],
      ),
    );
    return PressInkTarget(
      semanticLabel: label,
      identifier: identifier,
      onTap: onTap,
      inkColor: colors.textPrimary,
      borderRadius: BorderRadius.zero,
      child: CustomPaint(
        key: showDivider ? dividerKey : null,
        painter: showDivider
            ? _DashedDividerPainter(colors.timelineEntry)
            : null,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: minHeight),
          child: content,
        ),
      ),
    );
  }
}

/// 줄 맨 위 1px 안에 그리는 점선(`entry.divider`). 줄 전체 너비입니다.
class _DashedDividerPainter extends CustomPainter {
  const new(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = DiaryEntryLine.dividerWidth
      ..style = PaintingStyle.stroke;
    const y = DiaryEntryLine.dividerWidth / 2;
    const step =
        DiaryEntryLine.dividerDashLength + DiaryEntryLine.dividerDashGap;
    for (var x = 0.0; x < size.width; x += step) {
      final end = x + DiaryEntryLine.dividerDashLength;
      canvas.drawLine(
        Offset(x, y),
        Offset(end < size.width ? end : size.width, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashedDividerPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// [entries]를 위에서 아래로 놓고 줄과 줄 사이에만 점선을 긋습니다.
class _EntryLines extends StatelessWidget {
  const new({required this.entries});

  final List<DiaryEntryData> entries;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, entry) in entries.indexed)
          DiaryEntryLine(
            createdAt: entry.createdAt,
            excerpt: entry.excerpt,
            onTap: entry.onTap,
            showDivider: index > 0,
          ),
      ],
    );
  }
}

/// [DiaryEntries]가 놓이는 화면의 바탕(`entries.parts.container.byScreen`).
enum DiaryEntriesSurface {
  /// 오늘: 가이드 질문 카드 아래 카드 한 장(`bg.sheet`, `radius.lg`) 안.
  card,

  /// 그날 시트: 시트 바탕 위에 바로. 머리는 그리지 않습니다(섹션 제목은 `section-header`가 맡음).
  plain,
}

/// 오늘·그날 시트의 같은 날 일기 줄들(`diary-row` `entries`).
///
/// 날짜 열·배지·태그 없이 [DiaryEntryLine]만 작성 순으로 놓습니다(날짜와 날의 성격은 화면이
/// 이미 보여 줌). [entries]가 비면 바탕까지 그리지 않습니다. 머리는 그리지 않습니다(V85).
class DiaryEntries extends StatelessWidget {
  /// 줄들을 만듭니다.
  const new({required this.entries, required this.surface, super.key});

  /// 오늘 바탕 카드를 찾는 테스트용 키.
  static const Key cardKey = ValueKey('diary-entries-card');

  /// 오늘 바탕 좌우 안쪽 여백(`container.byScreen.today.paddingX`).
  static const double cardPaddingX = Space.s16;

  /// 오늘 바탕 위아래 안쪽 여백(`container.byScreen.today.paddingY`).
  static const double cardPaddingY = Space.s4;

  /// 오늘 바탕 위 간격(`container.byScreen.today.marginTop`).
  static const double cardMarginTop = Space.s12;

  /// 그날 일기 줄들(작성 순).
  final List<DiaryEntryData> entries;

  /// 놓이는 화면의 바탕.
  final DiaryEntriesSurface surface;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();
    final lines = _EntryLines(entries: entries);
    return switch (surface) {
      DiaryEntriesSurface.card => Padding(
        padding: const EdgeInsets.only(top: cardMarginTop),
        child: _cardSurface(context, lines),
      ),
      DiaryEntriesSurface.plain => lines,
    };
  }
}

Widget _cardSurface(BuildContext context, Widget child) {
  return DecoratedBox(
    key: DiaryEntries.cardKey,
    decoration: BoxDecoration(
      color: context.tokens.colors.bgSheet,
      borderRadius: BorderRadius.circular(Radii.lg),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DiaryEntries.cardPaddingX,
        vertical: DiaryEntries.cardPaddingY,
      ),
      child: child,
    ),
  );
}

/// [DiaryEntries]를 받는 동안(`diary-row` `entries` `loading`): 줄 두 개 높이의 뼈.
/// 스크린리더는 읽지 않습니다.
class DiaryEntriesSkeleton extends StatelessWidget {
  /// skeleton을 만듭니다. [surface]는 [DiaryEntries]와 같은 바탕입니다.
  const new({this.surface = DiaryEntriesSurface.card, super.key});

  /// 놓이는 화면의 바탕.
  final DiaryEntriesSurface surface;

  static const double _timeBoneWidth = 48;
  static const int _lineCount = 2;

  @override
  Widget build(BuildContext context) {
    final typography = context.tokens.typography;
    final lines = Column(
      children: [
        for (var i = 0; i < _lineCount; i++)
          ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: DiaryEntryLine.minHeight,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: DiaryEntryLine.paddingY,
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: _timeBoneWidth,
                    child: SkeletonTextLines(
                      style: typography.captionMd,
                      widthFactor: 1,
                      index: i,
                    ),
                  ),
                  const SizedBox(width: DiaryEntryLine.timeGap),
                  Expanded(
                    child: SkeletonTextLines(
                      style: typography.sentenceBody,
                      widthFactor: 1,
                      index: i + 1,
                    ),
                  ),
                  const SizedBox(width: DiaryEntryLine.chevronGap),
                  const SizedBox.square(dimension: DiaryEntryLine.chevronSize),
                ],
              ),
            ),
          ),
      ],
    );
    return ExcludeSemantics(
      child: switch (surface) {
        DiaryEntriesSurface.card => Padding(
          padding: const EdgeInsets.only(top: DiaryEntries.cardMarginTop),
          child: _cardSurface(context, lines),
        ),
        DiaryEntriesSurface.plain => lines,
      },
    );
  }
}
