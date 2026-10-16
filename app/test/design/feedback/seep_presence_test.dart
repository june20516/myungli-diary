import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/design/components/feedback/seep_presence.dart';

const Key _childKey = ValueKey('seep-child');

/// [present]·[animateInitial]로 [SeepPresence]를 그린 앱.
Widget _app({required bool present, bool animateInitial = true}) =>
    Directionality(
      textDirection: TextDirection.ltr,
      child: SeepPresence(
        present: present,
        animateInitial: animateInitial,
        child: const SizedBox(key: _childKey, width: 10, height: 10),
      ),
    );

/// 내용을 감싼 가장 가까운 투명도.
double _opacity(WidgetTester tester) => tester
    .widget<Opacity>(
      find.ancestor(of: find.byKey(_childKey), matching: find.byType(Opacity)),
    )
    .opacity;

void main() {
  testWidgets('기본: 처음부터 present면 appear.seep으로 나타납니다', (tester) async {
    await tester.pumpWidget(_app(present: true));
    expect(_opacity(tester), lessThan(1));
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpAndSettle();
    expect(_opacity(tester), 1);
  });

  testWidgets('animateInitial false: 처음부터 present면 첫 프레임에 다 나타난 상태입니다', (
    tester,
  ) async {
    await tester.pumpWidget(_app(present: true, animateInitial: false));
    expect(_opacity(tester), 1);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('animateInitial false: 처음에 없다가 생기면 seep으로 나타납니다', (tester) async {
    await tester.pumpWidget(_app(present: false, animateInitial: false));
    expect(find.byKey(_childKey), findsNothing);

    await tester.pumpWidget(_app(present: true, animateInitial: false));
    expect(_opacity(tester), lessThan(1));
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpAndSettle();
    expect(_opacity(tester), 1);
  });
}
