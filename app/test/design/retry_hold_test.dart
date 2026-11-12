import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/design/components/feedback/retry_hold.dart';

void main() {
  group('RetryHold(A126 ①)', () {
    test('누르기 전에는 붙잡지 않습니다', () {
      final hold = RetryHold(onChanged: () {});
      expect(hold.holds(isLoading: true), isFalse);
      hold.dispose();
    });

    test('곧바로 끝나도 최소 시간만큼 붙잡고, 지나면 다시 그리게 하고 풉니다', () {
      fakeAsync((async) {
        var changes = 0;
        var retries = 0;
        final hold = RetryHold(onChanged: () => changes++)
          ..start(() => retries++);
        expect(retries, 1);
        expect(changes, 1);
        expect(hold.holds(isLoading: false), isTrue);
        async.elapse(
          RetryHold.defaultMinDuration - const Duration(milliseconds: 1),
        );
        expect(hold.holds(isLoading: false), isTrue);
        async.elapse(const Duration(milliseconds: 1));
        expect(changes, 2);
        expect(hold.holds(isLoading: false), isFalse);
        hold.dispose();
      });
    });

    test('값이 받는 중이면 최소 시간 뒤에도 붙잡습니다(invalidate 뒤 이전 오류를 품은 받는 중)', () {
      fakeAsync((async) {
        final hold = RetryHold(onChanged: () {})..start(() {});
        async.elapse(const Duration(seconds: 1));
        expect(hold.holds(isLoading: true), isTrue);
        expect(hold.holds(isLoading: false), isFalse);
        // 한 번 풀리면 다음 받는 중은 붙잡지 않습니다(처음 불러오기의 지연 규칙으로).
        expect(hold.holds(isLoading: true), isFalse);
        hold.dispose();
      });
    });

    test('돌려준 일이 끝날 때까지 붙잡습니다', () {
      fakeAsync((async) {
        final done = Completer<void>();
        final hold = RetryHold(onChanged: () {})..start(() => done.future);
        async.elapse(const Duration(seconds: 1));
        expect(hold.holds(isLoading: false), isTrue);
        done.completeError(StateError('실패'));
        async.flushMicrotasks();
        expect(hold.holds(isLoading: false), isFalse);
        hold.dispose();
      });
    });

    test('dispose 뒤에는 다시 그리게 하지 않습니다', () {
      fakeAsync((async) {
        var changes = 0;
        RetryHold(onChanged: () => changes++)
          ..start(() {})
          ..dispose();
        async.elapse(const Duration(seconds: 1));
        expect(changes, 1);
      });
    });
  });
}
