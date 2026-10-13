import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/app/entry/account_linker.dart';
import 'package:myungli_diary/app/entry/entry_providers.dart';
import 'package:myungli_diary/app/entry/entry_state.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/gen/model/me.dart';
import 'package:myungli_diary/core/platform/fakes.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';
import 'package:myungli_diary/core/platform/purchases.dart';

import '../support/app_harness.dart';

const _accountId = '0b3f6a9e-6c1d-4f43-9a52-3c1e7d2b8a10';

final _me = Me.fromJson({
  'accountId': _accountId,
  'status': 'active',
  'consentRequired': false,
  'requiredConsents': <Object?>[],
  'hasProfile': true,
  'adFree': {'active': false},
  'insight': {'active': false},
});

/// 진입 계산을 고정 값으로 대신합니다. refresh는 같은 계정으로 다시 계산합니다.
class _FixedEntry extends EntryController {
  @override
  Future<EntrySnapshot> build() async => EntrySnapshot(EntryState.ready, _me);
}

/// 첫 logIn만 실패하는 구매 대역.
final class _FlakyPurchases implements Purchases {
  new(this._inner);

  final FakePurchases _inner;
  int logInCalls = 0;

  @override
  Future<void> logIn(String accountId) async {
    logInCalls++;
    if (logInCalls == 1) {
      throw const OfflineError();
    }
    await _inner.logIn(accountId);
  }

  @override
  Future<void> logOut() => _inner.logOut();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('구매 연결이 실패하면 같은 계정의 다음 진입 계산에서 다시 연결합니다', () async {
    final purchases = FakePurchases();
    final flaky = _FlakyPurchases(purchases);
    final container = ProviderContainer(
      overrides: [
        entryStateProvider.overrideWith(_FixedEntry.new),
        purchasesProvider.overrideWithValue(flaky),
        crashReporterProvider.overrideWithValue(FakeCrashReporter()),
      ],
    );
    addTearDown(container.dispose);
    final linker = container.read(accountLinkerProvider);
    await container.read(entryStateProvider.future);
    await linker.idle;
    expect(purchases.loggedInAccountId, isNull);

    await container.read(entryStateProvider.notifier).refresh();
    await linker.idle;
    expect(flaky.logInCalls, 2);
    expect(purchases.loggedInAccountId, _accountId);

    // 성공한 뒤의 재계산은 다시 연결하지 않습니다.
    await container.read(entryStateProvider.notifier).refresh();
    await linker.idle;
    expect(flaky.logInCalls, 2);
  });

  testWidgets('구매 연결이 실패하면 앱이 다시 앞으로 올 때 다시 연결합니다', (tester) async {
    final purchases = FakePurchases();
    final flaky = _FlakyPurchases(purchases);
    final container = await pumpApp(
      tester,
      scenario: 'member',
      overrides: [purchasesProvider.overrideWithValue(flaky)],
    );
    final linker = container.read(accountLinkerProvider);
    await tester.runAsync(() => linker.idle);
    expect(flaky.logInCalls, 1);
    expect(purchases.loggedInAccountId, isNull);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.runAsync(() => linker.idle);

    expect(flaky.logInCalls, 2);
    expect(purchases.loggedInAccountId, _accountId);
  });
}
