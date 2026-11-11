import 'package:myungli_diary/core/api/gen/model/insight.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/features/purchase/model/ad_free_date.dart';

/// 근거 시트 열림 꼬리표 문구(`evidence-sheet.unlock.until`, D118 ①). 열린 이유로 고릅니다.
///
/// * 광고 한 편(`rewarded_ad`): 그날 자정까지(매개변수 없음). 자정의 시간대는 server가 정해
///   `expiresAt`을 주므로 글자에는 쓰지 않습니다.
/// * 광고 제거권(`ad_free_pass`), 구독(`subscription`), 계약에 아직 없는 이유: 끝 시각
///   `expiresAt`의 날짜(프로필 시간대 [timezone]).
///
/// 권한이 없거나, 날짜 문구인데 끝 시각이 없으면 null(꼬리표 없음)입니다.
String? unlockUntilText(
  AppLocalizations l10n,
  Insight? insight,
  String timezone,
) {
  if (insight == null || !insight.active) return null;
  if (insight.source_ == InsightSource_Enum.rewardedAd) {
    return l10n.evidenceSheetUnlockUntilMidnight;
  }
  final expiresAt = insight.expiresAt;
  if (expiresAt == null) return null;
  return l10n.evidenceSheetUnlockUntilDate(
    expiryDate(l10n.localeName, expiresAt, timezone),
  );
}
