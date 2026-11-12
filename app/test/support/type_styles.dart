import 'package:flutter/painting.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

/// [type] 한 벌의 글자 스타일 전부(생성 토큰 `TypeTokens`의 필드 순서).
List<TextStyle> typeStylesOf(TypeTokens type) => [
  type.sentenceCard,
  type.sentenceBody,
  type.display,
  type.title,
  type.subtitle,
  type.labelLg,
  type.labelMd,
  type.captionMd,
  type.captionSm,
  type.captionLg,
  type.numericCalendar,
  type.numericTable,
  type.hanjaPillar,
  type.bodyUi,
];

/// 생성 토큰 두 벌(ko, ja)의 글자 스타일 전부.
List<TextStyle> allTypeStyles() => [
  for (final type in const [koType, jaType]) ...typeStylesOf(type),
];
