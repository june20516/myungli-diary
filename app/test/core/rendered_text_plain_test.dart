import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/gen/model/rendered_text.dart';
import 'package:myungli_diary/core/api/rendered_text_plain.dart';

RenderedText _text(List<Object> pieces) => RenderedText.fromJson({
  'segments': [
    for (final piece in pieces)
      if (piece is String)
        {'text': piece}
      else
        {'text': (piece as (String, String)).$1, 'term': piece.$2},
  ],
});

void main() {
  test('plainTextOf는 조각 글자(용어 조각 포함)를 그대로 잇습니다', () {
    expect(plainTextOf(_text([])), '');
    expect(
      plainTextOf(_text(['오늘은 ', ('정관', 'ten_god.jeonggwan'), '의 날'])),
      '오늘은 정관의 날',
    );
    expect(plainTextOf(_text([' 앞뒤 ', '공백 '])), ' 앞뒤 공백 ');
  });

  test('isBlankText는 조각이 없거나 공백뿐이면 true입니다', () {
    expect(isBlankText(_text([])), isTrue);
    expect(isBlankText(_text(['', ' ', '\n'])), isTrue);
    expect(isBlankText(_text(['오늘은'])), isFalse);
  });
}
