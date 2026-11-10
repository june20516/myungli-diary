import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/design/components/feedback/skeleton.dart';
import 'package:myungli_diary/design/components/today/date_header.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

import '../input/input_harness.dart';

const _solar = '10월 13일 화요일';
const _lunar = '음력 8월 24일';
const _iljin = '癸未(계미)일';

Widget _app({String? lunar, String? iljin, double width = 360}) => inputApp(
  Align(
    alignment: Alignment.topLeft,
    child: SizedBox(
      width: width,
      child: DateHeader(solar: _solar, lunar: lunar, iljin: iljin),
    ),
  ),
);

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

    test('ComponentSpec은 변형 today, day-sheet와 loading을 가집니다', () {
      expect(DateHeader.spec.id, 'date-header');
      expect(DateHeader.spec.variants, {'today', 'day-sheet'});
      expect(DateHeader.spec.states, {'loading'});
    });
  });
}
