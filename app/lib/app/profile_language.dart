import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/features/profile/application/profile_providers.dart';

/// 앱 언어에 프로필 사본의 `language`를 연결하는 override(결정 A60).
///
/// 사본이 없거나(로그아웃·처음 설치) 아직 읽는 중이면 null이라 기기 로케일을 씁니다. 사본을
/// 다시 읽는 동안에는 앞 값을 그대로 두어 언어가 잠깐 기기 값으로 깜박이지 않습니다.
/// core(`api_providers.dart`)가 feature를 알지 않도록 조립 지점인 app이 잇습니다.
final List<Override> profileLanguageOverrides = [
  profileLanguageProvider.overrideWith(
    (ref) => ref.watch(cachedProfileProvider).value?.language,
  ),
];
