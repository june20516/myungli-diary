import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/design/interaction/single_open_guard.dart';

class _Host extends StatefulWidget {
  const new();

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> with SingleOpenGuard<_Host> {
  @override
  Widget build(BuildContext context) => const SizedBox();
}

void main() {
  testWidgets('여는 동작이 끝날 때까지 다음 동작을 받지 않고, 끝나면 다시 받습니다', (tester) async {
    await tester.pumpWidget(const _Host());
    final state = tester.state<_HostState>(find.byType(_Host));
    final first = Completer<void>();
    var calls = 0;

    state.guardOpen(() {
      calls++;
      return first.future;
    });
    expect(state.isOpening, isTrue);
    // 같은 프레임의 두 번째 누름은 버립니다.
    state.guardOpen(() async => calls++);
    expect(calls, 1);

    first.complete();
    await tester.pump();
    expect(state.isOpening, isFalse);
    state.guardOpen(() async => calls++);
    await tester.pump();
    expect(calls, 2);
  });
}
