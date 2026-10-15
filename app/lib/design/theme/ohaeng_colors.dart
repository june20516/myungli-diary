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
