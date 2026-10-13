import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/platform/ad_consent.dart';
import 'package:myungli_diary/core/platform/app_check.dart';
import 'package:myungli_diary/core/platform/crash_reporter.dart';
import 'package:myungli_diary/core/platform/fakes.dart';
import 'package:myungli_diary/core/platform/purchases.dart';
import 'package:myungli_diary/core/platform/push.dart';
import 'package:myungli_diary/core/platform/social_auth.dart';

void main() {
  group('Ads', () {
    test('보상형이 준비되지 않으면 null', () async {
      final ads = FakeAds(rewardedAvailable: false);
      expect(await ads.loadRewarded(userId: 'u'), isNull);
    });

    test('배너가 준비되지 않으면 null', () async {
      final ads = FakeAds(bannerAvailable: false);
      expect(await ads.loadBanner(width: 320), isNull);
    });

    test('기본 대역은 보상형을 끝까지 보면 true', () async {
      final handle = await FakeAds().loadRewarded(userId: 'u');
      expect(await handle!.show(), isTrue);
    });

    test('보상을 못 받는 대역은 false', () async {
      final handle = await FakeAds(rewardEarned: false)
          .loadRewarded(userId: 'u');
      expect(await handle!.show(), isFalse);
    });

    test('배너는 요청한 너비의 크기를 가진다', () async {
      final banner = await FakeAds().loadBanner(width: 360);
      expect(banner!.size.width, 360);
      expect(banner.size.height, greaterThan(0));
      banner.dispose();
    });

    test('보상형을 요청한 userId를 기록한다', () async {
      final ads = FakeAds();
      await ads.loadRewarded(userId: 'account-1');
      expect(ads.rewardedUserIds, ['account-1']);
    });
  });

  group('로그인', () {
    test('카카오 대역은 비어 있지 않은 idToken', () async {
      final credential = await const FakeKakaoAuth().signIn(nonce: 'n');
      expect(credential.idToken, isNotEmpty);
    });

    test('카카오 대역은 주입한 오류로 실패한다', () async {
      const auth = FakeKakaoAuth(failWith: OfflineError());
      await expectLater(auth.signIn(nonce: 'n'), throwsA(isA<OfflineError>()));
    });

    test('Apple 대역은 idToken·authorizationCode·clientType을 낸다', () async {
      final credential = await const FakeAppleAuth(
        clientType: AppleClientType.web,
      ).signIn(nonce: 'n', state: 's');
      expect(credential.idToken, isNotEmpty);
      expect(credential.authorizationCode, isNotEmpty);
      expect(credential.clientType, AppleClientType.web);
    });

    test('Apple 대역은 주입한 오류로 실패한다', () async {
      const auth = FakeAppleAuth(failWith: TimeoutError());
      await expectLater(
        auth.signIn(nonce: 'n', state: 's'),
        throwsA(isA<TimeoutError>()),
      );
    });
  });

  group('AppCheck', () {
    test('대역은 비어 있지 않은 토큰', () async {
      const AppCheck appCheck = FakeAppCheck();
      expect(await appCheck.token(), isNotEmpty);
    });
  });

  group('푸시', () {
    test('opens에 넣은 값이 그대로 나온다', () async {
      final push = FakePushMessaging();
      const open = PushOpen(screenId: ScreenIds.today);
      final received = push.opens.first;
      push.addOpen(open);
      expect(await received, same(open));
    });

    test('권한과 토큰은 생성자 인자를 따른다', () async {
      final push = FakePushMessaging(
        permissionGranted: false,
        tokenValue: null,
      );
      expect(await push.requestPermission(), isFalse);
      expect(await push.token(), isNull);
    });

    test('토큰 갱신이 흐른다', () async {
      final push = FakePushMessaging();
      final refreshed = push.tokenRefreshes.first;
      push.addTokenRefresh('t2');
      expect(await refreshed, 't2');
    });
  });

  group('CrashReporter (D64)', () {
    test('IA 화면 id breadcrumb은 기록된다', () {
      final reporter = FakeCrashReporter()..breadcrumb('today');
      expect(reporter.breadcrumbs, ['today']);
    });

    test('IA 화면 id가 아닌 값은 debug에서 assert 실패, 기록되지 않는다', () {
      final reporter = FakeCrashReporter();
      expect(
        () => reporter.breadcrumb('1990-01-01'),
        throwsA(isA<AssertionError>()),
      );
      expect(reporter.breadcrumbs, isEmpty);
    });

    test('release에서도 걸러지도록 판별 함수가 거부한다', () {
      expect(sanitizeBreadcrumb('today'), 'today');
      expect(sanitizeBreadcrumb('1990-01-01'), isNull);
      expect(sanitizeBreadcrumb('오늘 일기 본문'), isNull);
    });

    test('계정 id는 UUID만 받는다', () {
      const uuid = '123e4567-e89b-12d3-a456-426614174000';
      expect(sanitizeAccountId(uuid), uuid);
      expect(sanitizeAccountId('홍길동'), isNull);
      expect(sanitizeAccountId('1990-01-01'), isNull);
      expect(sanitizeAccountId(null), isNull);
    });

    test('setUser는 UUID가 아니면 assert 실패, 기록되지 않는다', () {
      final reporter = FakeCrashReporter();
      expect(() => reporter.setUser('홍길동'), throwsA(isA<AssertionError>()));
      expect(reporter.userId, isNull);
      reporter.setUser('123e4567-e89b-12d3-a456-426614174000');
      expect(reporter.userId, '123e4567-e89b-12d3-a456-426614174000');
      reporter.setUser(null);
      expect(reporter.userId, isNull);
    });

    test('record는 오류를 모은다', () {
      final reporter = FakeCrashReporter()
        ..record(StateError('x'), StackTrace.current);
      expect(reporter.errors, hasLength(1));
    });
  });

  group('광고 동의', () {
    test('대역은 주입한 결과를 낸다', () async {
      expect(
        await const FakeAdConsent(result: AdConsentResult.nonPersonalized)
            .gather(),
        AdConsentResult.nonPersonalized,
      );
      expect(
        await const FakeAdConsent().gather(),
        AdConsentResult.personalized,
      );
    });
  });

  group('결제', () {
    test('상품 목록과 성공', () async {
      final purchases = FakePurchases();
      await purchases.logIn('a');
      final products = await purchases.products();
      expect(products, isNotEmpty);
      final outcome = await purchases.buy(products.first.id);
      expect(outcome, isA<PurchaseSucceeded>());
      expect(purchases.loggedInAccountId, 'a');
    });

    test('취소와 실패를 구분한다', () async {
      expect(
        await FakePurchases(outcome: const PurchaseCancelled()).buy('p'),
        isA<PurchaseCancelled>(),
      );
      final failed = await FakePurchases(
        outcome: const PurchaseFailed(OfflineError()),
      ).buy('p');
      expect(failed, isA<PurchaseFailed>());
    });
  });

  group('공유', () {
    test('공유한 이미지와 문구를 기록한다', () async {
      final share = FakeShareSheet();
      await share.sharePng(Uint8List.fromList([1, 2]), text: '문구');
      expect(share.shared.single.text, '문구');
      expect(share.shared.single.png, [1, 2]);
    });
  });
}
