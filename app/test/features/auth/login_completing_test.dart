import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/features/auth/application/login_completing.dart';

void main() {
  test('앞 시도가 끝나도 뒤 시도의 보류는 유지된다', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final completing = container.read(loginCompletingProvider.notifier)
      ..begin() // 첫 로그인
      ..begin() // 보류 중 다시 연 login의 두 번째 로그인
      ..end(); // 첫 로그인이 먼저 끝남
    expect(container.read(loginCompletingProvider), isTrue);

    completing.end();
    expect(container.read(loginCompletingProvider), isFalse);
  });

  test('시작하지 않은 end는 보류를 켜지 않는다', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(loginCompletingProvider.notifier).end();

    expect(container.read(loginCompletingProvider), isFalse);
  });
}
