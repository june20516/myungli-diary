import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/gen/model/notice.dart';
import 'package:myungli_diary/core/l10n/notice_text.dart';

Notice _notice(String code, List<String> pieces) => Notice.fromJson({
  'code': code,
  'text': {
    'segments': [
      for (final piece in pieces) {'text': piece},
    ],
  },
});

void main() {
  test('server 문장이 있으면 조각 글자를 이어 그대로 씁니다', () {
    expect(
      noticeTextOf(_notice('time_unknown', ['태어난 시간을 ', '몰라요.'])),
      '태어난 시간을 몰라요.',
    );
  });

  test('문장이 비거나 공백뿐이면 code와 관계없이 null이라 배너를 그리지 않습니다', () {
    expect(noticeTextOf(_notice('time_unknown', [])), isNull);
    expect(noticeTextOf(_notice('time_unknown', [' ', '\n'])), isNull);
    expect(noticeTextOf(_notice('near_solar_term', [' '])), isNull);
  });
}
