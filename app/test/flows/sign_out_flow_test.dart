import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/app/entry/entry_providers.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/api/gen/model/evidence_access.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/platform/fakes.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';
import 'package:myungli_diary/core/storage/app_database.dart';
import 'package:myungli_diary/core/storage/cache_store.dart';
import 'package:myungli_diary/core/storage/device_flags.dart';

import '../support/app_harness.dart';

void main() {
  testWidgets('강제 로그아웃이면 이전 계정의 로컬 데이터를 비우고 구매 연결을 끊습니다', (tester) async {
    final purchases = FakePurchases();
    final container = await pumpApp(
      tester,
      scenario: 'member',
      overrides: [purchasesProvider.overrideWithValue(purchases)],
    );
    expect(find.byKey(const ValueKey(ScreenIds.today)), findsOneWidget);
    final accountId = container.read(meProvider)!.accountId;
    final database = container.read(appDatabaseProvider);
    final cache = container.read(cacheStoreProvider);

    await tester.runAsync(() async {
      await purchases.logIn(accountId);
      await cache.write(
        CacheKind.calendar,
        'k',
        '{}',
        access: EvidenceAccess.unlocked,
      );
      await database
          .into(database.diaryDrafts)
          .insert(
            DiaryDraftsCompanion.insert(
              accountId: accountId,
              date: '2026-10-13',
              body: '초안',
              updatedAt: DateTime.utc(2026, 10, 13),
            ),
          );
      await database
          .into(database.onboardingInputs)
          .insert(
            OnboardingInputsCompanion.insert(
              json: '{}',
              updatedAt: DateTime.utc(2026, 10, 13),
            ),
          );
    });

    // AuthInterceptor가 refresh 거부(401·재사용) 때 부르는 것과 같은 경로입니다.
    await tester.runAsync(container.read(tokenStoreProvider).signOut);
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();

    final remaining = await tester.runAsync(() async {
      return (
        cache: await cache.read(CacheKind.calendar, 'k'),
        drafts: await database.select(database.diaryDrafts).get(),
        onboarding: await database.select(database.onboardingInputs).get(),
        adConsentDone: await container
            .read(deviceFlagsStoreProvider)
            .readBool(adConsentDoneKey),
      );
    });
    expect(remaining!.cache, isNull);
    expect(remaining.drafts, isEmpty);
    expect(remaining.onboarding, isEmpty);
    expect(remaining.adConsentDone, isTrue, reason: '기기 플래그는 남습니다');
    expect(purchases.loggedInAccountId, isNull);
    expect(find.byKey(const ValueKey(ScreenIds.welcome)), findsOneWidget);
  });
}
