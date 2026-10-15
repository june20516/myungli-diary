import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/gen/model/rendered_text.dart';
import 'package:myungli_diary/core/api/gen/model/segment.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/design/components/feedback/live_announcement.dart';
import 'package:myungli_diary/design/components/today/lucky_card.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';

import '../input/input_harness.dart';

RenderedText _text(String value) =>
    RenderedText(segments: [Segment(text: value)]);

const Map<LuckyCardVariant, String> _slotIds = {
  LuckyCardVariant.color: SlotIds.todayLuckyColorBody,
  LuckyCardVariant.direction: SlotIds.todayLuckyDirectionBody,
  LuckyCardVariant.number: SlotIds.todayLuckyNumberBody,
  LuckyCardVariant.time: SlotIds.todayLuckyTimeBody,
};

List<LuckyItem> _items() => [
  LuckyItem(
    variant: LuckyCardVariant.color,
    name: '행운 색',
    value: '파랑',
    explain: _text('물의 기운이 마음을 가라앉혀요.'),
    swatch: const Color(0xFF3B6FB6),
  ),
  LuckyItem(
    variant: LuckyCardVariant.direction,
    name: '행운 방향',
    value: '동쪽',
    explain: _text('동쪽에서 좋은 기운이 들어와요.'),
  ),
  LuckyItem(
    variant: LuckyCardVariant.number,
    name: '행운 숫자',
    value: '3',
    explain: _text('3이 흐름을 열어 줘요.'),
  ),
  LuckyItem(
    variant: LuckyCardVariant.time,
    name: '집중 시간',
    value: '오후 3시',
    explain: _text('오후 3시에 집중이 잘 돼요.'),
  ),
];

Widget _app({
  bool interactive = true,
  Map<LuckyCardVariant, String> slotIds = _slotIds,
  Brightness brightness = Brightness.light,
  Widget Function(Widget child)? wrap,
}) {
  final row = LuckyCardRow(
    items: _items(),
    interactive: interactive,
    slotIds: slotIds,
  );
  return inputApp(
    Center(child: SizedBox(width: 360, child: wrap?.call(row) ?? row)),
    brightness: brightness,
  );
}

Finder _chip(LuckyCardVariant variant) =>
    find.byKey(LuckyCardRow.chipKey(variant));

/// 칩의 시맨틱 노드를 가진 위젯(눌림 자리, 표시 전용이면 라벨 노드).
Finder _chipNode(LuckyCardVariant variant) =>
    find.descendant(of: _chip(variant), matching: find.byType(Semantics)).first;

Finder _explain(LuckyCardVariant variant) =>
    find.byKey(ValueKey<String>(_slotIds[variant]!));

SemanticsData _data(WidgetTester tester, Finder finder) =>
    tester.getSemantics(finder).getSemanticsData();

Future<void> _tap(WidgetTester tester, LuckyCardVariant variant) async {
  await tester.tap(_chip(variant));
  await tester.pumpAndSettle();
}

