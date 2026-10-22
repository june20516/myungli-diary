import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:intl/intl.dart';
import 'package:myungli_diary/core/api/gen/model/rendered_text.dart';
import 'package:myungli_diary/core/api/gen/model/segment.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/component_spec.dart';
import 'package:myungli_diary/design/components/diary/tag_chip.dart';
import 'package:myungli_diary/design/components/sentence/press_ink_target.dart';
import 'package:myungli_diary/design/components/sentence/sentence_block.dart';
import 'package:myungli_diary/design/components/today/day_character.dart';
import 'package:myungli_diary/design/components/today/day_reading_skeleton.dart';
import 'package:myungli_diary/design/elements/app_icon.dart';
import 'package:myungli_diary/design/elements/seal.dart';
import 'package:myungli_diary/design/elements/skeleton_bone.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';
import 'package:phosphor_glyphs/phosphor_glyphs.dart';

const AppGlyph _caretRight = AppGlyph(
  light: PhosphorIconsLight.caretRight,
  regular: PhosphorIconsRegular.caretRight,
);

/// 일기 목록 한 줄(`diary-row` `day`): 흐름 줄 위 날짜 + 카드.
///
/// 그날 일기가 한 편일 때의 모양입니다. 두 편 이상이면 [DiaryDayGroup], 오늘·그날 시트는
/// [DiaryEntries]를 씁니다.
///
/// 왼쪽 날짜 열(44)에 숫자(옅은 도장 34 가운데)와 요일을 두고, 요일 아래에서 줄 끝까지
/// `rail.timeline`이 이어져 다음 줄 날짜와 만납니다([isLast]면 없음). 오른쪽 카드에는
/// 날의 성격 배지([character], 없으면 그리지 않음) → 미리보기 두 줄 → 대표 태그 칩 하나
/// ([tag])를 둡니다.
///
/// 카드 전체가 버튼([onTap])이고 스크린리더는 "날짜 요일, 배지, 미리보기, 태그" 한 덩어리로
/// 읽습니다. 카드 안 태그 칩은 손가락으로는 따로 눌리고(태그 모아보기), 스크린리더에서는
/// 카드의 추가 동작(태그 이름)으로 닿습니다.
class DiaryRow extends StatelessWidget {
  /// 한 줄을 만듭니다. [excerpt]는 본문 앞부분(`DiarySummary.excerpt`)입니다.
  const new({
    required this.date,
    required this.excerpt,
    required this.onTap,
    this.character,
    this.characterLabel,
    this.characterPending = false,
    this.tag,
    this.isLast = false,
    this.identifier,
    super.key,
  }) : assert(
         (character == null) == (characterLabel == null),
         '배지는 변형과 이름을 함께 줍니다.',
       );

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

  /// 묶음 카드에서 배지 아래 entry 줄들까지의 간격(`day.parts.group.entriesMarginTop`).
  static const double entriesMarginTop = Space.s4;

  /// 묶음 카드에서 마지막 줄 아래 태그 칩까지의 간격(`day.parts.group.tag.marginTop`).
  static const double groupTagMarginTop = Space.s8;

  static const double _numberSize = 18;
  static const double _weekdayGap = 4;
  static const double _railWidth = 1.5;

  /// 일기 날짜.
  final CalendarDate date;

  /// 미리보기 글(본문 앞부분).
  final String excerpt;

  /// 그날 성격 배지 변형. null이면 배지를 그리지 않습니다.
  final DayCharacterVariant? character;

  /// 그날 성격 이름(배지 글자).
  final String? characterLabel;

  /// 그날 성격을 아직 받는 중이면 true. 배지 자리를 skeleton으로 잡아 둡니다(A46).
  final bool characterPending;

  /// 대표 태그 칩. null이면 그리지 않습니다.
  final TagChip? tag;

  /// 목록 마지막 줄이면 흐름 줄을 긋지 않습니다.
  final bool isLast;

  /// 카드를 눌렀을 때(일기 보기).
  final VoidCallback onTap;

  /// IA 슬롯 id. 있으면 Semantics `identifier`로 붙입니다.
  final String? identifier;

  DateTime get _day => DateTime(date.year, date.month, date.day);

  String _semanticLabel(BuildContext context, AppLocalizations l10n) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final tag = this.tag;
    return [
      DateFormat.MMMMEEEEd(locale).format(_day),
      ?characterLabel,
      excerpt,
      if (tag != null) l10n.tagChipLabel(tag.name),
    ].join(l10n.a11yListSeparator);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tag = this.tag;
    final tagTap = tag?.onTap;
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
          if (tag != null && tagTap != null)
            CustomSemanticsAction(label: l10n.tagChipLabel(tag.name)): tagTap,
        },
        child: _DiaryCard(
          children: [
            ..._badgeSlot(
              character: character,
              characterLabel: characterLabel,
              characterPending: characterPending,
              gap: Space.s8,
            ),
            SentenceBlock(
              variant: SentenceBlockVariant.preview,
              text: RenderedText(segments: [Segment(text: excerpt)]),
            ),
            if (tag != null) ...[const SizedBox(height: Space.s12), tag],
          ],
        ),
      ),
    );
  }
}

