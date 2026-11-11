import 'package:myungli_diary/core/api/gen/model/rendered_text.dart';
import 'package:myungli_diary/core/api/gen/model/segment.dart';

/// [text]의 조각 글자를 이은 평문(용어 조각도 글자 그대로). 스크린리더 라벨·공유 이미지
/// 첫 문장·빈 문장 판정이 함께 씁니다.
String plainTextOf(RenderedText text) =>
    text.segments.map((segment) => segment.text).join();

/// [text]의 평문([plainTextOf])이 비었거나 공백뿐인지. 빈 문장은 자리 없이 건너뜁니다
/// (A22 남은 규칙).
bool isBlankText(RenderedText text) => plainTextOf(text).trim().isEmpty;

/// [text]를 줄바꿈(`\n`)마다 나눈 줄들. 조각의 용어(`term`)는 나뉜 조각마다 그대로 남고,
/// 빈 조각은 버립니다. 줄바꿈이 없으면 줄 하나입니다.
///
/// 원전 문장(`Evidence.source`)은 writing 원고가 뜻, 원문, 출처를 줄 순서로 나눠 줍니다
/// (`evidence.source` structure, D118 ③).
List<RenderedText> linesOf(RenderedText text) {
  final lines = <List<Segment>>[[]];
  for (final segment in text.segments) {
    final parts = segment.text.split('\n');
    for (final (index, part) in parts.indexed) {
      if (index > 0) lines.add([]);
      if (part.isNotEmpty) {
        lines.last.add(Segment(text: part, term: segment.term));
      }
    }
  }
  return [for (final segments in lines) RenderedText(segments: segments)];
}
