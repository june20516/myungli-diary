import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:myungli_diary/core/clock/clock.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';
import 'package:myungli_diary/features/profile/application/profile_providers.dart';

/// 프로필 시간대에 프로필 사본을 연결하는 override.
///
/// 사본의 `currentTimezone` → 기기 시간대 → [fallbackTimezone] 순입니다(결정 A18).
/// 모르는 이름이면 다음 후보로 물러나고 crash 요약만 남깁니다([pickKnownTimezone]).
/// core(`clock.dart`)가 feature를 알지 않도록 조립 지점인 app이 잇습니다.
final List<Override> profileTimezoneOverrides = [
  profileTimezoneProvider.overrideWith(
    (ref) => pickKnownTimezone([
      ref.watch(cachedProfileProvider).value?.currentTimezone,
      ref.watch(deviceTimezoneNameProvider).value,
    ], onUnknown: () => reportUnknownTimezone(ref)),
  ),
];
