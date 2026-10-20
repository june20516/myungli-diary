import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:myungli_diary/design/components/diary/diary_row.dart';
import 'package:myungli_diary/design/components/diary/tag_chip.dart';
import 'package:myungli_diary/design/components/sentence/sentence_block.dart';
import 'package:myungli_diary/design/components/today/day_character.dart';
import 'package:myungli_diary/design/elements/seal.dart';
import 'package:myungli_diary/design/elements/skeleton_bone.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

import '../input/input_harness.dart';

final _date = CalendarDate(2026, 10, 12);

Widget _rows({
  bool withBadge = true,
  bool withTag = true,
  VoidCallback? onTap,
  VoidCallback? onTag,
  bool lastOnly = false,
}) => inputApp(
  SingleChildScrollView(
    child: SizedBox(
      width: 360,
      child: Column(
        children: [
          if (!lastOnly)
            DiaryRow(
              key: const ValueKey('first'),
              date: _date,
              excerpt: '오랜만에 연락이 온 친구와 점심을 먹었다.',
              character: withBadge ? DayCharacterVariant.good : null,
              characterLabel: withBadge ? '좋은 날' : null,
              tag: withTag
                  ? TagChip(
                      name: '천을귀인',
                      variant: TagChipVariant.good,
                      onTap: onTag ?? () {},
                    )
                  : null,
              onTap: onTap ?? () {},
            ),
          DiaryRow(
            key: const ValueKey('last'),
            date: CalendarDate(2026, 10, 8),
            excerpt: '아침 공기가 갑자기 차가워졌다.',
            isLast: true,
            onTap: () {},
          ),
        ],
      ),
    ),
  ),
);

Finder _in(String key, Finder finder) =>
    find.descendant(of: find.byKey(ValueKey(key)), matching: finder);

