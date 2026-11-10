import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:myungli_diary/core/api/gen/model/five_element.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/theme/ohaeng_colors.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

/// [OhaengCell] 크기(`ohaeng.cell` `sizes`).
enum OhaengCellSize {
  /// 원국표 기둥 칸: 높이 66, 한자 `type.hanja.pillar` + 아래 독음 `type.caption.sm`.
  pillar,

  /// 대운, 세운 기둥 칸(`luck-pillar`): 40 × 40, 한자 18 700, 독음 없음.
  small,
}

/// 오행 칸(`ohaeng.cell`): 오행 바탕 + 오행 글자로 천간·지지 한 글자를 보입니다. `radius.sm`.
/// 금과 수 칸은 1px 안쪽 테두리를 둡니다(`border`, V98).
///
/// 글자 크기는 1.3배에서 멈춥니다(`textScaleMax`). 표 칸이 커지면 원국 배치가 무너지기 때문입니다.
/// [OhaengCell.empty]는 시간 모름의 시주처럼 값이 없는 자리(점선 테두리 빈 칸)입니다.
/// 스크린리더 라벨은 표가 칸마다 따로 붙이므로 이 요소는 글자를 읽히지 않습니다.
class OhaengCell extends StatelessWidget {
  /// [element]의 칸에 [hanja](한 글자)와 [reading](독음, `pillar`만)을 그립니다.
  const new({
    required this.element,
    required this.hanja,
    this.reading,
    this.size = OhaengCellSize.pillar,
    super.key,
  }) : empty = false;

  /// 값이 없는 칸(점선 테두리).
  const new empty({this.size = OhaengCellSize.pillar, super.key})
    : element = null,
      hanja = '',
      reading = null,
      empty = true;

  /// 칸 높이(`pillar`).
  static const double pillarHeight = 66;

  /// 칸 한 변(`small`, 계약 `ohaeng.cell` `sizes`).
  static const double smallSide = 40;

  /// 글자 크기를 멈추는 배율.
  static const double textScaleMax = 1.3;

  /// 오행. [empty]면 null입니다.
  final FiveElement? element;

  /// 한자 한 글자.
  final String hanja;

  /// 독음(`pillar`에서만 그림).
  final String? reading;

  /// 크기.
  final OhaengCellSize size;

  /// 값이 없는 칸인지.
  final bool empty;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final pillar = size == OhaengCellSize.pillar;
    final scaler = MediaQuery.textScalerOf(context)
        .clamp(maxScaleFactor: textScaleMax);
    // 칸은 글자가 커진 만큼만 늘어납니다(1.3배에서 멈춤).
    final grow = scaler.scale(10) / 10;
    final side = switch (size) {
      OhaengCellSize.pillar => pillarHeight,
      OhaengCellSize.small => smallSide,
    };
    final height = side * math.max(1, grow);
    final width = pillar ? null : side * math.max(1, grow);
    const radius = BorderRadius.all(Radius.circular(Radii.sm));

    if (empty) {
      return SizedBox(
        width: width,
        height: height,
        child: CustomPaint(painter: _DashedBorder(color: colors.line)),
      );
    }

    final cell = ohaengCellColorsOf(colors, element!);
    final hanjaStyle = switch (size) {
      OhaengCellSize.pillar => tokens.typography.hanjaPillar.copyWith(
        color: cell.fg,
      ),
      OhaengCellSize.small => tokens.typography.hanjaPillar.copyWith(
        color: cell.fg,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    };
    final text = reading;
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: scaler),
      child: ExcludeSemantics(
        child: Container(
          width: width,
          height: height,
          // 금과 수 칸은 1px 안쪽 테두리(V98). 안쪽에 그려 칸과 글자 크기는 그대로입니다.
          decoration: BoxDecoration(
            color: cell.bg,
            borderRadius: radius,
            border: ohaengCellBorder(colors, element!),
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(hanja, style: hanjaStyle),
              if (pillar && text != null) ...[
                const SizedBox(height: Space.s4),
                Text(
                  text,
                  style: tokens.typography.captionSm.copyWith(color: cell.fg),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 점선 테두리(`radius.sm`).
final class _DashedBorder extends CustomPainter {
  const new({required this.color});

  final Color color;

  static const double _dash = 4;
  static const double _gap = 3;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          const Radius.circular(Radii.sm),
        ).deflate(0.5),
      );
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + _dash), paint);
        distance += _dash + _gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder oldDelegate) => oldDelegate.color != color;
}
