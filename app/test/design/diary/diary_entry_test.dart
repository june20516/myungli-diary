import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:myungli_diary/design/components/diary/diary_row.dart';
import 'package:myungli_diary/design/components/diary/tag_chip.dart';
import 'package:myungli_diary/design/components/sentence/sentence_block.dart';
import 'package:myungli_diary/design/components/today/day_character.dart';
import 'package:myungli_diary/design/elements/app_icon.dart';
import 'package:myungli_diary/design/elements/skeleton_bone.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';
import 'package:phosphor_glyphs/phosphor_glyphs.dart';

import '../input/input_harness.dart';

final _date = CalendarDate(2026, 10, 12);
final _morning = DateTime(2026, 10, 12, 9, 5);
final _noon = DateTime(2026, 10, 12, 12, 30);
final _night = DateTime(2026, 10, 12, 22, 40);

String _time(DateTime value) => DateFormat('HH:mm').format(value);

DiaryEntryData _data(DateTime at, String excerpt, {VoidCallback? onTap}) =>
    DiaryEntryData(createdAt: at, excerpt: excerpt, onTap: onTap ?? () {});

List<DiaryEntryData> _three({List<VoidCallback>? taps}) => [
  _data(_morning, '아침에 쓴 글', onTap: taps?[0]),
  _data(_noon, '점심에 쓴 글', onTap: taps?[1]),
  _data(_night, '밤에 쓴 글', onTap: taps?[2]),
];

Widget _app(Widget child, {double textScale = 1}) => inputApp(
  MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
    child: SingleChildScrollView(child: SizedBox(width: 360, child: child)),
  ),
);

Widget _group({
  List<DiaryEntryData>? entries,
  TagChip? tag,
  bool withBadge = true,
  bool isLast = false,
}) => _app(
  DiaryDayGroup(
    key: const ValueKey('group'),
    date: _date,
    entries: entries ?? _three(),
    character: withBadge ? DayCharacterVariant.good : null,
    characterLabel: withBadge ? '좋은 날' : null,
    tag: tag,
    isLast: isLast,
  ),
);

Finder _dividers() => find.byKey(DiaryEntryLine.dividerKey);

/// `text` 안 글자 한 줄의 첫 줄 기준선 y(전체 좌표).
double _baselineY(WidgetTester tester, Finder text) {
  final paragraph = tester.renderObject<RenderParagraph>(
    find.descendant(of: text, matching: find.byType(RichText)).first,
  );
  final top = paragraph.localToGlobal(Offset.zero).dy;
  return top +
      paragraph.getDryBaseline(paragraph.constraints, TextBaseline.alphabetic)!;
}

