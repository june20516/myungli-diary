import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/app/entry/entry_providers.dart';
import 'package:myungli_diary/core/api/fake/fake_server.dart';
import 'package:myungli_diary/core/api/gen/model/ad_free.dart';
import 'package:myungli_diary/core/api/gen/model/evidence_access.dart';
import 'package:myungli_diary/core/api/gen/model/insight.dart';
import 'package:myungli_diary/core/api/gen/model/me.dart';
import 'package:myungli_diary/features/depth/application/insight_expiry_relock.dart';
import 'package:myungli_diary/features/me/application/chart_providers.dart';
import 'package:myungli_diary/features/monetization/application/insight_providers.dart';
import 'package:myungli_diary/features/today/application/daily_controller.dart';

import '../../support/app_harness.dart';

/// 테스트가 손으로 바꾸는 지금 권한과 내 정보.
final class _Switch<T> extends Notifier<T> {
  new(this._initial);

  final T _initial;

  @override
  T build() => _initial;

  // Notifier 상태는 setter 대신 메서드로 바꾸는 것이 Riverpod 관례입니다.
  // ignore: use_setters_to_change_properties
  void set(T value) => state = value;
}

final _adGrant = Insight(
  active: true,
  expiresAt: DateTime.utc(2026, 10, 13, 5),
  source_: InsightSource_Enum.rewardedAd,
);

final _insight = NotifierProvider<_Switch<Insight?>, Insight?>(
  () => _Switch<Insight?>(_adGrant),
);

/// 실제 I/O(asset, DB)와 가짜 시계 영역의 microtask, timer를 한 번씩 풀어 줍니다.
Future<void> _spin(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 10)),
  );
  await tester.pump(const Duration(milliseconds: 50));
}

Future<void> _until(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 300; i++) {
    if (done()) return;
    await _spin(tester);
  }
  fail('조건이 채워지지 않음');
}

/// [scenario]로 부팅해 오늘 응답과 나의 사주를 받아 두고, 다시 잠그기를 구독합니다.
///
/// 지금 권한은 [_insight]로, 내 정보는 [me]가 있으면 그것으로 바꿉니다.
Future<ProviderContainer> _boot(
  WidgetTester tester,
  String scenario, {
  NotifierProvider<_Switch<Me?>, Me?>? me,
}) async {
  final container = (await tester.runAsync(
    () => bootstrapForTest(
      scenario,
      overrides: [
        currentInsightProvider.overrideWith((ref) => ref.watch(_insight)),
        if (me != null) meProvider.overrideWith((ref) => ref.watch(me)),
      ],
    ),
  ))!;
  addTearDown(container.dispose);
  await tester.runAsync(() => container.read(entryStateProvider.future));
  for (final provider in [dailyControllerProvider, chartControllerProvider]) {
    final subscription = container.listen(provider, (_, _) {});
    addTearDown(subscription.close);
  }
  final relock = container.listen(insightExpiryRelockProvider, (_, _) {});
  addTearDown(relock.close);
  await _until(
    tester,
    () =>
        container.read(dailyControllerProvider).hasValue &&
        !container.read(dailyControllerProvider).isLoading &&
        container.read(chartControllerProvider).hasValue &&
        !container.read(chartControllerProvider).isLoading,
  );
  return container;
}

FakeServerInterceptor _fake(ProviderContainer container) =>
    container.read(fakeServerInterceptorProvider)! as FakeServerInterceptor;

void main() {
  group('insightExpiryRelockProvider(D132)', () {
    testWidgets('권한이 끝나면 들고 있는 열린 오늘 응답과 나의 사주를 한 번씩 다시 받습니다', (tester) async {
      final container = await _boot(tester, 'evidence-unlocked');
      expect(
        container.read(dailyControllerProvider).value!.daily.evidenceAccess,
        EvidenceAccess.unlocked,
      );
      final daily = _fake(container).callCountOf('getDaily');
      final chart = _fake(container).callCountOf('getChart');

      container.read(_insight.notifier).set(null);
      await _until(
        tester,
        () =>
            _fake(container).callCountOf('getDaily') == daily + 1 &&
            _fake(container).callCountOf('getChart') == chart + 1,
      );
      for (var i = 0; i < 3; i++) {
        await _spin(tester);
      }
      expect(_fake(container).callCountOf('getDaily'), daily + 1);
      expect(_fake(container).callCountOf('getChart'), chart + 1);
    });

    testWidgets('들고 있는 응답이 잠겨 있으면 다시 받지 않습니다', (tester) async {
      final container = await _boot(tester, 'member');
      final daily = _fake(container).callCountOf('getDaily');
      final chart = _fake(container).callCountOf('getChart');

      container.read(_insight.notifier).set(null);
      for (var i = 0; i < 5; i++) {
        await _spin(tester);
      }
      expect(_fake(container).callCountOf('getDaily'), daily);
      expect(_fake(container).callCountOf('getChart'), chart);
    });

    testWidgets('로그아웃으로 권한이 없어지면(내 정보 없음) 다시 받지 않습니다', (tester) async {
      final me = NotifierProvider<_Switch<Me?>, Me?>(
        () => _Switch<Me?>(
          Me(
            accountId: 'a',
            consentRequired: false,
            requiredConsents: const [],
            hasProfile: true,
            adFree: AdFree(active: false),
            insight: _adGrant,
          ),
        ),
      );
      final container = await _boot(tester, 'evidence-unlocked', me: me);
      final daily = _fake(container).callCountOf('getDaily');
      final chart = _fake(container).callCountOf('getChart');

      container.read(me.notifier).set(null);
      container.read(_insight.notifier).set(null);
      for (var i = 0; i < 5; i++) {
        await _spin(tester);
      }
      expect(_fake(container).callCountOf('getDaily'), daily);
      expect(_fake(container).callCountOf('getChart'), chart);
    });
  });
}
