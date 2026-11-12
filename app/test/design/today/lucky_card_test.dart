import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/gen/model/five_element.dart';
import 'package:myungli_diary/core/api/gen/model/rendered_text.dart';
import 'package:myungli_diary/core/api/gen/model/segment.dart';
import 'package:myungli_diary/design/components/today/lucky_card.dart';
import 'package:myungli_diary/design/elements/app_icon.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';

import '../input/input_harness.dart';

RenderedText _text(String value) =>
    RenderedText(segments: [Segment(text: value)]);

/// 행운 4종.
const List<LuckyCardVariant> _luckyVariants = LuckyCardVariant.luckyValues;

List<LuckyItem> _items() => [
  LuckyItem(
    variant: LuckyCardVariant.color,
    name: '행운 색',
    value: '파랑',
    explain: _text('물의 기운이 마음을 가라앉혀요.'),
    element: FiveElement.water,
  ),
  LuckyItem(
    variant: LuckyCardVariant.direction,
    name: '행운 방향',
    value: '동',
    explain: _text('약속 장소를 고른다면 동쪽이 좋아요.'),
  ),
  LuckyItem(
    variant: LuckyCardVariant.number,
    name: '행운 숫자',
    value: '3',
    explain: _text('3이 흐름을 열어 줘요.'),
  ),
  LuckyItem(
    variant: LuckyCardVariant.time,
    name: '낮의 길한 시간',
    value: '오후 3시',
    explain: _text('오후 3시에 집중이 잘 돼요.'),
    period: AppTimeOfDay.day,
  ),
];

Widget _app({
  List<LuckyItem>? opened,
  Completer<void>? sheet,
  bool interactive = true,
  Brightness brightness = Brightness.light,
}) {
  final row = LuckyCardRow(
    items: _items(),
    onOpen: interactive
        ? (item) {
            opened?.add(item);
            return sheet?.future;
          }
        : null,
  );
  return inputApp(
    Center(child: SizedBox(width: 360, child: row)),
    brightness: brightness,
  );
}

Finder _chip(LuckyCardVariant variant) =>
    find.byKey(LuckyCardRow.chipKey(variant));

/// 칩의 시맨틱 노드를 가진 위젯(눌림 자리, 표시 전용이면 라벨 노드).
Finder _chipNode(LuckyCardVariant variant) =>
    find.descendant(of: _chip(variant), matching: find.byType(Semantics)).first;

Finder _surface(LuckyCardVariant variant) => find.descendant(
  of: _chip(variant),
  matching: find.byKey(LuckyChip.surfaceKey),
);

SemanticsData _data(WidgetTester tester, Finder finder) =>
    tester.getSemantics(finder).getSemanticsData();

/// 칩 바탕 앞에 덧그린 테두리.
Border _borderOf(WidgetTester tester, LuckyCardVariant variant) {
  final box = tester.widget<Container>(_surface(variant));
  return (box.foregroundDecoration! as BoxDecoration).border! as Border;
}

