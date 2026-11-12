import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/design/components/feedback/skeleton.dart';
import 'package:myungli_diary/design/components/sentence/hanja_tag.dart';
import 'package:myungli_diary/design/components/sentence/vertical_hit_slop.dart';
import 'package:myungli_diary/design/components/today/date_header.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

import '../input/input_harness.dart';

const _solar = '10월 13일 화요일';
const _lunar = '음력 8월 24일';
const _iljin = '癸未(계미)일';

Widget _app({
  String? lunar,
  String? iljin,
  List<DateHeaderVirtue> virtues = const [],
  double width = 360,
}) => inputApp(
  Align(
    alignment: Alignment.topLeft,
    child: Padding(
      // 위아래 넓힌 눌림을 재도록 화면 끝에서 떨어뜨립니다.
      padding: const EdgeInsets.symmetric(vertical: 40),
      // 오늘 화면처럼 감싼 상자도 덕일 알약의 아래 넓힘을 막지 않게 둡니다.
      child: HitSlopPassage(
        bottom: virtues.isEmpty ? 0 : DateHeader.virtueHitSlop,
        child: SizedBox(
          width: width,
          child: DateHeader(
            solar: _solar,
            lunar: lunar,
            iljin: iljin,
            virtues: virtues,
          ),
        ),
      ),
    ),
  ),
);

/// 덕일 알약 값. [onTap]을 주면 누를 수 있습니다.
DateHeaderVirtue _virtue(String label, {VoidCallback? onTap}) =>
    DateHeaderVirtue(glyph: '德', label: label, onTap: onTap);

