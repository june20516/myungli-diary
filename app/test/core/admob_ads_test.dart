import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/platform/admob_ads.dart';
import 'package:myungli_diary/core/platform/ads.dart';

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

/// SDK 경계 대역.
class _Api implements AdMobApi {
  final List<String> calls = [];
  bool canRequest = true;
  int initializeFailures = 0;
  AdMobLoadFailure? failWith;

  @override
  Future<void> initialize() async {
    calls.add('initialize');
    if (initializeFailures > 0) {
      initializeFailures--;
      throw StateError('init');
    }
  }

  @override
  Future<bool> canRequestAds() async => canRequest;

  @override
  Future<BannerAdHandle?> loadBanner({
    required String unitId,
    required int width,
  }) async {
    calls.add('banner $unitId $width');
    if (failWith case final failure?) throw failure;
    return _Banner();
  }

  @override
  Future<RewardedAdHandle?> loadRewarded({
    required String unitId,
    required String userId,
  }) async {
    calls.add('rewarded $unitId $userId');
    if (failWith case final failure?) throw failure;
    return _Rewarded();
  }
}

void main() {
  group('adMobUnitId(D99와 같은 축)', () {
    test('debug는 Google 공식 테스트 단위', () {
      expect(
        adMobUnitId(AdMobFormat.banner, platform: TargetPlatform.android),
        'ca-app-pub-3940256099942544/9214589741',
      );
      expect(
        adMobUnitId(AdMobFormat.rewarded, platform: TargetPlatform.iOS),
        'ca-app-pub-3940256099942544/1712485313',
      );
    });

    test('release는 실제 단위(#686)', () {
      expect(
        adMobUnitId(
          AdMobFormat.banner,
          platform: TargetPlatform.iOS,
          useTestAds: false,
        ),
        'ca-app-pub-5703509220233743/7635334395',
      );
      expect(
        adMobUnitId(
          AdMobFormat.rewarded,
          platform: TargetPlatform.android,
          useTestAds: false,
        ),
        'ca-app-pub-5703509220233743/5621087138',
      );
    });

    test('Android, iOS 밖은 null', () {
      expect(
        adMobUnitId(AdMobFormat.banner, platform: TargetPlatform.macOS),
        isNull,
      );
    });
  });

  group('adMobLoadError', () {
    test('광고 없음(Android 3, iOS 1)은 null', () {
      expect(adMobLoadError(3, platform: TargetPlatform.android), isNull);
      expect(adMobLoadError(1, platform: TargetPlatform.iOS), isNull);
    });

    test('네트워크(둘 다 2)는 OfflineError, 그 밖은 UnexpectedError', () {
      expect(
        adMobLoadError(2, platform: TargetPlatform.android),
        isA<OfflineError>(),
      );
      expect(
        adMobLoadError(2, platform: TargetPlatform.iOS),
        isA<OfflineError>(),
      );
      expect(
        adMobLoadError(1, platform: TargetPlatform.android),
        isA<UnexpectedError>(),
      );
    });
  });

  group('AdMobAds', () {
    late _Api api;

    AdMobAds ads({TargetPlatform platform = TargetPlatform.android}) =>
        AdMobAds(platform: platform, api: api);

    setUp(() => api = _Api());

    test('처음 부를 때 한 번 초기화하고 테스트 단위로 불러옵니다', () async {
      final adapter = ads();
      expect(await adapter.loadBanner(width: 360), isNotNull);
      expect(await adapter.loadRewarded(userId: 'acc-1'), isNotNull);
      expect(api.calls, [
        'initialize',
        'banner ca-app-pub-3940256099942544/9214589741 360',
        'rewarded ca-app-pub-3940256099942544/5224354917 acc-1',
      ]);
    });

    test('초기화가 실패하면 UnexpectedError이고 다음 호출에서 다시 초기화합니다', () async {
      api.initializeFailures = 1;
      final adapter = ads();
      await expectLater(
        adapter.loadBanner(width: 360),
        throwsA(isA<UnexpectedError>()),
      );
      expect(await adapter.loadBanner(width: 360), isNotNull);
      expect(api.calls.where((c) => c == 'initialize'), hasLength(2));
    });

    test('동의가 광고 요청을 허락하지 않으면 불러오지 않고 null', () async {
      api.canRequest = false;
      expect(await ads().loadBanner(width: 360), isNull);
      expect(await ads().loadRewarded(userId: 'a'), isNull);
      expect(api.calls.where((c) => !c.startsWith('initialize')), isEmpty);
    });

    test('불러오기 실패: 광고 없음은 null, 네트워크는 OfflineError', () async {
      final adapter = ads();
      api.failWith = const AdMobLoadFailure(3, 'no fill');
      expect(await adapter.loadBanner(width: 360), isNull);
      api.failWith = const AdMobLoadFailure(2, 'network');
      await expectLater(
        adapter.loadRewarded(userId: 'a'),
        throwsA(isA<OfflineError>()),
      );
    });

    test('지원하지 않는 플랫폼은 SDK를 부르지 않고 null', () async {
      final adapter = ads(platform: TargetPlatform.macOS);
      expect(await adapter.loadBanner(width: 360), isNull);
      expect(await adapter.loadRewarded(userId: 'a'), isNull);
      expect(api.calls, isEmpty);
    });
  });

  group('rewardedResultOf', () {
    test('보상을 받고 닫으면 RewardEarned, 받기 전 닫으면 RewardDismissed', () {
      expect(rewardedResultOf(earned: true), isA<RewardEarned>());
      expect(rewardedResultOf(earned: false), isA<RewardDismissed>());
    });

    test('보이지 못하면 RewardFailed(UnexpectedError)', () {
      expect(
        rewardedResultOf(earned: false, showError: 'fail'),
        isA<RewardFailed>().having(
          (r) => r.error,
          'error',
          isA<UnexpectedError>(),
        ),
      );
    });
  });
}