/// 같은 날 일기가 두 편 이상인 날의 묶음 카드(`diary-row` `day` 묶음).
///
/// 날짜 열·흐름 줄·카드 바탕은 [DiaryRow]와 같고, 카드 안은 배지(한 번) → [entries] 줄들
/// (배지 아래 `space.4`) → 대표 태그 칩(한 번, 마지막 줄 아래 `space.8`)입니다. 카드 전체는
/// 버튼이 아닙니다. 스크린리더는 "날짜 요일, 배지" 그룹으로 읽고, 누를 곳은 줄마다
/// ([DiaryEntryData.onTap])와 태그 칩입니다. 흐름 줄은 카드 높이만큼 이어집니다.
///
/// [entries]는 server 순서(작성 순) 그대로이고 다시 정렬하지 않습니다. 몇 편이든 모두 그립니다.
class DiaryDayGroup extends StatelessWidget {
  /// 묶음 카드를 만듭니다. [entries]는 두 편 이상이어야 합니다(한 편이면 [DiaryRow]).
  // 편수 검사(`entries.length`)는 const 식이 아니라 const 생성자로 둘 수 없습니다.
  // ignore: prefer_const_constructors_in_immutables
  new({
    required this.date,
    required this.entries,
    this.character,
    this.characterLabel,
    this.characterPending = false,
    this.tag,
    this.isLast = false,
    super.key,
  }) : assert(entries.length >= 2, '한 편인 날은 DiaryRow를 씁니다.'),
       assert(
         (character == null) == (characterLabel == null),
         '배지는 변형과 이름을 함께 줍니다.',
       );

  /// 일기 날짜.
  final CalendarDate date;

  /// 그날 일기 줄들(작성 순, 두 개 이상).
  final List<DiaryEntryData> entries;

  /// 그날 성격 배지 변형. null이면 배지를 그리지 않습니다.
  final DayCharacterVariant? character;

  /// 그날 성격 이름(배지 글자).
  final String? characterLabel;

  /// 그날 성격을 아직 받는 중이면 true(배지 자리 skeleton).
  final bool characterPending;

  /// 대표 태그 칩. null이면 그리지 않습니다.
  final TagChip? tag;