void main() {
  group('date-header', () {
    testWidgets('날짜, 음력, 일진을 모두 주면 세 글자 모두 보입니다', (tester) async {
      await tester.pumpWidget(_app(lunar: _lunar, iljin: _iljin));
      expect(find.text(_solar), findsOneWidget);
      expect(find.text(_lunar), findsOneWidget);
      expect(find.byKey(DateHeader.iljinKey), findsOneWidget);
      expect(find.byKey(DateHeader.metaKey), findsOneWidget);
    });

    testWidgets('음력이 없으면 일진만 남고 줄 위치는 같습니다(선택 필드 없음)', (tester) async {
      await tester.pumpWidget(_app(lunar: _lunar, iljin: _iljin));
      final full = tester.getTopLeft(find.byKey(DateHeader.iljinKey)).dy;
      await tester.pumpWidget(_app(iljin: _iljin));
      expect(find.text(_lunar), findsNothing);
      expect(find.byKey(DateHeader.iljinKey), findsOneWidget);
      expect(tester.getTopLeft(find.byKey(DateHeader.iljinKey)).dy, full);
      // 음력 칸이 빠지면 일진이 줄 맨 앞으로 옵니다.
      expect(tester.getTopLeft(find.byKey(DateHeader.iljinKey)).dx, 0);
    });

    testWidgets('일진이 없으면(그날 시트) 음력만 남습니다', (tester) async {
      await tester.pumpWidget(_app(lunar: _lunar));
      expect(find.text(_lunar), findsOneWidget);
      expect(find.byKey(DateHeader.iljinKey), findsNothing);
    });

    testWidgets('음력과 일진이 모두 없으면 날짜만 그리고 줄과 위 여백도 없습니다', (tester) async {
      await tester.pumpWidget(_app());
      expect(find.byKey(DateHeader.metaKey), findsNothing);
      final header = tester.getRect(find.byType(DateHeader));
      final solar = tester.getRect(find.text(_solar));
      expect(header.height, solar.height);
    });

    testWidgets(
      '날짜는 type.subtitle text.primary, 아래 줄은 caption.lg text.secondary이고 '
      '사이는 space.2입니다',
      (tester) async {
        await tester.pumpWidget(_app(lunar: _lunar, iljin: _iljin));
        final tokens = tester.element(find.byType(DateHeader)).tokens;
        final solar = tester.widget<Text>(find.text(_solar));
        expect(solar.style?.fontSize, tokens.typography.subtitle.fontSize);
        expect(solar.style?.color, tokens.colors.textPrimary);
        final lunar = tester.widget<Text>(find.text(_lunar));
        expect(lunar.style?.fontSize, tokens.typography.captionLg.fontSize);
        expect(lunar.style?.color, tokens.colors.textSecondary);
        final gap =
            tester.getTopLeft(find.text(_lunar)).dy -
            tester.getBottomLeft(find.text(_solar)).dy;
        expect(gap, DateHeader.metaGap);
      },
    );

    testWidgets('음력과 일진 사이는 space.8 간격뿐이고 기호로 잇지 않습니다', (tester) async {
      await tester.pumpWidget(_app(lunar: _lunar, iljin: _iljin));
      final gap =
          tester.getTopLeft(find.byKey(DateHeader.iljinKey)).dx -
          tester.getTopRight(find.text(_lunar)).dx;
      expect(gap, 8);
    });

    testWidgets('두 칸이 한 줄에 못 들어가면 칸 단위로 다음 줄로 넘어갑니다', (tester) async {
      await tester.pumpWidget(_app(lunar: _lunar, iljin: _iljin, width: 120));
      final lunarBox = tester.getRect(find.text(_lunar));
      final iljinBox = tester.getRect(find.byKey(DateHeader.iljinKey));
      expect(iljinBox.top, greaterThanOrEqualTo(lunarBox.bottom));
      expect(tester.takeException(), isNull);
    });

    testWidgets('일진의 한자만 hanja 글꼴이고 한글은 UI 글꼴 그대로입니다', (tester) async {
      await tester.pumpWidget(_app(iljin: _iljin));
      final tokens = tester.element(find.byType(DateHeader)).tokens;
      final root = tester
          .widget<Text>(find.byKey(DateHeader.iljinKey))
          .textSpan!;
      final spans = (root as TextSpan).children!.cast<TextSpan>();
      expect(spans.map((s) => s.text), ['癸未', '(계미)일']);
      expect(
        spans[0].style?.fontFamily,
        tokens.typography.hanjaPillar.fontFamily,
      );
      expect(spans[1].style, isNull);
    });

    test('스크린리더 일진은 한글 독음만 남깁니다', () {
      expect(DateHeader.spokenIljinOf('癸未(계미)일'), '계미일');
      expect(DateHeader.spokenIljinOf('庚申(경신)日'), '경신');
      expect(DateHeader.spokenIljinOf('경신일'), '경신일');
    });

    testWidgets('한 덩어리 header로 읽히고 일진은 독음만 읽습니다', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(lunar: _lunar, iljin: _iljin));
      final data = tester
          .getSemantics(find.byType(DateHeader))
          .getSemanticsData();
      expect(data.label, '$_solar, $_lunar, 계미일');
      expect(data.flagsCollection.isHeader, isTrue);
      expect(data.label, isNot(contains('癸')));
      handle.dispose();
    });

    testWidgets('누를 수 없는 표시입니다(탭 동작과 button이 없음)', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(lunar: _lunar, iljin: _iljin));
      final data = tester
          .getSemantics(find.byType(DateHeader))
          .getSemanticsData();
      expect(data.hasAction(SemanticsAction.tap), isFalse);
      expect(data.flagsCollection.isButton, isFalse);
      handle.dispose();
    });

    testWidgets('글자 배율 2.0과 폭 좁은 칸에서도 넘치지 않습니다', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(_app(lunar: _lunar, iljin: _iljin, width: 200));
      expect(tester.takeException(), isNull);
    });

    testWidgets('loading: 날짜 줄은 바로 그리고 음력, 일진 줄만 한 줄 뼈(50%)입니다', (
      tester,
    ) async {
      await tester.pumpWidget(
        inputApp(
          SizedBox(
            width: 300,
            child: DateHeader.skeleton(solar: _solar, animated: false),
          ),
        ),
      );
      expect(find.text(_solar), findsOneWidget);
      final lines = tester.widget<SkeletonTextLines>(
        find.byType(SkeletonTextLines),
      );
      expect(lines.lines, 1);
      expect(lines.widthFactor, DateHeader.skeletonWidthFactor);
      expect(DateHeader.skeletonWidthFactor, 0.5);
    });

    group('day-sheet trailing (V109)', () {
      const trailingKey = ValueKey('trailing');
      const trailing = SizedBox(key: trailingKey, width: 96, height: 30);

      Widget app({String? lunar = _lunar, double width = 360}) => inputApp(
        Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            child: DateHeader(solar: _solar, lunar: lunar, trailing: trailing),
          ),
        ),
      );

      testWidgets('오른쪽 끝, 날짜와 음력 두 줄 묶음의 세로 가운데입니다', (tester) async {
        await tester.pumpWidget(app());
        final dates = tester.getRect(find.byKey(DateHeader.datesKey));
        final tag = tester.getRect(find.byKey(trailingKey));
        expect(tag.right, 360);
        expect(tag.center.dy, closeTo(dates.center.dy, 0.01));
        expect(
          dates.bottom,
          greaterThan(tester.getRect(find.text(_solar)).bottom),
        );
        expect(
          tag.left - dates.right,
          greaterThanOrEqualTo(DateHeader.trailingGap),
        );
        expect(DateHeader.trailingGap, Space.s12);
      });

      testWidgets('음력이 없으면 날짜 줄 가운데입니다', (tester) async {
        await tester.pumpWidget(app(lunar: null));
        final solar = tester.getRect(find.text(_solar));
        final tag = tester.getRect(find.byKey(trailingKey));
        expect(tag.center.dy, closeTo(solar.center.dy, 0.01));
      });

      testWidgets('날짜 글자, space.12, 태그가 한 줄에 못 들어가면 아래 space.12 왼쪽 줄로 내립니다', (
        tester,
      ) async {
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pumpWidget(app());
        expect(tester.takeException(), isNull);
        final dates = tester.getRect(find.byKey(DateHeader.datesKey));
        final tag = tester.getRect(find.byKey(trailingKey));
        expect(tag.left, 0);
        expect(tag.top - dates.bottom, closeTo(Space.s12, 0.01));
      });

      testWidgets('loading: trailing 뼈도 같은 자리입니다', (tester) async {
        await tester.pumpWidget(
          inputApp(
            Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 360,
                child: DateHeader.skeleton(
                  solar: _solar,
                  trailing: trailing,
                  animated: false,
                ),
              ),
            ),
          ),
        );
        expect(tester.getRect(find.byKey(trailingKey)).right, 360);
      });
    });

    group('덕일 (D124 ⑤, V119)', () {
      testWidgets('덕일이 없으면 알약이 없고 날짜 머리가 그대로입니다', (tester) async {
        await tester.pumpWidget(_app(lunar: _lunar, iljin: _iljin));
        expect(find.byType(HanjaTag), findsNothing);
        // 칸째 없어 meta 줄은 글줄 높이 그대로이고 눌림 넓힘 상자도 없습니다.
        expect(
          tester.getSize(find.byKey(DateHeader.metaKey)).height,
          tester.getSize(find.text(_lunar)).height,
        );
        expect(
          find.descendant(
            of: find.byType(DateHeader),
            matching: find.byType(HitSlopPassage),
          ),
          findsNothing,
        );
      });

      testWidgets('덕 하나는 일진 뒤 space.8에 compact 길 톤 알약 하나입니다', (tester) async {
        await tester.pumpWidget(
          _app(lunar: _lunar, iljin: _iljin, virtues: [_virtue('천덕일')]),
        );
        final tag = tester.widget<HanjaTag>(find.byType(HanjaTag));
        expect(tag.size, HanjaTagSize.compact);
        expect(tag.tone, HanjaTagTone.good);
        expect(tag.glyph, '德');
        final iljin = tester.getRect(find.byKey(DateHeader.iljinKey));
        final pill = tester.getRect(find.byKey(HanjaTag.surfaceKey));
        expect(pill.left - iljin.right, Space.s8);
        // 알약(22)이 글줄보다 높아 줄 높이가 22이고 글자는 그 세로 가운데입니다.
        expect(tester.getSize(find.byKey(DateHeader.metaKey)).height, 22);
        expect(iljin.center.dy, closeTo(pill.center.dy, 0.5));
      });

      testWidgets('둘이면 받은 순서대로 알약 둘이고 사이는 space.8입니다', (tester) async {
        await tester.pumpWidget(
          _app(
            lunar: _lunar,
            iljin: _iljin,
            virtues: [_virtue('천덕일'), _virtue('월덕일')],
          ),
        );
        final first = tester.getRect(find.text('천덕일'));
        final pills = find.byKey(HanjaTag.surfaceKey);
        expect(pills, findsNWidgets(2));
        final a = tester.getRect(pills.at(0));
        final b = tester.getRect(pills.at(1));
        expect(a.contains(first.center), isTrue);
        expect(b.left - a.right, Space.s8);
      });

      testWidgets('폭이 좁으면 알약이 칸 단위로 다음 줄로 넘어갑니다', (tester) async {
        await tester.pumpWidget(
          _app(
            lunar: _lunar,
            iljin: _iljin,
            virtues: [_virtue('천덕일'), _virtue('월덕일')],
            width: 200,
          ),
        );
        final lunar = tester.getRect(find.text(_lunar));
        final pills = find.byKey(HanjaTag.surfaceKey);
        final last = tester.getRect(pills.last);
        // 칸 하나는 끊지 않고, 넘친 알약은 아래 줄에 놓여 폭 안에 들어갑니다.
        expect(last.top, greaterThan(lunar.bottom));
        for (var i = 0; i < 2; i++) {
          expect(tester.getRect(pills.at(i)).right, lessThanOrEqualTo(200));
        }
        expect(tester.takeException(), isNull);
      });

      testWidgets('스크린리더는 머리 덩어리 뒤에 알약마다 따로 버튼을 읽습니다', (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          _app(
            lunar: _lunar,
            iljin: _iljin,
            virtues: [
              _virtue('천덕일', onTap: () {}),
              _virtue('월덕일', onTap: () {}),
            ],
          ),
        );
        final head = tester
            .getSemantics(find.byKey(DateHeader.datesKey))
            .getSemanticsData();
        expect(head.label, '$_solar, $_lunar, 계미일');
        expect(head.flagsCollection.isHeader, isTrue);
        expect(head.hasAction(SemanticsAction.tap), isFalse);
        for (final name in ['천덕일', '월덕일']) {
          expect(
            tester.getSemantics(find.bySemanticsLabel(name)),
            isSemantics(label: name, isButton: true, hasTapAction: true),
          );
        }
        expect(find.bySemanticsLabel(RegExp('德')), findsNothing);
        // 읽는 순서: 머리 덩어리 → 천덕일 → 월덕일.
        final order = <String>[];
        void visit(SemanticsNode node) {
          if (node.label.isNotEmpty) order.add(node.label);
          node.visitChildren((child) {
            visit(child);
            return true;
          });
        }

        visit(tester.getSemantics(find.byKey(DateHeader.datesKey)));
        expect(order, ['$_solar, $_lunar, 계미일', '천덕일', '월덕일']);
        handle.dispose();
      });

      testWidgets('알약은 누르면 그 덕의 onTap이고 위아래로 44까지 눌립니다', (tester) async {
        final taps = <String>[];
        await tester.pumpWidget(
          _app(
            lunar: _lunar,
            iljin: _iljin,
            virtues: [
              _virtue('천덕일', onTap: () => taps.add('천덕일')),
              _virtue('월덕일', onTap: () => taps.add('월덕일')),
            ],
          ),
        );
        final pill = tester.getRect(find.byKey(HanjaTag.surfaceKey).last);
        expect(pill.height, 22);
        await tester.tapAt(pill.center);
        // 알약이 날짜 머리 맨 아래 줄이어도 위아래 넓힘이 머리 경계에서 막히지 않습니다.
        await tester.tapAt(Offset(pill.center.dx, pill.top - 10));
        await tester.tapAt(Offset(pill.center.dx, pill.bottom + 10));
        expect(taps, ['월덕일', '월덕일', '월덕일']);
        await tester.tapAt(Offset(pill.center.dx, pill.bottom + 12));
        expect(taps, hasLength(3));
      });

      testWidgets('알약이 위아래로 쌓여도 아래 알약의 넓힘이 윗 알약을 가로채지 않습니다', (tester) async {
        final taps = <String>[];
        await tester.pumpWidget(
          _app(
            virtues: [
              _virtue('천덕일', onTap: () => taps.add('천덕일')),
              _virtue('월덕일', onTap: () => taps.add('월덕일')),
            ],
            // 알약 하나만 들어가는 폭이라 둘째 알약이 같은 x의 아래 줄로 넘어갑니다.
            width: 80,
          ),
        );
        final pills = find.byKey(HanjaTag.surfaceKey);
        final upper = tester.getRect(pills.at(0));
        final lower = tester.getRect(pills.at(1));
        expect(lower.top, upper.bottom);
        expect(lower.left, upper.left);
        // 윗 알약의 아래쪽 안은 윗 알약, 아래 알약의 위쪽 안은 아래 알약입니다.
        await tester.tapAt(Offset(upper.center.dx, upper.bottom - 2));
        await tester.tapAt(Offset(lower.center.dx, lower.top + 2));
        // 덮은 알약이 없는 바깥 넓힘은 그대로 받습니다.
        await tester.tapAt(Offset(upper.center.dx, upper.top - 10));
        await tester.tapAt(Offset(lower.center.dx, lower.bottom + 10));
        expect(taps, ['천덕일', '월덕일', '천덕일', '월덕일']);
      });

      testWidgets('넓힌 자리에서도 일진 글자 아래는 누르는 곳이 아닙니다', (tester) async {
        var taps = 0;
        await tester.pumpWidget(
          _app(
            lunar: _lunar,
            iljin: _iljin,
            virtues: [_virtue('천덕일', onTap: () => taps++)],
          ),
        );
        final iljin = tester.getRect(find.byKey(DateHeader.iljinKey));
        await tester.tapAt(Offset(iljin.center.dx, iljin.bottom + 8));
        expect(taps, 0);
      });

      testWidgets('selected면 열린 동안 선택 테두리입니다', (tester) async {
        await tester.pumpWidget(
          _app(
            iljin: _iljin,
            virtues: [
              const DateHeaderVirtue(glyph: '德', label: '천덕일', selected: true),
            ],
          ),
        );
        expect(
          tester.widget<HanjaTag>(find.byType(HanjaTag)).variant,
          HanjaTagVariant.selected,
        );
      });

      testWidgets('loading 뼈에는 덕일 알약 뼈가 없습니다', (tester) async {
        await tester.pumpWidget(
          inputApp(DateHeader.skeleton(solar: _solar, animated: false)),
        );
        expect(find.byType(HanjaTag), findsNothing);
        expect(find.byType(SkeletonTextLines), findsOneWidget);
      });
    });

    test('ComponentSpec은 변형 today, day-sheet와 loading을 가집니다', () {
      expect(DateHeader.spec.id, 'date-header');
      expect(DateHeader.spec.variants, {'today', 'day-sheet'});
      expect(DateHeader.spec.states, {'loading'});
    });
  });
}
