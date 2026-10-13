import 'package:myungli_diary/core/api/gen/model/me.dart';
import 'package:pub_semver/pub_semver.dart';

/// 앱을 열었을 때 보낼 갈래.
enum EntryState {
  /// 앱 버전이 최소 버전보다 낮습니다.
  forceUpdate,

  /// 로그아웃 상태입니다.
  signedOut,

  /// 필수 약관에 동의하지 않았습니다.
  consentRequired,

  /// 사주 프로필이 없습니다.
  profileRequired,

  /// 이 기기에서 광고 동의를 받지 않았습니다. 화면 없이 SDK를 부른 뒤 다시 계산합니다.
  adConsentRequired,

  /// 모두 갖췄습니다.
  ready,
}

/// 진입 갈래를 판정합니다. 순서는 IA spec §3입니다.
///
/// 업데이트 강제 > 로그아웃 > 약관 미동의 > 프로필 없음 > 광고 동의 전 > 완료.
EntryState computeEntry({
  required Version appVersion,
  required Version minimumVersion,
  required bool hasSession,
  required bool adConsentDone,
  Me? me,
}) {
  if (appVersion < minimumVersion) {
    return EntryState.forceUpdate;
  }
  if (!hasSession || me == null) {
    return EntryState.signedOut;
  }
  if (me.consentRequired) {
    return EntryState.consentRequired;
  }
  if (!me.hasProfile) {
    return EntryState.profileRequired;
  }
  if (!adConsentDone) {
    return EntryState.adConsentRequired;
  }
  return EntryState.ready;
}
