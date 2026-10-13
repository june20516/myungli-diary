import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/app/entry/account_linker.dart';
import 'package:myungli_diary/app/router/screen_breadcrumbs.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/platform/fakes.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';
import 'package:myungli_diary/core/platform/purchases.dart';

const _accountA = '0b3f6a9e-6c1d-4f43-9a52-3c1e7d2b8a10';
const _accountB = '7c2e1f40-1b2a-4c3d-8e9f-0a1b2c3d4e5f';

final _linkerProvider = Provider<AccountLinker>(AccountLinker.new);

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
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late FakePurchases purchases;
  late FakeCrashReporter crash;

  setUp(() {
    purchases = FakePurchases();
    crash = FakeCrashReporter();
  });

  ProviderContainer container({Purchases? purchasesOverride}) {
    final c = ProviderContainer(
      overrides: [
        purchasesProvider.overrideWithValue(purchasesOverride ?? purchases),
        crashReporterProvider.overrideWithValue(crash),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  group('AccountLinker', () {
    test('계정 id가 생기면 구매·보고에 잇고, 같은 계정이면 다시 잇지 않습니다', () async {
      final linker = container().read(_linkerProvider)
        ..link(_accountA)
        ..link(_accountA);
      await linker.idle;
      expect(purchases.loggedInAccountId, _accountA);
      expect(crash.userId, _accountA);
    });

    test('다른 계정으로 바뀌면 새 계정으로 잇습니다', () async {
      final linker = container().read(_linkerProvider)
        ..link(_accountA)
        ..link(_accountB);
      await linker.idle;
      expect(purchases.loggedInAccountId, _accountB);
      expect(crash.userId, _accountB);
    });

    test('null은 해제가 아니어서 연결을 그대로 둡니다', () async {
      final linker = container().read(_linkerProvider)
        ..link(_accountA)
        ..link(null);
      await linker.idle;
      expect(purchases.loggedInAccountId, _accountA);
    });

    test('unlink는 구매 연결과 사용자 식별값을 지우고, 같은 계정의 재로그인을 다시 잇습니다', () async {
      final linker = container().read(_linkerProvider)
        ..link(_accountA)
        ..unlink();
      await linker.idle;
      expect(purchases.loggedInAccountId, isNull);
      expect(crash.userId, isNull);

      linker.link(_accountA);
      await linker.idle;
      expect(purchases.loggedInAccountId, _accountA);
    });

    test('구매 연결이 실패하면 요약만 보고하고 다음 진입 계산 때 다시 시도합니다', () async {
      final flaky = _FlakyPurchases(purchases);
      final linker = container(purchasesOverride: flaky).read(_linkerProvider)
        ..link(_accountA);
      await linker.idle;
      expect(purchases.loggedInAccountId, isNull);
      expect(crash.errors.single.errorType, 'OfflineError');

      linker.link(_accountA);
      await linker.idle;
      expect(flaky.logInCalls, 2);
      expect(purchases.loggedInAccountId, _accountA);
    });
  });

  group('screenIdOfPath', () {
    test('IA 화면 경로면 화면 id, 아니면 null입니다', () {
      expect(screenIdOfPath('/today'), ScreenIds.today);
      expect(screenIdOfPath('/auth/apple'), isNull);
      expect(screenIdOfPath('/unknown'), isNull);
    });
  });
}
