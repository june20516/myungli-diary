import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:myungli_diary/core/clock/clock.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';
import 'package:myungli_diary/features/profile/application/profile_providers.dart';

/// 프로필 시간대에 프로필 사본을 연결하는 override.
///
/// 사본의 `currentTimezone` → 기기 시간대 → [fallbackTimezone] 순입니다(결정 A18).
/// core(`clock.dart`)가 feature를 알지 않도록 조립 지점인 app이 잇습니다.
final List<Override> profileTimezoneOverrides = [
  profileTimezoneProvider.overrideWith((ref) {
    final cached = ref.watch(cachedProfileProvider).value;
    if (cached != null) {
      return cached.currentTimezone;
    }
    return ref.watch(deviceTimezoneNameProvider).value ?? fallbackTimezone;
  }),
];
