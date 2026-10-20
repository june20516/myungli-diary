import 'package:myungli_diary/core/api/gen/model/notice.dart';
import 'package:myungli_diary/core/api/rendered_text_plain.dart';

/// [notice]를 배너에 보일 문장으로 바꿉니다(today·preview 공용).
///
/// server가 writing 원고(`system.notice`, #232)로 렌더한 문장 조각의 글자를 이은 값을 씁니다.
/// 그 값이 비거나 공백뿐이면 null이라 호출하는 쪽이 배너를 그리지 않습니다(빈 배너 금지).
String? noticeTextOf(Notice notice) {
  final served = plainTextOf(notice.text);
  return served.trim().isEmpty ? null : served;
}
