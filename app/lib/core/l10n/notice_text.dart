import 'package:myungli_diary/core/api/gen/model/notice.dart';
import 'package:myungli_diary/core/api/gen/model/notice_code.dart';
import 'package:myungli_diary/core/api/rendered_text_plain.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';

/// [notice]를 배너에 보일 문장으로 바꿉니다(today·preview 공용).
///
/// server가 준 문장 조각의 글자를 이은 값을 씁니다. 그 값이 비거나 공백뿐이면 code별 app 문구를
/// 대신 쓰고(`time_unknown` → `noticeTimeUnknown`, A43), app 문구도 없는 code면 null이라
/// 호출하는 쪽이 배너를 그리지 않습니다(빈 배너 금지).
String? noticeTextOf(Notice notice, AppLocalizations l10n) {
  final served = plainTextOf(notice.text);
  if (served.trim().isNotEmpty) {
    return served;
  }
  return switch (notice.code) {
    NoticeCode.timeUnknown => l10n.noticeTimeUnknown,
    _ => null,
  };
}
