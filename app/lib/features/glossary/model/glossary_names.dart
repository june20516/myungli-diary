import 'package:myungli_diary/core/api/gen/model/rendered_text.dart';

/// 값 이름 사전. 이름·뜻 조회는 모두 여기를 거칩니다(오늘·달력·일기 태그·나의 사주).
final class GlossaryNames {
  /// 범주 → (값 → 이름)과 용어 id → 뜻 문장.
  const new(this.values, {this.meanings = const {}});

  /// 범주 → (값 → 이름).
  final Map<String, Map<String, String>> values;

  /// 용어 id → 뜻 문장(writing 슬롯 `term.meaning`, 계약 draft.3 `Glossary.meanings`).
  final Map<String, RenderedText> meanings;

  /// `<범주>.<값>` 형태의 [termId]에 해당하는 이름. 모르면 null입니다.
  ///
  /// 첫 `.`에서 나누므로 값에 `.`이 들어가도(`ten_god_rush.bigyeop`) 됩니다.
  /// 태그는 `tag.<키>`입니다.
  String? nameOf(String termId) {
    final dot = termId.indexOf('.');
    if (dot <= 0) {
      return null;
    }
    return valueName(termId.substring(0, dot), termId.substring(dot + 1));
  }

  /// [category]의 [value] 이름. 모르면 null입니다.
  String? valueName(String category, String value) => values[category]?[value];

  /// 용어 id [termId](`<범주>.<값>`, `tag.<키>`)의 뜻 문장. 모르면 null입니다.
  RenderedText? meaningOf(String termId) => meanings[termId];
}
