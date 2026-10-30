import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/platform/ad_consent.dart';
import 'package:myungli_diary/core/platform/purchases.dart';
import 'package:myungli_diary/core/platform/unavailable_store.dart';

void main() {
  group('UnavailablePurchases', () {
    const purchases = UnavailablePurchases();

    test('buy는 PurchaseFailed(UnexpectedError), 가짜 성공을 만들지 않음', () async {
      final outcome = await purchases.buy('ad_free_1m');
      expect(outcome, isA<PurchaseFailed>());
      expect((outcome as PurchaseFailed).error, isA<UnexpectedError>());
    });

    test('products는 빈 목록', () async {
      expect(await purchases.products(), isEmpty);
    });

    test('sync, logIn, logOut은 아무것도 하지 않고 끝남', () async {
      await expectLater(purchases.sync(), completes);
      await expectLater(purchases.logIn('account'), completes);
      await expectLater(purchases.logOut(), completes);
    });
  });

  group('NoAds', () {
    test('배너와 보상형은 null', () async {
      const ads = NoAds();
      expect(await ads.loadBanner(width: 320), isNull);
      expect(await ads.loadRewarded(userId: 'account'), isNull);
    });
  });

  test('NonPersonalizedAdConsent는 nonPersonalized', () async {
    expect(
      await const NonPersonalizedAdConsent().gather(),
      AdConsentResult.nonPersonalized,
    );
  });
}
