import 'package:flutter/material.dart';
import 'package:myungli_diary/core/api/gen/model/five_element.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/theme/ohaeng_colors.dart';

/// 오행 견본 원(`ohaeng.swatch`): 지금 테마의 견본 색에 1px `swatchBorder` 테두리를 두른
/// 원입니다. 테두리가 있어 흰 금 견본도 흰 바탕에 묻히지 않습니다(V98).
///
/// 크기는 쓰는 자리의 계약 값입니다(행운 색 칩과 두 색 시트 머리 14, 오행 막대 범례 12).
class OhaengSwatch extends StatelessWidget {
  /// [element] 견본을 [size] 지름으로 그립니다.
  const new({required this.element, required this.size, super.key});

  /// 행운 색 칩 앞 견본과 두 색 시트 구역 머리 견본의 지름(`lucky-card`
  /// `color.parts.lead.swatch.size`, `colorPairSheet.section.head.swatch` 14).
  static const double luckySize = 14;

  /// 견본 색의 오행.
  final FiveElement element;

  /// 지름.
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.tokens.colors;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: ohaengSwatchOf(colors, element),
        shape: BoxShape.circle,
        border: Border.all(color: colors.swatchBorder),
      ),
    );
  }
}
