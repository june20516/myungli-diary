import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/gen/model/notice.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations_ko.dart';
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
  final l10n = AppLocalizationsKo();

  test('server 문장이 있으면 조각 글자를 이어 그대로 씁니다', () {
    expect(
      noticeTextOf(_notice('time_unknown', ['태어난 시간을 ', '몰라요.']), l10n),
      '태어난 시간을 몰라요.',
    );
  });

  test('time_unknown 문장이 비어 있으면 app 문구입니다', () {
    expect(
      noticeTextOf(_notice('time_unknown', []), l10n),
      l10n.noticeTimeUnknown,
    );
    expect(
      noticeTextOf(_notice('time_unknown', [' ', '\n']), l10n),
      l10n.noticeTimeUnknown,
    );
  });

  test('공백뿐인 문장도 비어 있는 것으로 봅니다', () {
    expect(
      noticeTextOf(_notice('time_unknown', [' ', '\n']), l10n),
      l10n.noticeTimeUnknown,
    );
    expect(noticeTextOf(_notice('near_solar_term', [' ']), l10n), isNull);
  });

  test('app 문구가 없는 code의 문장이 비어 있으면 null이라 배너를 그리지 않습니다', () {
    expect(noticeTextOf(_notice('near_solar_term', []), l10n), isNull);
  });
}
