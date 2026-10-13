/// 광고 동의 결과.
enum AdConsentResult {
  /// 맞춤 광고 가능.
  personalized,

  /// 비맞춤 광고만 가능.
  nonPersonalized,
}

/// 광고 동의(iOS ATT, 필요한 지역 UMP).
abstract interface class AdConsent {
  /// 이 기기에서 처음 광고를 보이기 전에 동의를 모읍니다.
  ///
  /// UMP를 먼저, 그다음 ATT 순서입니다. 거절이거나 오류면 예외 없이
  /// [AdConsentResult.nonPersonalized]를 돌려줍니다.
  Future<AdConsentResult> gather();
}
