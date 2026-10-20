import 'package:flutter/foundation.dart';
import 'package:myungli_diary/core/api/gen/model/app_config.dart';
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

  /// 이 기기에서 새 계정의 프로필을 만든 뒤 알림 허락(notify-ask)을 아직 거치지 않았습니다(A17).
  notifyAskRequired,

  /// 이 기기에서 광고 동의를 받지 않았습니다. 화면 없이 SDK를 부른 뒤 다시 계산합니다.
  adConsentRequired,

  /// 모두 갖췄습니다.
  ready,
}

/// 진입 갈래를 판정합니다. 순서는 IA spec §3입니다.
///
/// 업데이트 강제 > 로그아웃 > (모르는 필수 약관이면 업데이트 강제) > 약관 미동의 >
/// 프로필 없음 > 알림 허락 대기 > 광고 동의 전 > 완료. 알림 허락 대기
/// ([notifyAskPending])는 IA 순서(프로필 저장 → notify-ask → ad-consent)를 지키려는
/// 기기 플래그입니다(A17). 삭제 대기 계정(server 결정 S16)은 로그아웃으로 봅니다.
/// 동의할 문서에 이 앱이 모르는 문서가 있으면([requiresUnknownConsent]) 동의 화면에서
/// 그 문서를 그리지도 보내지도 못해 막다른 길이 되므로 업데이트를 강제합니다(A66).
EntryState computeEntry({
  required Version appVersion,
  required Version minimumVersion,
  required bool hasSession,
  required bool adConsentDone,
  required bool notifyAskPending,
  Me? me,
}) {
  if (appVersion < minimumVersion) {
    return EntryState.forceUpdate;
  }
  if (!hasSession || me == null || isPendingDeletion(me)) {
    return EntryState.signedOut;
  }
  if (me.consentRequired) {
    if (requiresUnknownConsent(me)) {
      return EntryState.forceUpdate;
    }
    return EntryState.consentRequired;
  }
  if (!me.hasProfile) {
    return EntryState.profileRequired;
  }
  if (notifyAskPending) {
    return EntryState.notifyAskRequired;
  }
  if (!adConsentDone) {
    return EntryState.adConsentRequired;
  }
  return EntryState.ready;
}

/// 동의할 문서(`requiredConsents`)에 이 앱이 모르는 문서가 있는지.
///
/// `ConsentDocument.document`는 계약의 열린 enum이라 freeze 뒤 새 문서가 올 수 있습니다(A66).
bool requiresUnknownConsent(Me me) =>
    me.requiredConsents.any((consent) => !consent.document.isKnown);

/// 삭제 대기 계정인지. 남은 토큰으로는 getMe·deleteMe·logout만 됩니다(S16).
bool isPendingDeletion(Me me) => me.status == MeStatusEnum.pendingDeletion;

/// 진입 갈래와 그때 받은 내 정보. 로그아웃이면 [me]가 null입니다.
@immutable
final class EntrySnapshot {
  /// 갈래와 내 정보를 묶습니다.
  const new(this.entry, this.me);

  /// 진입 갈래.
  final EntryState entry;

  /// 내 정보.
  final Me? me;
}

/// [platform]에 맞는 최소 앱 버전 문자열.
///
/// 앱은 iOS·Android 전용이므로 android가 아니면 iOS 값을 씁니다.
String minimumVersionFor(AppConfig config, TargetPlatform platform) =>
    platform == TargetPlatform.android
    ? config.minimumVersion.android
    : config.minimumVersion.ios;

/// 버전 문자열을 해석합니다. 빌드 번호(`+2`)는 떼고 비교합니다.
///
/// 해석할 수 없으면 [FormatException]입니다.
Version parseAppVersion(String raw) {
  final core = raw.split('+').first;
  try {
    return Version.parse(core);
  } on FormatException catch (e) {
    throw FormatException('앱 버전을 해석할 수 없습니다: "$raw"', e.source);
  }
}
