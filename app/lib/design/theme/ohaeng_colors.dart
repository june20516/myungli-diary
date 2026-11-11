import 'package:flutter/painting.dart';
import 'package:myungli_diary/core/api/gen/model/five_element.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

/// 오행 [element]의 견본 색(`ohaeng.swatch`). 행운 색 칩·오행 막대처럼 색 자체를 보이는 자리에 씁니다.
Color ohaengSwatchOf(ColorTokens colors, FiveElement element) =>
    switch (element) {
      FiveElement.wood => colors.ohaengWoodSwatch,
      FiveElement.fire => colors.ohaengFireSwatch,
      FiveElement.earth => colors.ohaengEarthSwatch,
      FiveElement.metal => colors.ohaengMetalSwatch,
      FiveElement.water => colors.ohaengWaterSwatch,
    };

/// 오행 [element]의 칸 바탕·글자 색(`ohaeng.cell` `byElement`). 원국표·만세력·대운 칸에 씁니다.
({Color bg, Color fg}) ohaengCellColorsOf(
  ColorTokens colors,
  FiveElement element,
) => switch (element) {
  FiveElement.wood => (bg: colors.ohaengWoodBg, fg: colors.ohaengWoodFg),
  FiveElement.fire => (bg: colors.ohaengFireBg, fg: colors.ohaengFireFg),
  FiveElement.earth => (bg: colors.ohaengEarthBg, fg: colors.ohaengEarthFg),
  FiveElement.metal => (bg: colors.ohaengMetalBg, fg: colors.ohaengMetalFg),
  FiveElement.water => (bg: colors.ohaengWaterBg, fg: colors.ohaengWaterFg),
};

/// 오행 [element] 칸의 1px 안쪽 테두리 색(`ohaeng.cell` `border.byElement`, V98).
///
/// 금과 수 칸에만 늘 그리고, 목, 화, 토는 테두리가 없어 null입니다. 테두리가 보이는 모드가
/// 아니면 토큰 값이 칸 바탕과 같아 그려도 보이지 않습니다. `stem.chip`과
/// `hanja-tag` `ganji` 알약도 같은 값을 씁니다.
Color? ohaengCellBorderOf(ColorTokens colors, FiveElement element) =>
    switch (element) {
      FiveElement.metal => colors.ohaengMetalBorder,
      FiveElement.water => colors.ohaengWaterBorder,
      FiveElement.wood || FiveElement.fire || FiveElement.earth => null,
    };

/// 오행 칸 테두리 굵기(`ohaeng.cell` `border.width`).
const double ohaengCellBorderWidth = 1;

/// 오행 [element]의 칸 [Border](안쪽). 금과 수만 있고 나머지는 null입니다.
Border? ohaengCellBorder(ColorTokens colors, FiveElement element) =>
    switch (ohaengCellBorderOf(colors, element)) {
      // 굵기 상수와 렌더링이 한 값이 되도록 기본값(1)이어도 적습니다.
      // ignore: avoid_redundant_argument_values
      final color? => Border.all(color: color, width: ohaengCellBorderWidth),
      null => null,
    };

/// `bg.sheet` 흰 원 안에 그리는 오행 [element] 한자색(`color.ohaeng.<오행>.glyph`, V98).
///
/// 오행 글자가 `bg.sheet`에서 읽히면 글자색, 아니면 알약 바탕색입니다(V78과 같은 규칙).
Color ohaengGlyphOf(ColorTokens colors, FiveElement element) =>
    switch (element) {
      FiveElement.wood => colors.ohaengWoodGlyph,
      FiveElement.fire => colors.ohaengFireGlyph,
      FiveElement.earth => colors.ohaengEarthGlyph,
      FiveElement.metal => colors.ohaengMetalGlyph,
      FiveElement.water => colors.ohaengWaterGlyph,
    };
