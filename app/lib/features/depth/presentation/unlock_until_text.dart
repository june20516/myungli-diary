import 'package:intl/intl.dart';
import 'package:myungli_diary/core/api/gen/model/insight.dart';
import 'package:myungli_diary/core/clock/clock.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/features/purchase/model/ad_free_date.dart';

/// 근거 시트 열림 꼬리표 문구(`evidence-sheet.unlock.until`, D118 ①). 열린 이유로 고릅니다.
///
/// * 광고 한 편(`rewarded_ad`): 끝 시각 `expiresAt`(광고를 본 때부터 2시간, D132)을 기기
///   시간대 [timezone]의 시각으로 씁니다. 기기가 24시간제면([use24HourFormat]) 24시간 시각입니다.
/// * 광고 제거권(`ad_free_pass`), 구독(`subscription`), 계약에 아직 없는 이유: 끝 시각
///   `expiresAt`의 날짜(시간대 [timezone]).
///
/// 권한이 없거나 끝 시각이 없으면 null(꼬리표 없음)입니다.
String? unlockUntilText(
  AppLocalizations l10n,
  Insight? insight,
  String timezone, {
  required bool use24HourFormat,
}) {
  if (insight == null || !insight.active) return null;
  final expiresAt = insight.expiresAt;
  if (expiresAt == null) return null;
  if (insight.source_ == InsightSource_Enum.rewardedAd) {
    return l10n.evidenceSheetUnlockUntilTime(
      expiryTime(
        l10n.localeName,
        expiresAt,
        timezone,
        use24HourFormat: use24HourFormat,
      ),
    );
  }
  return l10n.evidenceSheetUnlockUntilDate(
    expiryDate(l10n.localeName, expiresAt, timezone),
  );
}

/// 끝 시각 [expiresAt](UTC)을 시간대 [timezone]의 그 언어 시각(예 "오후 3:05", 24시간제면
/// "15:05")으로 씁니다.
String expiryTime(
  String localeName,
  DateTime expiresAt,
  String timezone, {
  required bool use24HourFormat,
}) {
  final local = localTimeIn(expiresAt, timezone);
  final format = use24HourFormat
      ? DateFormat.Hm(localeName)
      : DateFormat.jm(localeName);
  return format.format(
    DateTime(local.year, local.month, local.day, local.hour, local.minute),
  );
}