void main() {
  group('lucky-card', () {
    testWidgets('처음에는 설명이 모두 닫혀 있습니다', (tester) async {
      await tester.pumpWidget(_app());
      for (final variant in LuckyCardVariant.values) {
        expect(_explain(variant), findsNothing, reason: variant.name);
      }
    });

    testWidgets('칩을 누르면 설명이 열리고 같은 칩을 다시 누르면 닫힙니다', (tester) async {
      await tester.pumpWidget(_app());
      await _tap(tester, LuckyCardVariant.direction);
      expect(
        find.text('동쪽에서 좋은 기운이 들어와요.', findRichText: true),
        findsOneWidget,
      );
      expect(_explain(LuckyCardVariant.direction), findsOneWidget);

      await _tap(tester, LuckyCardVariant.direction);
      expect(find.text('동쪽에서 좋은 기운이 들어와요.', findRichText: true), findsNothing);
      expect(_explain(LuckyCardVariant.direction), findsNothing);
    });

    testWidgets('다른 칩을 누르면 설명이 바뀌고 한 번에 하나만 열립니다', (tester) async {
      await tester.pumpWidget(_app());
      await _tap(tester, LuckyCardVariant.color);
      await _tap(tester, LuckyCardVariant.time);
      expect(find.text('물의 기운이 마음을 가라앉혀요.', findRichText: true), findsNothing);
      expect(find.text('오후 3시에 집중이 잘 돼요.', findRichText: true), findsOneWidget);
      expect(_explain(LuckyCardVariant.color), findsNothing);
      expect(_explain(LuckyCardVariant.time), findsOneWidget);
      expect(find.byKey(LuckyCardRow.explainKey), findsOneWidget);
    });

    testWidgets('설명 상자는 슬롯 id를 Key와 identifier로 답니다', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app());
      await _tap(tester, LuckyCardVariant.number);
      expect(_explain(LuckyCardVariant.number), findsOneWidget);
      expect(
        _data(tester, _explain(LuckyCardVariant.number)).identifier,
        SlotIds.todayLuckyNumberBody,
      );
      handle.dispose();
    });

    testWidgets('슬롯 id가 없으면 설명 상자에 identifier를 달지 않습니다', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(slotIds: const {}));
      await _tap(tester, LuckyCardVariant.number);
      final data = _data(
        tester,
        find.ancestor(
          of: find.byKey(LuckyCardRow.explainKey),
          matching: find.byType(LiveAnnouncement),
        ),
      );
      expect(data.label, '3이 흐름을 열어 줘요.', reason: '설명 노드를 읽었는지 확인');
      expect(data.identifier, isEmpty);
      handle.dispose();
    });

    testWidgets('칩은 높이 34 이상이고 누름 영역은 44 이상입니다', (tester) async {
      await tester.pumpWidget(_app());
      for (final variant in LuckyCardVariant.values) {
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

    testWidgets('보이는 칩(34) 위쪽 바깥을 눌러도 열립니다(누름 영역 44)', (tester) async {
      // 둘째 줄 칩의 위쪽 틈. 첫 줄 칩의 넓힌 영역(아래 5)과 겹치지 않는 자리(위 2)를 누릅니다.
      await tester.pumpWidget(
        inputApp(
          Center(
            child: SizedBox(
              width: 200,
              child: LuckyCardRow(items: _items(), slotIds: _slotIds),
            ),
          ),
        ),
      );
      final chip = find.descendant(
        of: _chip(LuckyCardVariant.time),
        matching: find.byKey(LuckyChip.surfaceKey),
      );
      final rect = tester.getRect(chip);
      await tester.tapAt(Offset(rect.center.dx, rect.top - 2));
      await tester.pumpAndSettle();
      expect(_explain(LuckyCardVariant.time), findsOneWidget);
    });

    Future<void> pumpRow(WidgetTester tester, double width) =>
        tester.pumpWidget(
          inputApp(
            Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 40),
                child: SizedBox(
                  width: width,
                  child: LuckyCardRow(items: _items(), slotIds: _slotIds),
                ),
              ),
            ),
          ),
        );

    Rect surfaceOf(WidgetTester tester, LuckyCardVariant variant) =>
        tester.getRect(
          find.descendant(
            of: _chip(variant),
            matching: find.byKey(LuckyChip.surfaceKey),
          ),
        );

    testWidgets('한 줄이어도 모든 칩의 위·아래 바깥 4px를 눌러 열립니다', (tester) async {
      await pumpRow(tester, 360);
      for (final variant in LuckyCardVariant.values) {
        for (final above in [true, false]) {
          final rect = surfaceOf(tester, variant);
          expect(
            surfaceOf(tester, LuckyCardVariant.color).top,
            rect.top,
            reason: '한 줄',
          );
          await tester.tapAt(
            Offset(rect.center.dx, above ? rect.top - 4 : rect.bottom + 4),
          );
          await tester.pumpAndSettle();
          expect(
            _explain(variant),
            findsOneWidget,
            reason: '${variant.name} ${above ? '위' : '아래'}',
          );
          await tester.tapAt(rect.center);
          await tester.pumpAndSettle();
          expect(_explain(variant), findsNothing);
        }
      }
    });

    testWidgets('여러 줄이면 첫 줄 위·마지막 줄 아래 바깥 4px도 눌립니다', (tester) async {
      await pumpRow(tester, 200);
      final first = surfaceOf(tester, LuckyCardVariant.color);
      final last = surfaceOf(tester, LuckyCardVariant.time);
      expect(last.top, greaterThan(first.top), reason: '두 줄 이상');

      await tester.tapAt(Offset(first.center.dx, first.top - 4));
      await tester.pumpAndSettle();
      expect(_explain(LuckyCardVariant.color), findsOneWidget);

      await tester.tapAt(Offset(last.center.dx, last.bottom + 4));
      await tester.pumpAndSettle();
      expect(_explain(LuckyCardVariant.time), findsOneWidget);
    });

    testWidgets('판정 여유는 보이는 간격을 바꾸지 않습니다(설명 상자 위 8)', (tester) async {
      await pumpRow(tester, 360);
      await _tap(tester, LuckyCardVariant.color);
      final chip = surfaceOf(tester, LuckyCardVariant.color);
      final box = tester.getRect(find.byKey(LuckyCardRow.explainKey));
      expect(box.top - chip.bottom, 8);
    });

    testWidgets('다른 칩으로 바꾸면 바뀐 설명이 appear.seep으로 다시 나타납니다', (tester) async {
      await tester.pumpWidget(_app());
      await _tap(tester, LuckyCardVariant.color);
      await tester.tap(_chip(LuckyCardVariant.time));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      final opacity = tester.widget<Opacity>(
        find
            .ancestor(
              of: find.byKey(LuckyCardRow.explainKey),
              matching: find.byType(Opacity),
            )
            .first,
      );
      expect(opacity.opacity, inExclusiveRange(0, 1));
      await tester.pumpAndSettle();
      expect(find.text('오후 3시에 집중이 잘 돼요.', findRichText: true), findsOneWidget);
      // 바뀐 뒤에도 닫으면 사라집니다.
      await _tap(tester, LuckyCardVariant.time);
      expect(find.byKey(LuckyCardRow.explainKey), findsNothing);
    });

    testWidgets('동작 줄이기에서도 바뀐 설명이 투명도로만 다시 나타납니다', (tester) async {
      await tester.pumpWidget(
        _app(
          wrap: (child) => MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: child,
          ),
        ),
      );
      await _tap(tester, LuckyCardVariant.color);
      await tester.tap(_chip(LuckyCardVariant.time));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        find.descendant(
          of: find.byKey(LuckyCardRow.explainKey),
          matching: find.byType(ImageFiltered),
        ),
        findsNothing,
      );
      await tester.pumpAndSettle();
      expect(_explain(LuckyCardVariant.time), findsOneWidget);
    });

    test('LuckyItem: color는 swatch가 필수이고 다른 변형은 줄 수 없습니다', () {
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
          swatch: const Color(0xFF3B6FB6),
        ),
        throwsAssertionError,
      );
    });

    testWidgets('칩 모양: 알약 반지름·chip.bg·값 글자', (tester) async {
      await tester.pumpWidget(_app());
      final surface = find.descendant(
        of: _chip(LuckyCardVariant.direction),
        matching: find.byKey(LuckyChip.surfaceKey),
      );
      final decoration =
          tester.widget<Container>(surface).decoration! as BoxDecoration;
      final tokens = tester.element(surface).tokens;
      expect(decoration.color, tokens.colors.chipBg);
      expect(
        decoration.borderRadius,
        const BorderRadius.all(Radius.circular(9999)),
      );
      final value = tester.widget<Text>(
        find.descendant(of: surface, matching: find.text('동쪽')),
      );
      expect(value.style?.fontSize, tokens.typography.labelMd.fontSize);
      expect(value.style?.color, tokens.colors.textPrimary);
    });

    testWidgets('아이콘은 16이고 text.secondary, 색 변형은 14 견본 원입니다', (tester) async {
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
        expect(icon.color, tokens.colors.textSecondary, reason: variant.name);
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
          tester.widget<Container>(swatch).decoration! as BoxDecoration;
      expect(decoration.color, const Color(0xFF3B6FB6));
      expect(decoration.shape, BoxShape.circle);
      expect(
        (decoration.border! as Border).top.color,
        tokens.colors.swatchBorder,
      );
      expect((decoration.border! as Border).top.width, 1);
    });

    testWidgets('칩 높이 34 안쪽 여백 12·아이콘과 값 사이 6', (tester) async {
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
          matching: find.text('동쪽'),
        ),
      );
      expect(icon.left - chip.left, 12);
      expect(value.left - icon.right, 6);
      expect(chip.right - value.right, 12);
      expect(chip.height, 34);
    });

    testWidgets('열린 칩만 1.5 action.primary 안쪽 테두리를 갖습니다', (tester) async {
      await tester.pumpWidget(_app());
      Border? borderOf(LuckyCardVariant variant) {
        final surface = find.descendant(
          of: _chip(variant),
          matching: find.byKey(LuckyChip.surfaceKey),
        );
        final box = tester.widget<Container>(surface);
        return (box.foregroundDecoration as BoxDecoration?)?.border as Border?;
      }

      await _tap(tester, LuckyCardVariant.number);
      final tokens = tester.element(_chip(LuckyCardVariant.number)).tokens;
      final open = borderOf(LuckyCardVariant.number)!;
      expect(open.top.width, 1.5);
      expect(open.top.color, tokens.colors.actionPrimary);
      expect(borderOf(LuckyCardVariant.color), isNull);

      await _tap(tester, LuckyCardVariant.number);
      expect(borderOf(LuckyCardVariant.number), isNull);
    });

    testWidgets('설명 상자: chip.bg·radius.md·안쪽 12·caption.lg·text.secondary', (
      tester,
    ) async {
      await tester.pumpWidget(_app());
      await _tap(tester, LuckyCardVariant.color);
      final box = find.byKey(LuckyCardRow.explainKey);
      final tokens = tester.element(box).tokens;
      final decoration =
          tester.widget<Container>(box).decoration! as BoxDecoration;
      expect(decoration.color, tokens.colors.chipBg);
      expect(decoration.borderRadius, BorderRadius.circular(12));
      final rect = tester.getRect(box);
      final text = tester.getRect(
        find.descendant(of: box, matching: find.byType(RichText)).first,
      );
      expect(text.left - rect.left, 12);
      expect(text.top - rect.top, 12);
      final chips = tester.getRect(
        find.descendant(
          of: _chip(LuckyCardVariant.color),
          matching: find.byKey(LuckyChip.surfaceKey),
        ),
      );
      expect(rect.top - chips.bottom, 8);
      expect(rect.width, 360);
      final style = tester
          .widget<Text>(find.descendant(of: box, matching: find.byType(Text)))
          .textSpan!
          .style;
      expect(style?.color, tokens.colors.textSecondary);
      expect(style?.fontSize, tokens.typography.captionLg.fontSize);
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
        for (final variant in LuckyCardVariant.values)
          tester.getTopLeft(_chip(variant)).dy,
      };
      expect(tops.length, greaterThan(1));
    });

    group('접근성', () {
      testWidgets('칩은 button이고 라벨은 항목 이름 + 값입니다', (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(_app());
        final data = _data(tester, _chipNode(LuckyCardVariant.color));
        expect(data.label, '행운 색, 파랑');
        expect(data.flagsCollection.isButton, isTrue);
        expect(data.hasAction(SemanticsAction.tap), isTrue);
        handle.dispose();
      });

      testWidgets('열림·닫힘 상태가 expanded로 읽힙니다', (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(_app());
        Tristate expanded(LuckyCardVariant v) =>
            _data(tester, _chipNode(v)).flagsCollection.isExpanded;

        expect(expanded(LuckyCardVariant.time), Tristate.isFalse);
        await _tap(tester, LuckyCardVariant.time);
        expect(expanded(LuckyCardVariant.time), Tristate.isTrue);
        expect(expanded(LuckyCardVariant.color), Tristate.isFalse);
        await _tap(tester, LuckyCardVariant.color);
        expect(expanded(LuckyCardVariant.time), Tristate.isFalse);
        expect(expanded(LuckyCardVariant.color), Tristate.isTrue);
        handle.dispose();
      });

      testWidgets('설명이 열리면 liveRegion으로 설명 글자가 알려집니다', (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(_app());
        await _tap(tester, LuckyCardVariant.direction);
        final data = _data(tester, _explain(LuckyCardVariant.direction));
        expect(data.label, '동쪽에서 좋은 기운이 들어와요.');
        expect(data.flagsCollection.isLiveRegion, isTrue);
        handle.dispose();
      });

      testWidgets('interactive: false면 눌러도 열리지 않고 button이 아닙니다', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(_app(interactive: false));
        await tester.tap(_chip(LuckyCardVariant.direction));
        await tester.pumpAndSettle();
        expect(_explain(LuckyCardVariant.direction), findsNothing);
        expect(find.byKey(LuckyCardRow.explainKey), findsNothing);
        final data = _data(tester, _chipNode(LuckyCardVariant.direction));
        expect(data.label, '행운 방향, 동쪽');
        expect(data.flagsCollection.isButton, isFalse);
        expect(data.hasAction(SemanticsAction.tap), isFalse);
        handle.dispose();
      });
    });

    group('인터랙션', () {
      testWidgets('햅틱을 내지 않습니다(명세 haptic 비어 있음)', (tester) async {
        final calls = recordHaptics(tester);
        await tester.pumpWidget(_app());
        await _tap(tester, LuckyCardVariant.color);
        await _tap(tester, LuckyCardVariant.time);
        await _tap(tester, LuckyCardVariant.time);
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

      testWidgets('설명은 appear.seep로 나타나고 disappear.seep 뒤에 사라집니다', (
        tester,
      ) async {
        await tester.pumpWidget(_app());
        await tester.tap(_chip(LuckyCardVariant.color));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        final opacity = tester.widget<Opacity>(
          find
              .ancestor(
                of: find.byKey(LuckyCardRow.explainKey),
                matching: find.byType(Opacity),
              )
              .first,
        );
        expect(opacity.opacity, inExclusiveRange(0, 1));

        await tester.pumpAndSettle();
        await tester.tap(_chip(LuckyCardVariant.color));
        await tester.pump(const Duration(milliseconds: 20));
        expect(find.byKey(LuckyCardRow.explainKey), findsOneWidget);
        await tester.pumpAndSettle();
        expect(find.byKey(LuckyCardRow.explainKey), findsNothing);
      });

      testWidgets('동작 줄이기에서도 열리고 닫힙니다(투명도만)', (tester) async {
        await tester.pumpWidget(
          _app(
            wrap: (child) => MediaQuery(
              data: const MediaQueryData(disableAnimations: true),
              child: child,
            ),
          ),
        );
        await _tap(tester, LuckyCardVariant.color);
        expect(find.byKey(LuckyCardRow.explainKey), findsOneWidget);
        await _tap(tester, LuckyCardVariant.color);
        expect(find.byKey(LuckyCardRow.explainKey), findsNothing);
      });
    });

    testWidgets('칩 줄에서 items가 바뀌어 열린 항목이 사라지면 설명을 닫습니다', (tester) async {
      await tester.pumpWidget(_app());
      await _tap(tester, LuckyCardVariant.time);
      await tester.pumpWidget(
        inputApp(
          Center(
            child: SizedBox(
              width: 360,
              child: LuckyCardRow(items: _items().sublist(0, 2)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(LuckyCardRow.explainKey), findsNothing);
    });

    testWidgets('LuckyChip 하나만 따로 그릴 수 있습니다', (tester) async {
      await tester.pumpWidget(
        inputApp(
          Center(child: LuckyChip(item: _items()[1], open: false, onTap: null)),
        ),
      );
      expect(find.text('동쪽'), findsOneWidget);
      expect(find.byType(Icon), findsOneWidget);
    });

    test('ComponentSpec은 변형 4개를 가집니다', () {
      expect(LuckyCardRow.spec.id, 'lucky-card');
      expect(LuckyCardRow.spec.variants, {
        'color',
        'direction',
        'number',
        'time',
      });
      expect(LuckyCardRow.spec.states, {'pressed', 'open', 'closed'});
    });
  });
}
