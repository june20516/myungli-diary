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
import 'package:myungli_diary/design/elements/seal.dart';
import 'package:myungli_diary/design/elements/skeleton_bone.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

/// 일기 목록 한 줄(`diary-row`): 흐름 줄 위 날짜 + 카드.
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
  static const ComponentSpec spec = ComponentSpec('diary-row', {}, {
    'pressed',
    'loading',
  });

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
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _dateColumn(context),
          const SizedBox(width: Space.s12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: Space.s12),
              child: PressInkTarget(
                semanticLabel: _semanticLabel(context, l10n),
                identifier: identifier,
                onTap: onTap,
                inkColor: context.tokens.colors.textPrimary,
                borderRadius: const BorderRadius.all(Radius.circular(Radii.lg)),
                customActions: {
                  if (tag != null && tagTap != null)
                    CustomSemanticsAction(label: l10n.tagChipLabel(tag.name)):
                        tagTap,
                },
                child: _card(context),
              ),
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
          fontSize: _numberSize,
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

  Widget _card(BuildContext context) {
    final character = this.character;
    final characterLabel = this.characterLabel;
    final tag = this.tag;
    return DecoratedBox(
      key: cardKey,
      decoration: BoxDecoration(
        color: context.tokens.colors.bgSheet,
        borderRadius: BorderRadius.circular(Radii.lg),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Space.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (character != null && characterLabel != null) ...[
              DayCharacterBadge(variant: character, label: characterLabel),
              const SizedBox(height: Space.s8),
            ] else if (characterPending) ...[
              const SkeletonBone(
                width: DayReadingSkeleton.badgeWidth,
                height: DayCharacterBadge.minHeight,
                borderRadius: Radii.full,
              ),
              const SizedBox(height: Space.s8),
            ],
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
