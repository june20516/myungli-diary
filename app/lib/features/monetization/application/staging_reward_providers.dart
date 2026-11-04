import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/api/http_client.dart';
import 'package:myungli_diary/core/clock/clock.dart';
import 'package:myungli_diary/core/platform/staging_ads.dart';
import 'package:myungli_diary/features/monetization/data/staging_reward_delivery.dart';

/// staging 보상 전달. staging 환경의 실제 server(http 모드)에서만 있고, 그 밖에는 null입니다
/// (prod는 SSV 콜백만, fake 모드는 대역 광고 결과로 권한이 바뀜).
final stagingRewardDeliveryProvider = Provider<StagingRewardSender?>((ref) {
  if (!stagingAdsBuild || ref.watch(apiModeProvider) != ApiMode.http) {
    return null;
  }
  return StagingRewardDelivery(
    ref.watch(dioProvider),
    clock: ref.watch(clockProvider),
  );
});
