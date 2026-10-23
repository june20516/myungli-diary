import 'package:intl/intl.dart';
import 'package:myungli_diary/core/api/gen/model/ad_free.dart';
import 'package:myungli_diary/core/clock/clock.dart';

/// 광고 제거권 만료일 글자(그 언어의 짧은 날짜). 활성이 아니면 null입니다.
///
/// 만료 시각(UTC)을 프로필 시간대([timezone])의 날짜로 보입니다. 설정 줄과 `ad-free` 화면이
/// 같은 날짜를 보이도록 이 함수 하나를 씁니다.
String? adFreeExpiryDate(String localeName, AdFree? adFree, String timezone) {
  final expiresAt = adFree?.expiresAt;
  if (adFree == null || !adFree.active || expiresAt == null) {
    return null;
  }
  final local = localTimeIn(expiresAt, timezone);
  return DateFormat.yMMMd(localeName)
      .format(DateTime(local.year, local.month, local.day));
}
