import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/design/components/feedback/seep_on_change.dart';
import 'package:myungli_diary/design/interaction/motion_prefs.dart';

/// 상태를 가진 자식. 다시 스밀 때도 상태가 남는지 확인합니다.
class _Counter extends StatefulWidget {
  const new();

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int count = 0;

  @override
  Widget build(BuildContext context) => Text('$count');
}

Widget _host(Object key, {bool reduceMotion = false}) => MotionPrefsScope(
  prefs: MotionPrefs(
    reduceMotion: reduceMotion,
    reduceTransparency: false,
    lowEnd: false,
  ),
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: SeepOnChange(changeKey: key, child: const _Counter()),
  ),
);

double _opacity(WidgetTester tester) => tester
    .widget<Opacity>(
      find.ancestor(of: find.byType(_Counter), matching: find.byType(Opacity)),
    )
    .opacity;

void main() {
  testWidgets('처음과 같은 key로 다시 그릴 때는 움직이지 않습니다', (tester) async {
    await tester.pumpWidget(_host('a'));
    expect(_opacity(tester), 1);
    expect(tester.binding.hasScheduledFrame, isFalse);

    await tester.pumpWidget(_host('a'));
    expect(_opacity(tester), 1);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('key가 바뀌면 appear.seep으로 다시 스미고 자식 상태는 남습니다', (tester) async {
    await tester.pumpWidget(_host('a'));
    tester.state<_CounterState>(find.byType(_Counter)).count = 3;

    await tester.pumpWidget(_host('b'));
    await tester.pump(const Duration(milliseconds: 40));
    expect(_opacity(tester), lessThan(1));

    await tester.pumpAndSettle();
    expect(_opacity(tester), 1);
    expect(tester.state<_CounterState>(find.byType(_Counter)).count, 3);
  });

  testWidgets('동작 줄이기에서도 투명도로만 스밉니다', (tester) async {
    await tester.pumpWidget(_host('a', reduceMotion: true));
    await tester.pumpWidget(_host('b', reduceMotion: true));
    await tester.pump(const Duration(milliseconds: 40));
    expect(_opacity(tester), lessThan(1));
    expect(find.byType(ImageFiltered), findsNothing);
    await tester.pumpAndSettle();
  });
}
