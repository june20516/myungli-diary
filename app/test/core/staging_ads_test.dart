import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/platform/ads.dart';
import 'package:myungli_diary/core/platform/staging_ads.dart';

import '../design/input/input_harness.dart';

class _Banner implements BannerAdHandle {
  @override
  Widget get view => const SizedBox();

  @override
  Size get size => const Size(320, 50);

  @override
  void dispose() {}
}

class _Rewarded implements RewardedAdHandle {
  @override
  Future<RewardedResult> show() async => const RewardEarned();
}

/// 실제 광고 대역. [error]가 있으면 던지고, [empty]면 null(채울 광고 없음)입니다.
class _RealAds implements Ads {
  AppError? error;
  bool empty = false;

  @override
  Future<BannerAdHandle?> loadBanner({required int width}) async {
    if (error case final e?) throw e;
    return empty ? null : _Banner();
  }

  @override
  Future<RewardedAdHandle?> loadRewarded({required String userId}) async {
    if (error case final e?) throw e;
    return empty ? null : _Rewarded();
  }
}

void main() {
  test('staging 환경 값이 없는 테스트 빌드에서는 staging 광고가 꺼져 있습니다', () {
    expect(stagingAdsBuild, isFalse);
  });

  group('StagingAds(D101 ③)', () {
    late _RealAds real;
    late StagingAds ads;

    setUp(() {
      real = _RealAds();
      ads = StagingAds(
        real: real,
        navigator: () => null,
        bannerSize: (width) async => Size(width.toDouble(), 57),
      );
    });

    test('실제 광고를 받으면 그대로 씁니다', () async {
      expect(await ads.loadBanner(width: 360), isA<_Banner>());
      expect(await ads.loadRewarded(userId: 'a'), isA<_Rewarded>());
    });

    test('채울 광고가 없으면 실제와 같은 크기의 모의 배너와 모의 보상형 광고입니다', () async {
      real.empty = true;
      final banner = await ads.loadBanner(width: 360);
      expect(banner, isA<MockBannerHandle>());
      expect(banner!.size, const Size(360, 57));
      expect(await ads.loadRewarded(userId: 'a'), isA<MockRewardedHandle>());
    });

    test('불러오기 실패(검토 전 등)도 모의 광고로 넘어가지만 오프라인은 그대로 실패입니다', () async {
      real.error = UnexpectedError(StateError('AdMob 불러오기 실패 0'));
      expect(await ads.loadBanner(width: 360), isA<MockBannerHandle>());
      real.error = const OfflineError();
      await expectLater(
        ads.loadRewarded(userId: 'a'),
        throwsA(isA<OfflineError>()),
      );
    });

    test('Navigator가 없으면 모의 보상형 광고는 RewardFailed입니다', () async {
      real.empty = true;
      final handle = await ads.loadRewarded(userId: 'a');
      expect(await handle!.show(), isA<RewardFailed>());
    });
  });

  group('모의 보상형 광고 화면', () {
    Future<({Future<RewardedResult> shown})> showMock(
      WidgetTester tester,
    ) async {
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        inputApp(
          Navigator(
            key: navigator,
            onGenerateRoute: (_) =>
                MaterialPageRoute<void>(builder: (_) => const SizedBox()),
          ),
        ),
      );
      final result = MockRewardedHandle(
        navigator: () => navigator.currentState,
        length: const Duration(seconds: 3),
      ).show();
      await tester.pumpAndSettle();
      return (shown: result);
    }

    testWidgets('끝까지 보면 RewardEarned(모의 광고 단위)이고 남은 초를 보입니다', (tester) async {
      final result = (await showMock(tester)).shown;
      expect(find.text('3'), findsOneWidget);
      expect(find.text('모의 광고'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      await tester.tap(find.byKey(MockRewardedAdPage.closeKey));
      await tester.pumpAndSettle();
      expect(
        await result,
        isA<RewardEarned>().having(
          (r) => r.adUnit,
          'adUnit',
          RewardEarned.mockAdUnit,
        ),
      );
    });

    testWidgets('끝나기 전에 닫거나 뒤로 가면 RewardDismissed입니다', (tester) async {
      final closed = (await showMock(tester)).shown;
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.byKey(MockRewardedAdPage.closeKey));
      await tester.pumpAndSettle();
      expect(await closed, isA<RewardDismissed>());

      final backed = (await showMock(tester)).shown;
      final navigator = tester.state<NavigatorState>(
        find.byType(Navigator).last,
      );
      await navigator.maybePop();
      await tester.pumpAndSettle();
      expect(await backed, isA<RewardDismissed>());
    });

    testWidgets('닫기 버튼은 스크린리더에 닫기로 읽힙니다', (tester) async {
      await showMock(tester);
      final context = tester.element(find.byType(MockRewardedAdPage));
      expect(
        find.byTooltip(MaterialLocalizations.of(context).closeButtonTooltip),
        findsOneWidget,
      );
    });
  });

  testWidgets('모의 배너는 "모의 광고"를 보이고 그 이름으로 읽힙니다', (tester) async {
    await tester.pumpWidget(
      inputApp(const SizedBox(width: 360, height: 57, child: MockBannerAd())),
    );
    expect(find.text('모의 광고'), findsOneWidget);
    expect(find.bySemanticsLabel('모의 광고'), findsOneWidget);
  });
}
