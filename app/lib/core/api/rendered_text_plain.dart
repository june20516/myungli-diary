import 'package:myungli_diary/core/api/gen/model/rendered_text.dart';

/// [text]의 조각 글자를 이은 평문(용어 조각도 글자 그대로). 스크린리더 라벨·공유 이미지
/// 첫 문장·빈 문장 판정이 함께 씁니다.
String plainTextOf(RenderedText text) =>
    text.segments.map((segment) => segment.text).join();

/// [text]의 평문([plainTextOf])이 비었거나 공백뿐인지. 빈 문장은 자리 없이 건너뜁니다
/// (A22 남은 규칙).
bool isBlankText(RenderedText text) => plainTextOf(text).trim().isEmpty;
