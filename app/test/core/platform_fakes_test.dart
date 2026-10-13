import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/ia/ia_ids.dart';
import 'package:myungli_diary/core/platform/ad_consent.dart';
import 'package:myungli_diary/core/platform/ads.dart';
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
      expect(await handle!.show(), isA<RewardEarned>());
    });

    test('보상 전에 닫음과 표시 실패를 만들 수 있다', () async {
      final dismissed = await FakeAds(rewardedResult: const RewardDismissed())
          .loadRewarded(userId: 'u');
      expect(await dismissed!.show(), isA<RewardDismissed>());
      final failed = await FakeAds(
        rewardedResult: const RewardFailed(OfflineError()),
      ).loadRewarded(userId: 'u');
      expect(await failed!.show(), isA<RewardFailed>());
    });

    test('불러오기 예외를 주입할 수 있다', () async {
      await expectLater(
        FakeAds(bannerFailWith: const OfflineError()).loadBanner(width: 320),
        throwsA(isA<OfflineError>()),
      );
      await expectLater(
        FakeAds(rewardedFailWith: const TimeoutError())
            .loadRewarded(userId: 'u'),
        throwsA(isA<TimeoutError>()),
      );
    });

    test('배너 dispose는 두 번 불러도 안전하다', () async {
      final banner = await FakeAds().loadBanner(width: 320);
      banner!
        ..dispose()
        ..dispose();
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
      final open = PushOpen.tryCreate(ScreenIds.today)!;
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

    test('IA 화면 id가 아닌 PushOpen은 만들어지지 않는다', () {
      expect(PushOpen.tryCreate('1990-01-01'), isNull);
      expect(PushOpen.tryCreate('today')!.screenId, 'today');
    });

    test('앱이 꺼진 상태의 시작 알림을 낸다', () async {
      final open = PushOpen.tryCreate(ScreenIds.today);
      expect(await FakePushMessaging(initial: open).initialOpen(), same(open));
      expect(await FakePushMessaging().initialOpen(), isNull);
    });

    test('권한 거절을 흉내 낸다', () async {
      expect(
        await FakePushMessaging(permissionGranted: false).requestPermission(),
        isFalse,
      );
    });

    test('dispose 뒤 스트림이 닫힌다', () async {
      final push = FakePushMessaging();
      final done = push.opens.isEmpty;
      await push.dispose();
      expect(await done, isTrue);
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
      expect(sanitizeScreenId('today'), 'today');
      expect(sanitizeScreenId('1990-01-01'), isNull);
      expect(sanitizeScreenId('오늘 일기 본문'), isNull);
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
        ..record(CrashSummary.from(StateError('x')), StackTrace.current);
      expect(reporter.errors, hasLength(1));
    });

    test('CrashSummary는 메시지와 본문을 담지 않는다', () {
      const secret = '1990-05-05 홍길동 오늘 일기';
      final state = CrashSummary.from(StateError('출생일 $secret'));
      expect(state.errorType, 'StateError');
      final unexpected = CrashSummary.from(
        UnexpectedError(
          DioException(
            requestOptions: RequestOptions(path: '/diaries', data: secret),
            response: Response<Object?>(
              requestOptions: RequestOptions(path: '/diaries'),
              data: {'body': secret},
            ),
          ),
        ),
      );
      expect(unexpected.errorType, 'UnexpectedError');
      for (final summary in [state, unexpected]) {
        final text = '${summary.errorType}${summary.code}${summary.status}';
        expect(text.contains('1990'), isFalse);
        expect(text.contains('홍길동'), isFalse);
        expect(text.contains('일기'), isFalse);
      }
    });

    test('형식이 이상한 problem code는 버린다', () {
      for (final code in ['홍길동 1990-05-05', 'A.B', '', 'a' * 65]) {
        final summary = CrashSummary.from(
          ProblemError(
            code: code,
            status: 422,
            fieldErrors: const [],
            traceId: 't',
          ),
        );
        expect(summary.code, isNull, reason: code);
        expect(summary.status, 422);
      }
    });

    test('ProblemError는 code와 status만 담는다', () {
      final summary = CrashSummary.from(
        const ProblemError(
          code: 'date.invalid',
          status: 422,
          fieldErrors: [FieldProblem('/birth', 'x')],
          traceId: 't',
        ),
      );
      expect(summary.errorType, 'ProblemError');
      expect(summary.code, 'date.invalid');
      expect(summary.status, 422);
    });
  });

  group('광고 동의', () {
    test('오류를 흉내 내도 예외 없이 비맞춤', () async {
      expect(
        await const FakeAdConsent(simulateError: true).gather(),
        AdConsentResult.nonPersonalized,
      );
    });

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
        await FakePurchases(outcomes: [const PurchaseCancelled()]).buy('p'),
        isA<PurchaseCancelled>(),
      );
      final failed = await FakePurchases(
        outcomes: [const PurchaseFailed(OfflineError())],
      ).buy('p');
      expect(failed, isA<PurchaseFailed>());
    });

    test('buy는 호출마다 목록 순서대로 응답하고 마지막을 반복한다', () async {
      final purchases = FakePurchases(
        outcomes: [const PurchaseCancelled(), const PurchaseSucceeded()],
      );
      expect(await purchases.buy('p'), isA<PurchaseCancelled>());
      expect(await purchases.buy('p'), isA<PurchaseSucceeded>());
      expect(await purchases.buy('p'), isA<PurchaseSucceeded>());
    });

    test('logIn 실패를 주입하고 logOut으로 연결을 끊는다', () async {
      await expectLater(
        FakePurchases(logInFailWith: const OfflineError()).logIn('a'),
        throwsA(isA<OfflineError>()),
      );
      final purchases = FakePurchases();
      await purchases.logIn('a');
      await purchases.logOut();
      expect(purchases.loggedInAccountId, isNull);
    });

    test('restore는 주입한 결과를 낸다', () async {
      expect(await FakePurchases().restore(), isA<PurchaseSucceeded>());
      expect(
        await FakePurchases(restoreOutcome: const PurchaseCancelled())
            .restore(),
        isA<PurchaseCancelled>(),
      );
    });
  });

  group('공유', () {
    test('공유한 이미지와 문구를 기록한다', () async {
      final share = FakeShareSheet();
      await share.sharePng(Uint8List.fromList([1, 2]), text: '문구');
      expect(share.shared.single.text, '문구');
      expect(share.shared.single.png, [1, 2]);
    });

    test('공유 실패를 주입할 수 있다', () async {
      await expectLater(
        FakeShareSheet(failWith: const OfflineError())
            .sharePng(Uint8List(0), text: ''),
        throwsA(isA<OfflineError>()),
      );
    });
  });
}
