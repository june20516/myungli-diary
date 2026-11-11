import 'package:flutter/material.dart';
import 'package:myungli_diary/core/api/gen/model/five_element.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/theme/ohaeng_colors.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

/// 천간 한 글자 오행 색 칩(`stem.chip`, V72): band-table 지장간 칸에 씁니다.
///
/// 22 정사각 칸, `radius.sm`, 바탕과 글자 색은 [element]의 `ohaeng.cell` 색입니다(금과 수는 테두리까지).
/// 한자는 `font.family.hanja` 13 700이고 글자 배율은 1.3배에서 멈춥니다(`textScaleMax`).
/// 원국 칸과 대운, 세운 칸은 `ohaeng.cell` 자체이므로 이 칩을 쓰지 않습니다(V89).
/// 스크린리더 라벨은 칩이 놓인 표가 붙입니다.
class StemChip extends StatelessWidget {
  /// [element] 색의 칸에 천간 [hanja] 한 글자를 그립니다.
  const new({required this.element, required this.hanja, super.key});

  /// 천간의 오행.
  final FiveElement element;

  /// 천간 한자 한 글자.
  final String hanja;

  /// 칸 한 변(`stem.chip` `size`).
  static const double side = 22;

  /// 한자 크기(`stem.chip` `hanja.fontSize`).
  static const double hanjaFontSize = 13;

  /// 글자 크기를 멈추는 배율.
  static const double textScaleMax = 1.3;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final cell = ohaengCellColorsOf(tokens.colors, element);
    final scaler = MediaQuery.textScalerOf(context)
        .clamp(maxScaleFactor: textScaleMax);
    return ExcludeSemantics(
      child: Container(
        width: side,
        height: side,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: cell.bg,
          borderRadius: const BorderRadius.all(Radius.circular(Radii.sm)),
          // 금과 수는 `ohaeng.cell`과 같은 1px 안쪽 테두리(V98).
          border: ohaengCellBorder(tokens.colors, element),
        ),
        child: Text(
          hanja,
          textScaler: scaler,
          style: tokens.typography.hanjaPillar.copyWith(
            color: cell.fg,
            fontSize: hanjaFontSize,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
