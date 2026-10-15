import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/app/bootstrap.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/fake/scenario.dart';
import 'package:myungli_diary/core/platform/ads.dart';
import 'package:myungli_diary/core/platform/fakes.dart';

String _scenario(String extra) =>
    '[{"id": "a", "today": "2026-10-13", "timezone": "Asia/Seoul"$extra}]';

void main() {
  group('Scenario.rewardedAd', () {
    test('생략하면 earned입니다', () {
      final scenario = parseScenarios(_scenario('')).single;
      expect(scenario.rewardedAd, ScenarioRewardedAd.earned);
    });

    test('값마다 해당하는 결과입니다', () {
      for (final value in ScenarioRewardedAd.values) {
        final scenario = parseScenarios(
          _scenario(', "rewardedAd": "${value.name}"'),
        ).single;
        expect(scenario.rewardedAd, value);
      }
    });

    test('모르는 값이면 ScenarioFormatException입니다', () {
      expect(
        () => parseScenarios(_scenario(', "rewardedAd": "maybe"')),
        throwsA(isA<ScenarioFormatException>()),
      );
    });
  });

  group('fakeAdsFor', () {
    Future<RewardedResult?> showOf(ScenarioRewardedAd value) async {
      final ad = await fakeAdsFor(value).loadRewarded(userId: 'u');
      return ad == null ? null : await ad.show();
    }

    test('earned: 끝까지 봐서 보상을 받습니다', () async {
      expect(await showOf(ScenarioRewardedAd.earned), isA<RewardEarned>());
    });

    test('dismissed: 보상 전에 닫습니다', () async {
      expect(
        await showOf(ScenarioRewardedAd.dismissed),
        isA<RewardDismissed>(),
      );
    });

    test('unavailable: 볼 수 있는 광고가 없습니다', () async {
      expect(await showOf(ScenarioRewardedAd.unavailable), isNull);
    });

    test('failed: 표시에 실패합니다', () async {
      final result = await showOf(ScenarioRewardedAd.failed);
      expect(result, isA<RewardFailed>());
      expect((result! as RewardFailed).error, isA<AppError>());
    });

    test('배너는 늘 준비됩니다', () {
      for (final value in ScenarioRewardedAd.values) {
        expect(fakeAdsFor(value), isA<FakeAds>());
        expect((fakeAdsFor(value) as FakeAds).bannerAvailable, isTrue);
      }
    });
  });
}