void main() {
  group('diary-row', () {
    testWidgets('날짜 열 44: 숫자 18 600 tnum이 옅은 도장 34 가운데, 아래 요일 caption.md', (
      tester,
    ) async {
      await tester.pumpWidget(_rows());
      final tokens = tester.element(find.byType(DiaryRow).first).tokens;
      expect(
        tester.getSize(_in('first', find.byKey(DiaryRow.dateColumnKey))).width,
        44,
      );
      final number = tester.widget<Text>(_in('first', find.text('12')));
      expect(number.style!.fontSize, 18);
      expect(number.style!.fontWeight, FontWeight.w600);
      expect(
        number.style!.fontFeatures,
        contains(const FontFeature.tabularFigures()),
      );
      final seal = tester.widget<Seal>(_in('first', find.byType(Seal)));
      expect((seal.size, seal.variant), (SealSize.row, SealVariant.soft));
      expect(
        tester.getCenter(_in('first', find.byType(Seal))),
        tester.getCenter(_in('first', find.text('12'))),
      );
      final weekday = tester.widget<Text>(_in('first', find.text('월')));
      expect(weekday.style!.fontSize, tokens.typography.captionMd.fontSize);
      expect(weekday.style!.color, tokens.colors.textSecondary);
    });

    testWidgets('날짜 열은 글자 1.3배에서 멈춰 큰 글자에서도 숫자가 한 줄입니다', (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: _rows(),
        ),
      );
      final number = _in('first', find.text('12'));
      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(of: number, matching: find.byType(RichText)),
      );
      expect(paragraph.textScaler.scale(10), closeTo(13, 0.01));
      expect(tester.getSize(number).height, lessThan(18 * 1.3 * 1.5));
      expect(tester.takeException(), isNull);
    });

    testWidgets('흐름 줄 1.5는 요일 아래에서 줄 끝까지 이어지고 마지막 줄 뒤에는 없습니다', (tester) async {
      await tester.pumpWidget(_rows());
      final rail = _in('first', find.byKey(DiaryRow.railKey));
      expect(tester.getSize(rail).width, 1.5);
      final weekdayBottom = tester
          .getBottomLeft(_in('first', find.text('월')))
          .dy;
      expect(tester.getTopLeft(rail).dy, greaterThanOrEqualTo(weekdayBottom));
      expect(
        tester.getBottomLeft(rail).dy,
        tester.getBottomLeft(find.byKey(const ValueKey('first'))).dy,
        reason: '다음 줄 날짜까지 끊기지 않습니다',
      );
      expect(_in('last', find.byKey(DiaryRow.railKey)), findsNothing);
    });

    testWidgets('카드: bg.sheet radius.lg 안쪽 16, 배지 → 미리보기(preview) → 태그 칩', (
      tester,
    ) async {
      await tester.pumpWidget(_rows());
      final tokens = tester.element(find.byType(DiaryRow).first).tokens;
      final card =
          tester
                  .widget<DecoratedBox>(
                    _in('first', find.byKey(DiaryRow.cardKey)),
                  )
                  .decoration
              as BoxDecoration;
      expect(card.color, tokens.colors.bgSheet);
      expect(card.borderRadius, BorderRadius.circular(Radii.lg));
      final badge = _in('first', find.byType(DayCharacterBadge));
      final preview = _in('first', find.byType(SentenceBlock));
      final chip = _in('first', find.byType(TagChip));
      expect(
        tester.widget<SentenceBlock>(preview).variant,
        SentenceBlockVariant.preview,
      );
      expect(
        tester.getTopLeft(preview).dy - tester.getBottomLeft(badge).dy,
        Space.s8,
      );
      expect(
        tester.getTopLeft(chip).dy - tester.getBottomLeft(preview).dy,
        Space.s12,
      );
      expect(
        tester.getTopLeft(badge).dx -
            tester.getTopLeft(_in('first', find.byKey(DiaryRow.cardKey))).dx,
        Space.s16,
      );
    });

    testWidgets('배지·태그가 없으면 그 자리를 그리지 않습니다', (tester) async {
      await tester.pumpWidget(_rows(withBadge: false, withTag: false));
      expect(_in('first', find.byType(DayCharacterBadge)), findsNothing);
      expect(_in('first', find.byType(TagChip)), findsNothing);
      final preview = _in('first', find.byType(SentenceBlock));
      final card = _in('first', find.byKey(DiaryRow.cardKey));
      expect(
        tester.getTopLeft(preview).dy - tester.getTopLeft(card).dy,
        Space.s16,
      );
    });

    testWidgets('카드를 누르면 onTap, 태그 칩을 누르면 태그만 갑니다', (tester) async {
      var rows = 0;
      var tags = 0;
      await tester.pumpWidget(_rows(onTap: () => rows++, onTag: () => tags++));
      await tester.tap(_in('first', find.byType(SentenceBlock)));
      await tester.pumpAndSettle();
      await tester.tap(_in('first', find.byType(TagChip)));
      await tester.pumpAndSettle();
      expect((rows, tags), (1, 1));
    });

    testWidgets('스크린리더: 카드 한 덩어리 버튼, "날짜 요일, 배지, 미리보기, 태그" + 태그 동작', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      var tags = 0;
      await tester.pumpWidget(_rows(onTag: () => tags++));
      final node = tester.getSemantics(
        find.bySemanticsLabel(RegExp('^10월 12일 월요일')),
      );
      final data = node.getSemanticsData();
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.label, '10월 12일 월요일, 좋은 날, 오랜만에 연락이 온 친구와 점심을 먹었다., #천을귀인');
      expect(data.customSemanticsActionIds, hasLength(1));
      node.owner!.performAction(
        node.id,
        SemanticsAction.customAction,
        data.customSemanticsActionIds!.single,
      );
      expect(tags, 1);
      handle.dispose();
    });

    testWidgets('배지를 기다리는 동안(characterPending) 배지 자리는 skeleton입니다', (
      tester,
    ) async {
      await tester.pumpWidget(
        inputApp(
          SizedBox(
            width: 360,
            child: DiaryRow(
              date: _date,
              excerpt: '본문',
              characterPending: true,
              onTap: () {},
            ),
          ),
        ),
      );
      expect(find.byType(DayCharacterBadge), findsNothing);
      final bone = tester.getSize(find.byType(SkeletonBone));
      expect(bone.height, DayCharacterBadge.minHeight);
    });

    testWidgets('loading: 목록 skeleton 줄은 도장 자리·카드 뼈이고 스크린리더는 읽지 않습니다', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        inputApp(const SizedBox(width: 360, child: DiaryRowSkeleton())),
      );
      expect(find.byType(SkeletonBone), findsWidgets);
      expect(
        tester.getSize(find.byKey(DiaryRow.dateColumnKey)).width,
        DiaryRow.dateColumnWidth,
      );
      expect(find.byType(Text), findsNothing);
      handle.dispose();
    });

    testWidgets('달 머리는 type.subtitle입니다', (tester) async {
      await tester.pumpWidget(
        inputApp(const DiaryMonthHeader(label: '2026년 10월')),
      );
      final tokens = tester.element(find.byType(DiaryMonthHeader)).tokens;
      final text = tester.widget<Text>(find.text('2026년 10월'));
      expect(text.style!.fontSize, tokens.typography.subtitle.fontSize);
      final handle = tester.ensureSemantics();
      await tester.pump();
      expect(
        tester
            .getSemantics(find.text('2026년 10월'))
            .getSemanticsData()
            .flagsCollection
            .isHeader,
        isTrue,
      );
      handle.dispose();
    });
  });
}