void main() {
  group('diary-row entry 줄', () {
    testWidgets('시각은 caption.md text.secondary tnum, 줄바꿈 없음입니다', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          DiaryEntryLine(createdAt: _morning, excerpt: '아침에 쓴 글', onTap: () {}),
        ),
      );
      final tokens = tester.element(find.byType(DiaryEntryLine)).tokens;
      final time = tester.widget<Text>(find.text(_time(_morning)));
      expect(time.style!.fontSize, tokens.typography.captionMd.fontSize);
      expect(time.style!.fontWeight, tokens.typography.captionMd.fontWeight);
      expect(time.style!.color, tokens.colors.textSecondary);
      expect(
        time.style!.fontFeatures,
        contains(const FontFeature.tabularFigures()),
      );
      expect(time.softWrap, isFalse);
      expect(time.maxLines, 1);
    });

    testWidgets('시각은 createdAt을 기기 시간대로 바꿔 짧은 시각 형식으로 만듭니다', (tester) async {
      final utc = DateTime.utc(2026, 10, 12, 0, 30);
      await tester.pumpWidget(
        _app(DiaryEntryLine(createdAt: utc, excerpt: '글', onTap: () {})),
      );
      expect(find.text(_time(utc.toLocal())), findsOneWidget);
    });

    testWidgets('entry 시각은 locale과 상관없이 HH:mm', (tester) async {
      for (final locale in const [Locale('en'), Locale('ja'), Locale('ko')]) {
        for (final (at, expected) in [
          (DateTime(2026, 10, 12, 9, 5), '09:05'),
          (DateTime(2026, 10, 12, 21), '21:00'),
        ]) {
          await tester.pumpWidget(
            inputApp(
              DiaryEntryLine(createdAt: at, excerpt: '글', onTap: () {}),
              locale: locale,
            ),
          );
          expect(find.text(expected), findsOneWidget, reason: '$locale $at');
        }
      }
    });

    testWidgets('미리보기는 sentence-block preview 한 줄이고 시각 오른쪽 12에서 시작합니다', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          DiaryEntryLine(
            createdAt: _morning,
            excerpt: '아주 긴 글 ' * 30,
            onTap: () {},
          ),
        ),
      );
      final block = tester.widget<SentenceBlock>(find.byType(SentenceBlock));
      expect(block.variant, SentenceBlockVariant.preview);
      expect(block.maxLines, DiaryEntryLine.previewMaxLines);
      expect(DiaryEntryLine.previewMaxLines, 1);
      final timeRight = tester.getTopRight(find.text(_time(_morning))).dx;
      final previewLeft = tester.getTopLeft(find.byType(SentenceBlock)).dx;
      expect(previewLeft - timeRight, Space.s12);
      final paragraph = tester.renderObject<RenderParagraph>(
        find
            .descendant(
              of: find.byType(SentenceBlock),
              matching: find.byType(RichText),
            )
            .first,
      );
      expect(paragraph.maxLines, 1);
      expect(
        tester.getSize(find.byType(DiaryEntryLine)).height,
        DiaryEntryLine.minHeight,
        reason: '긴 글도 한 줄이라 줄 높이가 늘지 않습니다',
      );
    });

    testWidgets('첫 줄 기준선이 시각과 미리보기에서 같습니다', (tester) async {
      await tester.pumpWidget(
        _app(
          DiaryEntryLine(createdAt: _morning, excerpt: '아침에 쓴 글', onTap: () {}),
        ),
      );
      expect(
        _baselineY(tester, find.byType(SentenceBlock)),
        closeTo(_baselineY(tester, find.text(_time(_morning))), 0.5),
      );
    });

    testWidgets('꺾쇠는 caret-right 16 Light text.secondary이고 세로 가운데입니다', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          DiaryEntryLine(createdAt: _morning, excerpt: '아침에 쓴 글', onTap: () {}),
        ),
      );
      final icon = tester.widget<Icon>(
        find.descendant(
          of: find.byKey(DiaryEntryLine.chevronKey),
          matching: find.byType(Icon),
        ),
      );
      final tokens = tester.element(find.byType(DiaryEntryLine)).tokens;
      expect(icon.size, 16);
      expect(icon.size, DiaryEntryLine.chevronSize);
      expect(icon.color, tokens.colors.textSecondary);
      expect(
        tester.getCenter(find.byKey(DiaryEntryLine.chevronKey)).dy,
        tester.getCenter(find.byType(DiaryEntryLine)).dy,
      );
      expect(
        tester.getTopRight(find.byKey(DiaryEntryLine.chevronKey)).dx,
        tester.getTopRight(find.byType(DiaryEntryLine)).dx,
      );
    });

    testWidgets('꺾쇠는 light weight(caret-right Light 글리프)입니다', (tester) async {
      await tester.pumpWidget(
        _app(
          DiaryEntryLine(createdAt: _morning, excerpt: '아침에 쓴 글', onTap: () {}),
        ),
      );
      final appIcon = tester.widget<AppIcon>(
        find.byKey(DiaryEntryLine.chevronKey),
      );
      expect(appIcon.weight, AppIconWeight.light);
      final icon = tester.widget<Icon>(
        find.descendant(
          of: find.byKey(DiaryEntryLine.chevronKey),
          matching: find.byType(Icon),
        ),
      );
      expect(icon.icon, PhosphorIconsLight.caretRight);
    });

    testWidgets('높이는 위아래 12, 최소 48입니다', (tester) async {
      await tester.pumpWidget(
        _app(DiaryEntryLine(createdAt: _morning, excerpt: '글', onTap: () {})),
      );
      expect(DiaryEntryLine.minHeight, 48);
      expect(DiaryEntryLine.paddingY, Space.s12);
      expect(tester.getSize(find.byType(DiaryEntryLine)).height, 48);
      // 글자가 커지면 위아래 12를 지키며 늘어납니다.
      await tester.pumpWidget(
        _app(
          DiaryEntryLine(createdAt: _morning, excerpt: '글', onTap: () {}),
          textScale: 2,
        ),
      );
      final block = tester.getSize(find.byType(SentenceBlock)).height;
      expect(
        tester.getSize(find.byType(DiaryEntryLine)).height,
        greaterThanOrEqualTo(block + 2 * Space.s12),
      );
    });

    testWidgets('본문이 비면 시각만 읽고 한 줄 높이를 지킵니다', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          Column(
            children: [
              DiaryEntryLine(
                key: const ValueKey('empty'),
                createdAt: _morning,
                excerpt: '   ',
                onTap: () {},
              ),
              DiaryEntryLine(
                key: const ValueKey('full'),
                createdAt: _morning,
                excerpt: '글',
                onTap: () {},
              ),
            ],
          ),
          textScale: 2,
        ),
      );
      expect(
        tester.getSize(find.byKey(const ValueKey('empty'))).height,
        tester.getSize(find.byKey(const ValueKey('full'))).height,
      );
      final node = tester.getSemantics(find.byKey(const ValueKey('empty')));
      expect(node.getSemanticsData().label, _time(_morning));
      handle.dispose();
    });

    testWidgets('본문이 빈 줄로 시작하면 화면도 낭독도 첫 내용 줄입니다', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          DiaryEntryLine(
            createdAt: _morning,
            excerpt: '\n  \n아침에 쓴 글\n둘째 줄',
            onTap: () {},
          ),
        ),
      );
      final block = tester.widget<SentenceBlock>(find.byType(SentenceBlock));
      expect(block.text.segments.single.text, '아침에 쓴 글');
      final node = tester.getSemantics(find.byType(DiaryEntryLine));
      expect(node.getSemanticsData().label, '${_time(_morning)}, 아침에 쓴 글');
      handle.dispose();
    });

    testWidgets('entry 줄은 시각과 미리보기 첫 줄을 읽습니다', (tester) async {
      final handle = tester.ensureSemantics();
      var taps = 0;
      await tester.pumpWidget(
        _app(
          DiaryEntryLine(
            createdAt: _morning,
            excerpt: '아침에 쓴 글\n둘째 줄',
            identifier: 'diary-list.entry',
            onTap: () => taps++,
          ),
        ),
      );
      final node = tester.getSemantics(find.byType(DiaryEntryLine));
      final data = node.getSemanticsData();
      expect(data.label, '${_time(_morning)}, 아침에 쓴 글');
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.identifier, 'diary-list.entry');
      node.owner!.performAction(node.id, SemanticsAction.tap);
      expect(taps, 1);
      handle.dispose();
    });

    testWidgets('줄을 누르면 onTap이 불립니다', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _app(
          DiaryEntryLine(
            createdAt: _morning,
            excerpt: '글',
            onTap: () => taps++,
          ),
        ),
      );
      await tester.tap(find.byType(DiaryEntryLine));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });

    testWidgets(
      'showDivider면 줄 위에 1px 점선(대시 4·간격 3, color.timeline.entry)을 긋습니다',
      (tester) async {
        await tester.pumpWidget(
          _app(
            DiaryEntryLine(
              createdAt: _morning,
              excerpt: '글',
              showDivider: true,
              onTap: () {},
            ),
          ),
        );
        final color = tester
            .element(find.byType(DiaryEntryLine))
            .tokens
            .colors
            .timelineEntry;
        expect(DiaryEntryLine.dividerWidth, 1);
        expect(DiaryEntryLine.dividerDash, 4);
        expect(DiaryEntryLine.dividerGap, 3);
        final painted = tester.renderObject(_dividers());
        expect(
          painted,
          paints
            ..line(
              p1: const Offset(0, 0.5),
              p2: const Offset(4, 0.5),
              color: color,
              strokeWidth: 1,
            )
            ..line(
              p1: const Offset(7, 0.5),
              p2: const Offset(11, 0.5),
              color: color,
              strokeWidth: 1,
            ),
        );
        // 줄 전체 너비(시각 왼쪽 끝 ~ 꺾쇠 오른쪽 끝)이고 최소 48 안에 듭니다.
        expect(tester.getSize(_dividers()).width, 360);
        expect(tester.getSize(find.byType(DiaryEntryLine)).height, 48);
      },
    );

    testWidgets('showDivider가 false면 점선이 없습니다', (tester) async {
      await tester.pumpWidget(
        _app(DiaryEntryLine(createdAt: _morning, excerpt: '글', onTap: () {})),
      );
      expect(_dividers(), findsNothing);
    });
  });

  group('diary-row day 묶음 카드', () {
    testWidgets('점선은 줄과 줄 사이에만 있습니다(첫 줄 위·끝 줄 아래 없음)', (tester) async {
      await tester.pumpWidget(_group());
      expect(_dividers(), findsNWidgets(2));
      final lines = find.byType(DiaryEntryLine);
      expect(lines, findsNWidgets(3));
      final first = tester.getTopLeft(lines.at(0)).dy;
      final firstBottom = tester.getBottomLeft(lines.at(0)).dy;
      final lastBottom = tester.getBottomLeft(lines.at(2)).dy;
      for (final divider in _dividers().evaluate()) {
        final y = tester.getTopLeft(find.byWidget(divider.widget)).dy;
        expect(y, greaterThanOrEqualTo(firstBottom - 0.01));
        expect(y, lessThan(lastBottom));
        expect(y, greaterThan(first));
      }
    });

    testWidgets('두 편이면 점선 하나입니다', (tester) async {
      await tester.pumpWidget(_group(entries: _three().take(2).toList()));
      expect(_dividers(), findsOneWidget);
    });

    testWidgets('줄은 작성 순(받은 순서)으로 놓이고 다시 정렬하지 않습니다', (tester) async {
      // 일부러 시각이 뒤섞인 순서로 줍니다.
      await tester.pumpWidget(
        _group(
          entries: [
            _data(_night, '셋째'),
            _data(_morning, '첫째'),
            _data(_noon, '둘째'),
          ],
        ),
      );
      final tops = [
        for (final text in ['셋째', '첫째', '둘째'])
          tester.getTopLeft(find.text(text)).dy,
      ];
      expect(tops, orderedEquals([...tops]..sort()));
    });

    testWidgets('카드: 배지 → entry 줄들(배지 아래 4) → 태그(마지막 줄 아래 8), 미리보기 두 줄은 없습니다', (
      tester,
    ) async {
      await tester.pumpWidget(
        _group(
          tag: TagChip(
            name: '천을귀인',
            variant: TagChipVariant.good,
            onTap: () {},
          ),
        ),
      );
      final tokens = tester.element(find.byType(DiaryDayGroup)).tokens;
      final card = tester.widget<DecoratedBox>(find.byKey(DiaryRow.cardKey));
      final decoration = card.decoration as BoxDecoration;
      expect(decoration.color, tokens.colors.bgSheet);
      expect(decoration.borderRadius, BorderRadius.circular(Radii.lg));
      final badge = find.byType(DayCharacterBadge);
      final lines = find.byType(DiaryEntryLine);
      final chip = find.byType(TagChip);
      expect(DiaryRow.entriesMarginTop, Space.s4);
      expect(DiaryRow.groupTagMarginTop, Space.s8);
      expect(
        tester.getTopLeft(lines.first).dy - tester.getBottomLeft(badge).dy,
        Space.s4,
      );
      expect(
        tester.getTopLeft(chip).dy - tester.getBottomLeft(lines.last).dy,
        Space.s8,
      );
      expect(
        tester.getTopLeft(badge).dx -
            tester.getTopLeft(find.byKey(DiaryRow.cardKey)).dx,
        Space.s16,
      );
      expect(find.byType(SentenceBlock), findsNWidgets(3));
    });

    testWidgets('배지가 없으면 첫 줄이 카드 안쪽 위 16에서 시작하고 태그 칩이 없으면 그리지 않습니다', (
      tester,
    ) async {
      await tester.pumpWidget(_group(withBadge: false));
      expect(find.byType(DayCharacterBadge), findsNothing);
      expect(find.byType(TagChip), findsNothing);
      expect(
        tester.getTopLeft(find.byType(DiaryEntryLine).first).dy -
            tester.getTopLeft(find.byKey(DiaryRow.cardKey)).dy,
        Space.s16,
      );
    });

    testWidgets('날짜 열과 흐름 줄이 카드 높이만큼 이어집니다(마지막 줄 뒤는 없음)', (tester) async {
      await tester.pumpWidget(_group());
      final rail = find.byKey(DiaryRow.railKey);
      expect(find.text('12'), findsOneWidget);
      expect(tester.getSize(rail).width, 1.5);
      expect(
        tester.getBottomLeft(rail).dy,
        greaterThanOrEqualTo(
          tester.getBottomLeft(find.byKey(DiaryRow.cardKey)).dy,
        ),
        reason: '카드 높이만큼 이어져 다음 날짜까지 갑니다',
      );
      await tester.pumpWidget(_group(isLast: true));
      expect(find.byKey(DiaryRow.railKey), findsNothing);
    });

    testWidgets('묶음 카드는 버튼이 아니고 그룹, 안의 줄이 각각 버튼입니다', (tester) async {
      final handle = tester.ensureSemantics();
      final taps = [0, 0, 0];
      await tester.pumpWidget(
        _group(
          entries: _three(
            taps: [() => taps[0]++, () => taps[1]++, () => taps[2]++],
          ),
        ),
      );
      final group = tester.getSemantics(
        find.bySemanticsLabel('10월 12일 월요일, 좋은 날'),
      );
      final data = group.getSemanticsData();
      expect(data.flagsCollection.isButton, isFalse);
      expect(data.hasAction(SemanticsAction.tap), isFalse);
      final entry = tester.getSemantics(
        find.bySemanticsLabel('${_time(_noon)}, 점심에 쓴 글'),
      );
      expect(entry.getSemanticsData().flagsCollection.isButton, isTrue);
      entry.owner!.performAction(entry.id, SemanticsAction.tap);
      expect(taps, [0, 1, 0]);
      handle.dispose();
    });

    testWidgets('묶음 그룹 안에는 배지·날짜 숫자·요일 노드가 따로 없습니다(라벨 중복 금지)', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_group());
      expect(find.bySemanticsLabel('10월 12일 월요일, 좋은 날'), findsOneWidget);
      expect(find.bySemanticsLabel('좋은 날'), findsNothing);
      expect(find.bySemanticsLabel('12'), findsNothing);
      expect(find.bySemanticsLabel('월'), findsNothing);
      handle.dispose();
    });

    testWidgets('줄마다 따로 눌립니다(눌린 줄의 onTap만)', (tester) async {
      final taps = [0, 0, 0];
      await tester.pumpWidget(
        _group(
          entries: _three(
            taps: [() => taps[0]++, () => taps[1]++, () => taps[2]++],
          ),
        ),
      );
      await tester.tap(find.byType(DiaryEntryLine).at(2));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DiaryEntryLine).at(0));
      await tester.pumpAndSettle();
      expect(taps, [1, 0, 1]);
    });

    testWidgets('태그 칩은 따로 눌립니다', (tester) async {
      var tags = 0;
      await tester.pumpWidget(
        _group(
          tag: TagChip(
            name: '천을귀인',
            variant: TagChipVariant.good,
            onTap: () => tags++,
          ),
        ),
      );
      await tester.tap(find.byType(TagChip));
      await tester.pumpAndSettle();
      expect(tags, 1);
    });

    testWidgets('entries는 두 개 이상이어야 합니다', (tester) async {
      expect(
        () => DiaryDayGroup(date: _date, entries: [_data(_morning, '한 편')]),
        throwsAssertionError,
      );
    });

    testWidgets('배지를 기다리는 동안은 배지 자리가 skeleton입니다', (tester) async {
      await tester.pumpWidget(
        _app(
          DiaryDayGroup(date: _date, entries: _three(), characterPending: true),
        ),
      );
      expect(find.byType(DayCharacterBadge), findsNothing);
      expect(
        tester.getSize(find.byType(SkeletonBone)).height,
        DayCharacterBadge.minHeight,
      );
    });

    testWidgets('몇 편이든 모두 보입니다(접지 않음)', (tester) async {
      await tester.pumpWidget(
        _group(entries: [for (var i = 0; i < 12; i++) _data(_morning, '글 $i')]),
      );
      expect(find.byType(DiaryEntryLine), findsNWidgets(12));
      expect(_dividers(), findsNWidgets(11));
    });
  });

  group('diary-row entries', () {
    testWidgets('card: 오늘 바탕은 bg.sheet radius.lg 좌우 16 위아래 4, 위 간격 12입니다', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          DiaryEntries(entries: _three(), surface: DiaryEntriesSurface.card),
        ),
      );
      final tokens = tester.element(find.byType(DiaryEntries)).tokens;
      final card = find.byKey(DiaryEntries.cardKey);
      final decoration =
          tester.widget<DecoratedBox>(card).decoration as BoxDecoration;
      expect(decoration.color, tokens.colors.bgSheet);
      expect(decoration.borderRadius, BorderRadius.circular(Radii.lg));
      expect(DiaryEntries.cardPaddingX, Space.s16);
      expect(DiaryEntries.cardPaddingY, Space.s4);
      expect(DiaryEntries.cardMarginTop, Space.s12);
      expect(
        tester.getTopLeft(card).dy -
            tester.getTopLeft(find.byType(DiaryEntries)).dy,
        Space.s12,
      );
      expect(
        tester.getTopLeft(find.byType(DiaryEntryLine).first).dx -
            tester.getTopLeft(card).dx,
        Space.s16,
      );
      expect(
        tester.getTopLeft(find.byType(DiaryEntryLine).first).dy -
            tester.getTopLeft(card).dy,
        Space.s4,
      );
      expect(
        tester.getBottomLeft(card).dy -
            tester.getBottomLeft(find.byType(DiaryEntryLine).last).dy,
        Space.s4,
      );
      // 날짜 열·배지·태그는 그리지 않습니다.
      expect(find.byKey(DiaryRow.dateColumnKey), findsNothing);
      expect(find.byType(DayCharacterBadge), findsNothing);
      expect(find.byType(TagChip), findsNothing);
      expect(_dividers(), findsNWidgets(2));
    });

    testWidgets(
      'plain: 그날 시트는 바탕 없이 줄만, 머리는 label.md text.secondary 위 16 아래 4입니다',
      (tester) async {
        await tester.pumpWidget(
          _app(
            DiaryEntries(
              entries: _three(),
              surface: DiaryEntriesSurface.plain,
              head: '이날 일기 3편',
            ),
          ),
        );
        final tokens = tester.element(find.byType(DiaryEntries)).tokens;
        expect(find.byKey(DiaryEntries.cardKey), findsNothing);
        final head = tester.widget<Text>(find.text('이날 일기 3편'));
        expect(head.style!.fontSize, tokens.typography.labelMd.fontSize);
        expect(head.style!.fontWeight, tokens.typography.labelMd.fontWeight);
        expect(head.style!.color, tokens.colors.textSecondary);
        expect(DiaryEntries.headMarginTop, Space.s16);
        expect(DiaryEntries.headMarginBottom, Space.s4);
        final top = tester.getTopLeft(find.byType(DiaryEntries)).dy;
        expect(tester.getTopLeft(find.text('이날 일기 3편')).dy - top, Space.s16);
        expect(
          tester.getTopLeft(find.byType(DiaryEntryLine).first).dy -
              tester.getBottomLeft(find.text('이날 일기 3편')).dy,
          Space.s4,
        );
        // 머리는 링크가 아니라 글자입니다(누르는 자리 없음).
        final handle = tester.ensureSemantics();
        final data = tester
            .getSemantics(find.text('이날 일기 3편'))
            .getSemanticsData();
        expect(data.hasAction(SemanticsAction.tap), isFalse);
        handle.dispose();
      },
    );

    testWidgets('headIdentifier가 있으면 머리에 Semantics identifier로 붙습니다', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          DiaryEntries(
            entries: _three(),
            surface: DiaryEntriesSurface.plain,
            head: '이날 일기 3편',
            headIdentifier: 'day-sheet.diary.open',
          ),
        ),
      );
      expect(
        tester
            .getSemantics(find.text('이날 일기 3편'))
            .getSemanticsData()
            .identifier,
        'day-sheet.diary.open',
      );
      handle.dispose();
    });

    testWidgets('plain에서 head가 없으면 머리를 그리지 않습니다', (tester) async {
      await tester.pumpWidget(
        _app(
          DiaryEntries(entries: _three(), surface: DiaryEntriesSurface.plain),
        ),
      );
      expect(
        tester.getTopLeft(find.byType(DiaryEntryLine).first).dy,
        tester.getTopLeft(find.byType(DiaryEntries)).dy,
      );
    });

    testWidgets('entries가 비면 아무것도 그리지 않습니다(머리도 바탕도)', (tester) async {
      for (final surface in DiaryEntriesSurface.values) {
        await tester.pumpWidget(
          _app(
            DiaryEntries(entries: const [], surface: surface, head: '이날 일기 0편'),
          ),
        );
        expect(tester.getSize(find.byType(DiaryEntries)).height, 0);
        expect(find.text('이날 일기 0편'), findsNothing);
        expect(find.byKey(DiaryEntries.cardKey), findsNothing);
        expect(find.byType(DiaryEntryLine), findsNothing);
      }
    });

    testWidgets('한 편이어도 줄 하나(점선 없음)이고 누르면 그 일기입니다', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _app(
          DiaryEntries(
            entries: [_data(_morning, '혼자', onTap: () => taps++)],
            surface: DiaryEntriesSurface.card,
          ),
        ),
      );
      expect(_dividers(), findsNothing);
      await tester.tap(find.byType(DiaryEntryLine));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });

    testWidgets('줄은 각각 버튼이고 시트 머리·바탕은 버튼이 아닙니다', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          DiaryEntries(entries: _three(), surface: DiaryEntriesSurface.card),
        ),
      );
      for (final at in [_morning, _noon, _night]) {
        final node = tester.getSemantics(
          find.bySemanticsLabel(RegExp('^${RegExp.escape(_time(at))}, ')),
        );
        expect(node.getSemanticsData().flagsCollection.isButton, isTrue);
      }
      handle.dispose();
    });

    testWidgets('skeleton은 줄 두 개 높이이고 스크린리더는 읽지 않습니다', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(const DiaryEntriesSkeleton(surface: DiaryEntriesSurface.plain)),
      );
      expect(
        tester.getSize(find.byType(DiaryEntriesSkeleton)).height,
        2 * DiaryEntryLine.minHeight,
      );
      expect(find.byType(SkeletonBone), findsWidgets);
      expect(find.byType(Text), findsNothing);
      handle.dispose();
    });

    testWidgets('skeleton card는 바탕 안(위아래 4)에 줄 두 개 높이입니다', (tester) async {
      await tester.pumpWidget(_app(const DiaryEntriesSkeleton()));
      expect(
        tester.getSize(find.byKey(DiaryEntries.cardKey)).height,
        2 * DiaryEntryLine.minHeight + 2 * DiaryEntries.cardPaddingY,
      );
    });
  });
}