void main() {
  group('lucky-card', () {
    testWidgets('time 값만 숫자 폭이 고른 tnum이고 다른 값은 그대로입니다', (tester) async {
      // 칩 줄 배치 테스트들이 한 줄을 전제하므로 시간 칩은 따로 그립니다.
      await tester.pumpWidget(
        inputApp(
          Center(
            child: LuckyChip(
              item: LuckyItem(
                variant: LuckyCardVariant.time,
                name: '낮의 길한 시간',
                value: '09:30~11:30',
                explain: _text('오전에 집중이 잘 돼요.'),
                period: AppTimeOfDay.day,
              ),
              open: false,
              onTap: null,
            ),
          ),
        ),
      );
      final time = tester.widget<Text>(find.text('09:30~11:30'));
      expect(time.style!.fontFeatures, LuckyChip.timeValueFeatures);
      expect(
        LuckyChip.timeValueFeatures,
        contains(const FontFeature.tabularFigures()),
      );
      await tester.pumpWidget(_app());
      final number = tester.widget<Text>(find.text('3'));
      expect(number.style!.fontFeatures, isNot(LuckyChip.timeValueFeatures));
    });

    testWidgets('글자 배율 2.0에서 앞 아이콘이 배율만큼 커지고 칩은 최소 높이 34 아래로 줄지 않으며 넘치지 않습니다', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(_app());
      final icons = tester
          .widgetList<AppIcon>(find.byType(AppIcon))
          .where((icon) => icon.scalesWithText);
      expect(icons, isNotEmpty);
      for (final icon in icons) {
        final drawn = tester.widget<Icon>(
          find.descendant(of: find.byWidget(icon), matching: find.byType(Icon)),
        );
        expect(drawn.size, icon.size!.logical * 2);
      }
      for (final variant in _luckyVariants) {
        final chip = find.descendant(
          of: _chip(variant),
          matching: find.byKey(LuckyChip.surfaceKey),
        );
        expect(
          tester.getSize(chip).height,
          greaterThanOrEqualTo(34),
          reason: variant.name,
        );
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('칩은 높이 34 이상이고 누름 영역은 44 이상입니다', (tester) async {
      await tester.pumpWidget(_app());
      for (final variant in _luckyVariants) {
        final chip = find.descendant(
          of: _chip(variant),
          matching: find.byKey(LuckyChip.surfaceKey),
        );
        expect(
          tester.getSize(chip).height,
          greaterThanOrEqualTo(34),
          reason: variant.name,
        );
        expect(
          tester.getSize(_chip(variant)).width,
          greaterThanOrEqualTo(44),
          reason: variant.name,
        );
      }
    });

    testWidgets('칩 모양: 알약 반지름·bg.sheet·값 글자', (tester) async {
      await tester.pumpWidget(_app());
      final surface = find.descendant(
        of: _chip(LuckyCardVariant.direction),
        matching: find.byKey(LuckyChip.surfaceKey),
      );
      final decoration =
          tester.widget<Container>(surface).decoration! as BoxDecoration;
      final tokens = tester.element(surface).tokens;
      expect(decoration.color, tokens.colors.bgSheet);
      expect(
        decoration.borderRadius,
        const BorderRadius.all(Radius.circular(9999)),
      );
      final value = tester.widget<Text>(
        find.descendant(of: surface, matching: find.text('동')),
      );
      expect(value.style?.fontSize, tokens.typography.labelMd.fontSize);
      expect(value.style?.color, tokens.colors.textPrimary);
    });

    testWidgets('아이콘은 16이고 text.secondary(시간은 해와 달 색), 색 변형은 14 견본 원입니다', (
      tester,
    ) async {
      await tester.pumpWidget(_app());
      final tokens = tester.element(_chip(LuckyCardVariant.time)).tokens;
      for (final variant in [
        LuckyCardVariant.direction,
        LuckyCardVariant.number,
        LuckyCardVariant.time,
      ]) {
        final icon = tester.widget<Icon>(
          find.descendant(of: _chip(variant), matching: find.byType(Icon)),
        );
        expect(icon.size, 16, reason: variant.name);
        expect(
          icon.color,
          variant == LuckyCardVariant.time
              ? tokens.colors.timeDay
              : tokens.colors.textSecondary,
          reason: variant.name,
        );
      }
      expect(
        find.descendant(
          of: _chip(LuckyCardVariant.color),
          matching: find.byType(Icon),
        ),
        findsNothing,
      );
      final swatch = find.descendant(
        of: _chip(LuckyCardVariant.color),
        matching: find.byKey(LuckyChip.swatchKey),
      );
      expect(tester.getSize(swatch), const Size.square(14));
      final decoration =
          tester
                  .widget<Container>(
                    find.descendant(
                      of: swatch,
                      matching: find.byType(Container),
                    ),
                  )
                  .decoration!
              as BoxDecoration;
      // 오행 견본 색은 칩이 테마 토큰에서 고릅니다.
      expect(decoration.color, tokens.colors.ohaengWaterSwatch);
      expect(decoration.shape, BoxShape.circle);
      expect(
        (decoration.border! as Border).top.color,
        tokens.colors.swatchBorder,
      );
      expect((decoration.border! as Border).top.width, 1);
    });

    testWidgets('칩 높이 34 안쪽 여백 12·아이콘과 값 사이 4', (tester) async {
      await tester.pumpWidget(_app());
      final chip = tester.getRect(
        find.descendant(
          of: _chip(LuckyCardVariant.direction),
          matching: find.byKey(LuckyChip.surfaceKey),
        ),
      );
      final icon = tester.getRect(
        find.descendant(
          of: _chip(LuckyCardVariant.direction),
          matching: find.byType(Icon),
        ),
      );
      final value = tester.getRect(
        find.descendant(
          of: _chip(LuckyCardVariant.direction),
          matching: find.text('동'),
        ),
      );
      expect(icon.left - chip.left, 12);
      expect(value.left - icon.right, 4);
      expect(chip.right - value.right, 12);
      expect(chip.height, 34);
    });

    testWidgets('칩 줄은 폭이 모자라면 두 줄로 넘어갑니다', (tester) async {
      await tester.pumpWidget(
        inputApp(
          Center(
            child: SizedBox(width: 200, child: LuckyCardRow(items: _items())),
          ),
        ),
      );
      final tops = {
        for (final variant in _luckyVariants)
          tester.getTopLeft(_chip(variant)).dy,
      };
      expect(tops.length, greaterThan(1));
    });

    testWidgets('칩 바탕은 불투명 bg.sheet이고 1px line 테두리를 안쪽에 그립니다(V75)', (
      tester,
    ) async {
      for (final brightness in Brightness.values) {
        await tester.pumpWidget(_app(brightness: brightness));
        final tokens = tester.element(_chip(LuckyCardVariant.color)).tokens;
        expect(tokens.colors.bgSheet.a, 1, reason: '불투명');
        for (final variant in _luckyVariants) {
          final box = tester.widget<Container>(_surface(variant));
          expect(
            (box.decoration! as BoxDecoration).color,
            tokens.colors.bgSheet,
            reason: variant.name,
          );
          final border = _borderOf(tester, variant);
          expect(border.top.width, 1, reason: variant.name);
          expect(border.top.color, tokens.colors.line, reason: variant.name);
        }
      }
    });

    testWidgets('칩을 누르면 onOpen이 그 항목으로 불리고 아래에 설명 상자가 생기지 않습니다', (
      tester,
    ) async {
      final opened = <LuckyItem>[];
      await tester.pumpWidget(_app(opened: opened));
      await tester.tap(_chip(LuckyCardVariant.direction));
      await tester.pumpAndSettle();
      expect(opened.single.variant, LuckyCardVariant.direction);
      expect(opened.single.name, '행운 방향');
      expect(
        find.text('약속 장소를 고른다면 동쪽이 좋아요.', findRichText: true),
        findsNothing,
      );
      // 칩 줄 아래에는 판정 여유 말고 아무것도 이어지지 않습니다.
      final row = tester.getRect(find.byType(LuckyCardRow));
      final lastChip = tester.getRect(_surface(LuckyCardVariant.time));
      expect(row.bottom - lastChip.bottom, LuckyCardRow.hitInset);
    });

    testWidgets('열린 동안에만 누른 칩이 1.5 action.primary 테두리이고 닫히면 1px line으로 돌아옵니다', (
      tester,
    ) async {
      final sheet = Completer<void>();
      await tester.pumpWidget(_app(sheet: sheet));
      final tokens = tester.element(_chip(LuckyCardVariant.number)).tokens;
      final before = tester.getSize(_surface(LuckyCardVariant.number));

      await tester.tap(_chip(LuckyCardVariant.number));
      await tester.pump();
      final open = _borderOf(tester, LuckyCardVariant.number);
      expect(open.top.width, 1.5);
      expect(open.top.color, tokens.colors.actionPrimary);
      // 다른 칩은 그대로이고, 테두리가 바뀌어도 칩 크기는 그대로입니다.
      expect(_borderOf(tester, LuckyCardVariant.color).top.width, 1);
      expect(tester.getSize(_surface(LuckyCardVariant.number)), before);

      sheet.complete();
      await tester.pumpAndSettle();
      final closed = _borderOf(tester, LuckyCardVariant.number);
      expect(closed.top.width, 1);
      expect(closed.top.color, tokens.colors.line);
    });

    testWidgets('낮과 밤 시간 칩은 각자 설명을 열고 열림 테두리는 누른 칩에만 생깁니다(V116)', (
      tester,
    ) async {
      final sheet = Completer<void>();
      final opened = <LuckyItem>[];
      final nightExplain = _text('새벽 1시쯤 마음이 차분해요.');
      final items = [
        LuckyItem(
          variant: LuckyCardVariant.time,
          name: '낮의 길한 시간',
          value: '15:30~17:30',
          explain: _text('오후 3시쯤 집중이 잘 돼요.'),
          period: AppTimeOfDay.day,
        ),
        LuckyItem(
          variant: LuckyCardVariant.time,
          name: '밤의 길한 시간',
          value: '01:30~03:30',
          explain: nightExplain,
          period: AppTimeOfDay.night,
          word: '오늘 밤',
        ),
      ];
      await tester.pumpWidget(
        inputApp(
          Center(
            child: SizedBox(
              width: 360,
              child: LuckyCardRow(
                items: items,
                onOpen: (item) {
                  opened.add(item);
                  return sheet.future;
                },
              ),
            ),
          ),
        ),
      );
      final first = _chip(LuckyCardVariant.time);
      final second = find.byKey(
        LuckyCardRow.chipKey(LuckyCardVariant.time, period: AppTimeOfDay.night),
      );
      double widthOf(Finder chip) =>
          ((tester
                              .widget<Container>(
                                find.descendant(
                                  of: chip,
                                  matching: find.byKey(LuckyChip.surfaceKey),
                                ),
                              )
                              .foregroundDecoration!
                          as BoxDecoration)
                      .border!
                  as Border)
              .top
              .width;
      await tester.tap(second);
      await tester.pump();
      expect(opened.single.period, AppTimeOfDay.night);
      expect(opened.single.explain, same(nightExplain));
      expect(widthOf(second), 1.5);
      expect(widthOf(first), 1);
      sheet.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('먼저 연 칩의 시트가 늦게 끝나도 나중에 연 칩의 열림 테두리는 남습니다', (tester) async {
      final sheets = <Completer<void>>[];
      await tester.pumpWidget(
        inputApp(
          Center(
            child: SizedBox(
              width: 360,
              child: LuckyCardRow(
                items: _items(),
                onOpen: (_) {
                  final sheet = Completer<void>();
                  sheets.add(sheet);
                  return sheet.future;
                },
              ),
            ),
          ),
        ),
      );
      await tester.tap(_chip(LuckyCardVariant.color));
      await tester.pump();
      await tester.tap(_chip(LuckyCardVariant.number));
      await tester.pump();
      sheets.first.complete();
      await tester.pumpAndSettle();
      expect(_borderOf(tester, LuckyCardVariant.number).top.width, 1.5);
      expect(_borderOf(tester, LuckyCardVariant.color).top.width, 1);
      sheets.last.complete();
      await tester.pumpAndSettle();
      expect(_borderOf(tester, LuckyCardVariant.number).top.width, 1);
    });

    testWidgets('onOpen이 바로 끝나면 열림 테두리가 남지 않습니다', (tester) async {
      await tester.pumpWidget(_app(opened: <LuckyItem>[]));
      await tester.tap(_chip(LuckyCardVariant.color));
      await tester.pumpAndSettle();
      expect(_borderOf(tester, LuckyCardVariant.color).top.width, 1);
    });

    testWidgets('보이는 칩(34) 위아래 바깥 4px를 눌러도 열립니다(누름 영역 44)', (tester) async {
      final opened = <LuckyItem>[];
      await tester.pumpWidget(_app(opened: opened));
      for (final variant in _luckyVariants) {
        final rect = tester.getRect(_surface(variant));
        await tester.tapAt(Offset(rect.center.dx, rect.top - 4));
        await tester.pumpAndSettle();
        await tester.tapAt(Offset(rect.center.dx, rect.bottom + 4));
        await tester.pumpAndSettle();
      }
      expect(opened, hasLength(_luckyVariants.length * 2));
    });

    testWidgets('onOpen이 null이면 눌러도 열리지 않고 버튼으로 읽히지 않습니다', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(interactive: false));
      await tester.tap(_chip(LuckyCardVariant.direction));
      await tester.pumpAndSettle();
      expect(_borderOf(tester, LuckyCardVariant.direction).top.width, 1);
      final data = _data(tester, _chipNode(LuckyCardVariant.direction));
      expect(data.label, '행운 방향, 동');
      expect(data.flagsCollection.isButton, isFalse);
      expect(data.hasAction(SemanticsAction.tap), isFalse);
      handle.dispose();
    });

    group('time 낮과 밤 칩(V115, V116)', () {
      final day = LuckyItem(
        variant: LuckyCardVariant.time,
        name: '낮의 길한 시간',
        value: '15:30~17:30',
        explain: _text('오후 3시쯤 집중이 잘 돼요.'),
        period: AppTimeOfDay.day,
      );
      final night = LuckyItem(
        variant: LuckyCardVariant.time,
        name: '밤의 길한 시간',
        value: '01:30~03:30',
        explain: _text('새벽 1시쯤 마음이 차분해요.'),
        period: AppTimeOfDay.night,
        word: '새벽',
      );

      Widget row(Brightness brightness) => inputApp(
        Center(
          child: SizedBox(
            width: 360,
            child: LuckyCardRow(items: [day, night], onOpen: (_) {}),
          ),
        ),
        brightness: brightness,
      );

      Finder chipOf(AppTimeOfDay period) => find.byKey(
        LuckyCardRow.chipKey(LuckyCardVariant.time, period: period),
      );

      for (final brightness in Brightness.values) {
        testWidgets('앞 아이콘은 채운 해와 달이고 색은 color.time.* ($brightness)', (
          tester,
        ) async {
          await tester.pumpWidget(row(brightness));
          final colors = tester.element(chipOf(AppTimeOfDay.day)).tokens.colors;
          for (final (period, color) in [
            (AppTimeOfDay.day, colors.timeDay),
            (AppTimeOfDay.night, colors.timeNight),
          ]) {
            final icon = tester.widget<Icon>(
              find.descendant(of: chipOf(period), matching: find.byType(Icon)),
            );
            expect(icon.icon, period.glyph, reason: period.name);
            expect(icon.color, color, reason: period.name);
          }
        });
      }

      testWidgets('밤 칩은 때 낱말을 값 앞 space.4에 같은 글자로 두고 낮 칩에는 없습니다', (
        tester,
      ) async {
        await tester.pumpWidget(row(Brightness.light));
        final word = find.descendant(
          of: chipOf(AppTimeOfDay.night),
          matching: find.text('새벽'),
        );
        final value = find.text('01:30~03:30');
        expect(word, findsOneWidget);
        expect(
          tester.getTopLeft(value).dx - tester.getTopRight(word).dx,
          moreOrLessEquals(4),
        );
        expect(
          tester.widget<Text>(word).style!.fontSize,
          tester.widget<Text>(value).style!.fontSize,
        );
        expect(
          find.descendant(
            of: chipOf(AppTimeOfDay.day),
            matching: find.text('새벽'),
          ),
          findsNothing,
        );
      });

      testWidgets('스크린리더는 낮은 제목 + 값, 밤은 제목 + 때 낱말 + 값이고 아이콘은 읽지 않습니다', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(row(Brightness.light));
        String labelOf(AppTimeOfDay period) => _data(
          tester,
          find
              .descendant(of: chipOf(period), matching: find.byType(Semantics))
              .first,
        ).label;
        expect(labelOf(AppTimeOfDay.day), '낮의 길한 시간, 15:30~17:30');
        expect(labelOf(AppTimeOfDay.night), '밤의 길한 시간, 새벽 01:30~03:30');
        handle.dispose();
      });
    });

    group('색이 둘인 날 두 칸 알약(D119 ②, V114)', () {
      final pair = LuckyItem(
        variant: LuckyCardVariant.color,
        name: '행운 색',
        value: '검정',
        explain: _text('내 사주의 균형으로 보면 검정이 잘 맞아요.'),
        element: FiveElement.water,
        secondColor: LuckySecondColor(
          element: FiveElement.earth,
          value: '노랑',
          explain: _text('원전의 해석에 따르면 오늘은 노랑도 어울려요.'),
        ),
      );

      Widget row({
        List<LuckyItem>? opened,
        Completer<void>? sheet,
        bool interactive = true,
        double textScale = 1,
      }) => inputApp(
        MediaQuery.withClampedTextScaling(
          minScaleFactor: textScale,
          maxScaleFactor: textScale,
          child: Center(
            child: SizedBox(
              width: 360,
              child: LuckyCardRow(
                items: [pair, ..._items().skip(1)],
                onOpen: interactive
                    ? (item) {
                        opened?.add(item);
                        return sheet?.future;
                      }
                    : null,
              ),
            ),
          ),
        ),
      );

      Finder half(int index) => find.byKey(LuckyChip.pairHalfKey(index));

      testWidgets('칩 하나 안에 첫째, 둘째 순서로 두 칸과 세로선이 있고 이름표가 없습니다', (tester) async {
        await tester.pumpWidget(row());
        final chip = _chip(LuckyCardVariant.color);
        expect(
          find.descendant(of: chip, matching: find.byKey(LuckyChip.surfaceKey)),
          findsOneWidget,
        );
        expect(
          find.descendant(of: half(0), matching: find.text('검정')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: half(1), matching: find.text('노랑')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: chip, matching: find.byKey(LuckyChip.swatchKey)),
          findsNWidgets(2),
        );
        final divider = find.byKey(LuckyChip.pairDividerKey);
        expect(divider, findsOneWidget);
        final first = tester.getRect(half(0));
        final second = tester.getRect(half(1));
        final line = tester.getRect(divider);
        expect(first.right, lessThanOrEqualTo(line.left));
        expect(line.right, lessThanOrEqualTo(second.left));
        // 칩 안 글자는 두 색 이름뿐입니다(기준 이름표 없음, `pair.basisLabel` false).
        expect(
          find.descendant(of: chip, matching: find.byType(Text)),
          findsNWidgets(2),
        );
        // 칩 줄 개수는 색이 하나인 날과 같습니다.
        expect(find.byKey(LuckyChip.surfaceKey), findsNWidgets(4));
      });

      testWidgets('세로선은 1 x 18 color.line이고 칸 안은 좌우 12, 견본과 이름 사이 4입니다', (
        tester,
      ) async {
        await tester.pumpWidget(row());
        final tokens = tester.element(half(0)).tokens;
        final divider = find.byKey(LuckyChip.pairDividerKey);
        expect(tester.getSize(divider), const Size(1, 18));
        expect(tester.widget<Container>(divider).color, tokens.colors.line);
        for (final (index, name) in [(0, '검정'), (1, '노랑')]) {
          final rect = tester.getRect(half(index));
          final swatch = tester.getRect(
            find.descendant(
              of: half(index),
              matching: find.byKey(LuckyChip.swatchKey),
            ),
          );
          final text = tester.getRect(
            find.descendant(of: half(index), matching: find.text(name)),
          );
          expect(swatch.left - rect.left, 12, reason: name);
          expect(rect.right - text.right, 12, reason: name);
          expect(text.left - swatch.right, 4, reason: name);
        }
      });

      testWidgets('칸마다 누름 자리는 폭과 높이 모두 44 이상입니다', (tester) async {
        final opened = <LuckyItem>[];
        await tester.pumpWidget(row(opened: opened));
        for (final index in [0, 1]) {
          final rect = tester.getRect(half(index));
          expect(rect.width, greaterThanOrEqualTo(44));
          // 보이는 칸(34) 위아래 바깥 4px도 그 칸이 받습니다.
          await tester.tapAt(Offset(rect.center.dx, rect.top - 4));
          await tester.pumpAndSettle();
          await tester.tapAt(Offset(rect.center.dx, rect.bottom + 4));
          await tester.pumpAndSettle();
        }
        expect(opened, hasLength(4));
      });

      testWidgets('어느 칸을 눌러도 같은 색 항목을 열고 열림 테두리는 알약 전체입니다', (tester) async {
        final opened = <LuckyItem>[];
        final sheet = Completer<void>();
        await tester.pumpWidget(row(opened: opened, sheet: sheet));
        final tokens = tester.element(half(0)).tokens;

        await tester.tap(half(1));
        await tester.pump();
        expect(opened.single, same(pair));
        final open = _borderOf(tester, LuckyCardVariant.color);
        expect(open.top.width, 1.5);
        expect(open.top.color, tokens.colors.actionPrimary);
        // 테두리는 두 칸을 감싼 알약 하나에 그립니다.
        final surface = tester.getRect(_surface(LuckyCardVariant.color));
        expect(surface.left, lessThanOrEqualTo(tester.getRect(half(0)).left));
        expect(
          surface.right,
          greaterThanOrEqualTo(tester.getRect(half(1)).right),
        );
        sheet.complete();
        await tester.pumpAndSettle();
        expect(_borderOf(tester, LuckyCardVariant.color).top.width, 1);

        await tester.tap(half(0));
        await tester.pumpAndSettle();
        expect(opened, [pair, pair]);
      });

      testWidgets('스크린리더는 칸마다 버튼이고 라벨은 항목 이름 + 그 칸의 값입니다', (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(row());
        for (final (index, value) in [(0, '검정'), (1, '노랑')]) {
          final data = _data(tester, half(index));
          // "두 개 중 몇째"는 원고 문구가 없어 아직 붙이지 않습니다(A135, writing 몫).
          expect(data.label, '행운 색, $value');
          expect(data.flagsCollection.isButton, isTrue);
          expect(data.hasAction(SemanticsAction.tap), isTrue);
        }
        handle.dispose();
      });

      testWidgets('표시 전용이면 칸이 버튼으로 읽히지 않습니다', (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(row(interactive: false));
        final data = _data(tester, half(1));
        expect(data.label, '행운 색, 노랑');
        expect(data.flagsCollection.isButton, isFalse);
        handle.dispose();
      });

      testWidgets('글자 배율 2.0에서도 넘치지 않고 칸은 34 아래로 줄지 않습니다', (tester) async {
        await tester.pumpWidget(row(textScale: 2));
        expect(tester.takeException(), isNull);
        expect(tester.getSize(half(0)).height, greaterThanOrEqualTo(34));
      });

      test('withoutSecondColor는 둘째 색만 빼고 나머지는 같습니다', () {
        final first = pair.withoutSecondColor;
        expect(first.secondColor, isNull);
        expect(first.value, '검정');
        expect(first.element, FiveElement.water);
        expect(first.explain, same(pair.explain));
        final single = _items().first;
        expect(single.withoutSecondColor, same(single));
      });
    });

    group('접근성과 인터랙션', () {
      testWidgets('칩은 button이고 라벨은 항목 이름 + 값입니다', (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(_app());
        final data = _data(tester, _chipNode(LuckyCardVariant.color));
        expect(data.label, '행운 색, 파랑');
        expect(data.flagsCollection.isButton, isTrue);
        expect(data.hasAction(SemanticsAction.tap), isTrue);
        handle.dispose();
      });

      testWidgets('햅틱을 내지 않습니다(명세 haptic 비어 있음)', (tester) async {
        final calls = recordHaptics(tester);
        await tester.pumpWidget(_app(opened: <LuckyItem>[]));
        await tester.tap(_chip(LuckyCardVariant.color));
        await tester.pumpAndSettle();
        expect(calls, isEmpty);
      });

      testWidgets('누르는 동안 press.ink 얼룩 층이 있습니다', (tester) async {
        await tester.pumpWidget(_app());
        final gesture = await tester.startGesture(
          tester.getCenter(_chip(LuckyCardVariant.number)),
        );
        await tester.pump(const Duration(milliseconds: 100));
        expect(inkLayer(_chip(LuckyCardVariant.number)), findsOneWidget);
        await gesture.up();
        await tester.pumpAndSettle();
      });
    });

    test('LuckyItem: color는 element가 필수이고 다른 변형은 줄 수 없습니다', () {
      expect(
        () => LuckyItem(
          variant: LuckyCardVariant.color,
          name: '행운 색',
          value: '파랑',
          explain: _text('설명'),
        ),
        throwsAssertionError,
      );
      expect(
        () => LuckyItem(
          variant: LuckyCardVariant.number,
          name: '행운 숫자',
          value: '3',
          explain: _text('설명'),
          element: FiveElement.water,
        ),
        throwsAssertionError,
      );
    });

    test('tag 변형은 5.0.0에서 지워져 변형은 행운 4종뿐입니다(V78)', () {
      expect(LuckyCardVariant.values, LuckyCardVariant.luckyValues);
      expect(LuckyCardVariant.values.map((v) => v.name), [
        'color',
        'direction',
        'number',
        'time',
      ]);
    });

    testWidgets('LuckyChip 하나만 따로 그릴 수 있습니다', (tester) async {
      await tester.pumpWidget(
        inputApp(
          Center(child: LuckyChip(item: _items()[1], open: false, onTap: null)),
        ),
      );
      expect(find.text('동'), findsOneWidget);
      expect(find.byType(Icon), findsOneWidget);
    });

    test(
      'ComponentSpec은 변형 4개(tag 삭제)와 loading, pressed, open, closed를 가집니다',
      () {
        expect(LuckyCardRow.spec.id, 'lucky-card');
        expect(LuckyCardRow.spec.variants, {
          'color',
          'direction',
          'number',
          'time',
        });
        expect(LuckyCardRow.spec.states, {
          'loading',
          'pressed',
          'open',
          'closed',
        });
      },
    );
  });
}
