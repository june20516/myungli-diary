import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/api/http_client.dart';
import 'package:myungli_diary/core/clock/clock.dart';
import 'package:myungli_diary/core/platform/ads.dart';
import 'package:myungli_diary/features/monetization/application/staging_reward_providers.dart';
import 'package:myungli_diary/features/monetization/data/staging_reward_delivery.dart';

/// 고정 시각 시계.
final class _FixedClock implements Clock {
  const new(this.now);

  final DateTime now;

  @override
  DateTime nowUtc() => now;

  @override
  bool get advances => false;
}

/// 보낸 요청을 남기고 200으로 답하는 interceptor.
final class _Capture extends Interceptor {
  final requests = <RequestOptions>[];

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    requests.add(options);
    handler.resolve(
      Response<Object?>(requestOptions: options, statusCode: 200),
    );
  }
}

void main() {
  test('SSV와 같은 값을 staging 경로로 보냅니다(D101 ④, server S131)', () async {
    final capture = _Capture();
    final dio = Dio()..interceptors.add(capture);
    final delivery = StagingRewardDelivery(
      dio,
      clock: _FixedClock(DateTime.utc(2026, 11, 4, 1, 2, 3)),
      newTransactionId: () => 'tx-1',
    );

    await delivery.deliver(
      const RewardEarned(adUnit: 'unit-1', rewardItem: 'insight'),
    );

    final request = capture.requests.single;
    expect(request.method, 'POST');
    expect(request.path, '/test/v1/billing/rewarded-ad');
    expect(request.data, {
      'transactionId': 'tx-1',
      'adUnit': 'unit-1',
      'rewardItem': 'insight',
      'timestamp': DateTime.utc(2026, 11, 4, 1, 2, 3).millisecondsSinceEpoch,
    });
  });

  test('광고 단위와 보상 항목을 모르면 그 필드를 뺍니다', () async {
    final capture = _Capture();
    final delivery = StagingRewardDelivery(
      Dio()..interceptors.add(capture),
      clock: _FixedClock(DateTime.utc(2026, 11, 4)),
    );

    await delivery.deliver(const RewardEarned());

    final data = capture.requests.single.data as Map<String, Object>;
    expect(data.keys, unorderedEquals(['transactionId', 'timestamp']));
    expect(
      data['transactionId'],
      isA<String>().having((v) => v, 'id', isNotEmpty),
    );
  });

  test('staging 환경 값이 없는 빌드(테스트, prod)에서는 http 모드여도 없습니다', () {
    final container = ProviderContainer(
      overrides: [apiModeProvider.overrideWithValue(ApiMode.http)],
    );
    addTearDown(container.dispose);
    expect(container.read(stagingRewardDeliveryProvider), isNull);
  });
}