  /// 목록 마지막 줄이면 흐름 줄을 긋지 않습니다.
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final tag = this.tag;
    final label = [
      DateFormat.MMMMEEEEd(locale)
          .format(DateTime(date.year, date.month, date.day)),
      ?characterLabel,
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
            ..._badgeSlot(
              character: character,
              characterLabel: characterLabel,
              characterPending: characterPending,
              gap: DiaryRow.entriesMarginTop,
            ),
            _EntryLines(entries: entries),
            if (tag != null) ...[
              const SizedBox(height: DiaryRow.groupTagMarginTop),
              tag,
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
    return _DateColumn(
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

/// 카드 맨 위 배지 자리. 배지가 있으면 [gap]을 두고 배지를, 기다리는 중이면 같은 크기의
/// skeleton을, 둘 다 아니면 아무것도 그리지 않습니다.
List<Widget> _badgeSlot({
  required DayCharacterVariant? character,
  required String? characterLabel,
  required bool characterPending,
  required double gap,
}) {
  if (character != null && characterLabel != null) {
    return [
      DayCharacterBadge(variant: character, label: characterLabel),
      SizedBox(height: gap),
    ];
  }
  if (characterPending) {
    return [
      const SkeletonBone(
        width: DayReadingSkeleton.badgeWidth,
        height: DayCharacterBadge.minHeight,
        borderRadius: Radii.full,
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

/// 일기 목록을 받는 동안의 한 줄(`diary-row` `loading`): 날짜 열은 도장 자리와 요일 뼈,
/// 카드는 배지·미리보기 두 줄 뼈입니다. 스크린리더는 읽지 않습니다.
class DiaryRowSkeleton extends StatelessWidget {
  /// skeleton 줄을 만듭니다. [index]는 숨쉬기 순서입니다.
  const new({this.index = 0, super.key});

  /// 숨쉬기 순서(여러 줄이 차례로 숨쉼).
  final int index;

  static const double _weekdayBoneWidth = 16;
  static const double _lineHeight = 12;
  static const double _lastLineFactor = 0.6;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DateColumn(
              isLast: false,
              number: const SizedBox.shrink(),
              weekday: SkeletonBone(
                width: _weekdayBoneWidth,
                height: _lineHeight,
                borderRadius: Radii.xs,
                index: index,
              ),
            ),
            const SizedBox(width: Space.s12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: Space.s12),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: context.tokens.colors.bgSheet,
                    borderRadius: BorderRadius.circular(Radii.lg),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(Space.s16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonBone(
                          width: DayReadingSkeleton.badgeWidth,
                          height: DayCharacterBadge.minHeight,
                          borderRadius: Radii.full,
                          index: index,
                        ),
                        const SizedBox(height: Space.s8),
                        SkeletonBone(
                          height: _lineHeight,
                          borderRadius: Radii.xs,
                          index: index + 1,
                        ),
                        const SizedBox(height: Space.s8),
                        FractionallySizedBox(
                          widthFactor: _lastLineFactor,
                          child: SkeletonBone(
                            height: _lineHeight,
                            borderRadius: Radii.xs,
                            index: index + 1,
                          ),
                        ),
                      ],
                    ),
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
  /// 줄을 만듭니다. 시각은 [createdAt]을 기기 시간대로 바꿔 locale의 짧은 시각 형식으로
  /// 그립니다(설정 화면과 같은 `DateFormat.jm`).
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

  /// 점선 대시 길이(`entry.divider.dash`).
  static const double dividerDash = 4;

  /// 점선 대시 사이 간격(`entry.divider.gap`).
  static const double dividerGap = 3;

  // 미리보기와 꺾쇠 사이(명세에 값이 없어 event-row 목록과 같은 space.8).
  static const double _chevronGap = Space.s8;

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
    final time = DateFormat.jm(l10n.localeName).format(createdAt.toLocal());
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
                        Segment(text: firstLine.isEmpty ? ' ' : excerpt),
                      ],
                    ),
                    maxLines: previewMaxLines,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: _chevronGap),
          AppIcon(
            _caretRight,
            key: chevronKey,
            size: AppIconSize.inline,
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
    const step = DiaryEntryLine.dividerDash + DiaryEntryLine.dividerGap;
    for (var x = 0.0; x < size.width; x += step) {
      final end = x + DiaryEntryLine.dividerDash;
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

  /// 그날 시트: 시트 바탕 위에 바로. 머리([DiaryEntries.head])가 위에 붙을 수 있습니다.
  plain,
}

/// 오늘·그날 시트의 같은 날 일기 줄들(`diary-row` `entries`).
///
/// 날짜 열·배지·태그 없이 [DiaryEntryLine]만 작성 순으로 놓습니다(날짜와 날의 성격은 화면이
/// 이미 보여 줌). [entries]가 비면 머리와 바탕 모두 그리지 않습니다.
class DiaryEntries extends StatelessWidget {
  /// 줄들을 만듭니다. [head]는 [DiaryEntriesSurface.plain]일 때만 위에 그립니다(링크 아님).
  const new({
    required this.entries,
    required this.surface,
    this.head,
    super.key,
  });

  /// 오늘 바탕 카드를 찾는 테스트용 키.
  static const Key cardKey = ValueKey('diary-entries-card');

  /// 오늘 바탕 좌우 안쪽 여백(`container.byScreen.today.paddingX`).
  static const double cardPaddingX = Space.s16;

  /// 오늘 바탕 위아래 안쪽 여백(`container.byScreen.today.paddingY`).
  static const double cardPaddingY = Space.s4;

  /// 오늘 바탕 위 간격(`container.byScreen.today.marginTop`).
  static const double cardMarginTop = Space.s12;

  /// 머리 위 간격(`head.marginTop`).
  static const double headMarginTop = Space.s16;

  /// 머리 아래 간격(`head.marginBottom`).
  static const double headMarginBottom = Space.s4;

  /// 그날 일기 줄들(작성 순).
  final List<DiaryEntryData> entries;

  /// 놓이는 화면의 바탕.
  final DiaryEntriesSurface surface;

  /// 그날 시트 머리 글자(`daySheetDiaryOpen(count)`).
  /// [DiaryEntriesSurface.plain]에서만 씁니다.
  final String? head;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();
    final lines = _EntryLines(entries: entries);
    switch (surface) {
      case DiaryEntriesSurface.card:
        return Padding(
          padding: const EdgeInsets.only(top: cardMarginTop),
          child: _cardSurface(context, lines),
        );
      case DiaryEntriesSurface.plain:
        final head = this.head;
        final tokens = context.tokens;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (head != null)
              Padding(
                padding: const EdgeInsets.only(
                  top: headMarginTop,
                  bottom: headMarginBottom,
                ),
                child: Text(
                  head,
                  style: tokens.typography.labelMd.copyWith(
                    color: tokens.colors.textSecondary,
                  ),
                ),
              ),
            lines,
          ],
        );
    }
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
  static const double _boneHeight = 12;
  static const int _lineCount = 2;

  @override
  Widget build(BuildContext context) {
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
                  SkeletonBone(
                    width: _timeBoneWidth,
                    height: _boneHeight,
                    borderRadius: Radii.xs,
                    index: i,
                  ),
                  const SizedBox(width: DiaryEntryLine.timeGap),
                  Expanded(
                    child: SkeletonBone(
                      height: _boneHeight,
                      borderRadius: Radii.xs,
                      index: i + 1,
                    ),
                  ),
                  const SizedBox(width: DiaryEntryLine._chevronGap),
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
