import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/gen/model/language.dart';
import 'package:myungli_diary/core/api/known_language.dart';

void main() {
  test('knownLanguageOf는 아는 값은 그대로, 모르는 값은 en이다', () {
    expect(knownLanguageOf(Language.ko), Language.ko);
    expect(knownLanguageOf(Language.en), Language.en);
    expect(knownLanguageOf(Language.ja), Language.ja);
    expect(knownLanguageOf(Language.unknownDefaultOpenApi), Language.en);
  });
}
