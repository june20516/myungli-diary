import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';

/// 도장 변형.
enum SealVariant {
  /// 채움: 안의 날짜는 `seal.knock`으로 새기고 아이콘은 `action.on-primary`.
  fill,

  /// 옅은 채움: 안의 내용은 본문색.
  soft,

  /// 테두리 1.6px.
  outline,
}

/// 도장 크기(`elements.json` `seal.sizes`).
enum SealSize {
  /// 달력 칸.
  cell(26),

  /// 탭 바, 반응 버튼, 일기 목록 날짜.
  row(34),

  /// 질문 카드.
  card(52),

  /// 일기 종이.
  paper(64);

  new(this.logical);

  /// 논리 픽셀(도장 영역 한 변).
  final double logical;
}

/// 낙관 도장 요소. 모양만 -8° 기울고 안의 내용은 바로 서서 가운데에 놓입니다.
///
/// 찍힘·지워짐 움직임은 `animate(InteractionPattern.sealStamp / sealErase)`로 입힙니다.
class Seal extends StatelessWidget {
  /// 도장을 만듭니다.
  const new({
    required this.size,
    this.variant = SealVariant.fill,
    this.contentColor,
    this.child,
    super.key,
  });

  /// 도장 영역 크기.
  final SealSize size;

  /// 변형.
  final SealVariant variant;

  /// 안 내용 색(글자·아이콘 모두). 없으면 변형의 기본: fill은 글자 `seal.knock`·
  /// 아이콘 `action.on-primary`, 그 밖은 `text.primary`.
  final Color? contentColor;

  /// 안의 내용(날짜 숫자, 아이콘 등). 없을 수 있습니다.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final colors = context.tokens.colors;
    final color = switch (variant) {
      SealVariant.fill || SealVariant.outline => colors.sealFill,
      SealVariant.soft => colors.sealSoft,
    };
    // 명세: fill에서 날짜 글자는 knock으로 새기고 아이콘은 action.on-primary.
    final isFill = variant == SealVariant.fill;
    final textColor =
        contentColor ?? (isFill ? colors.sealKnock : colors.textPrimary);
    final iconColor =
        contentColor ?? (isFill ? colors.actionOnPrimary : colors.textPrimary);
    return SizedBox.square(
      dimension: size.logical,
      child: CustomPaint(
        painter: _SealPainter(
          color: color,
          outline: variant == SealVariant.outline,
        ),
        child: child == null
            ? null
            : Center(
                child: IconTheme.merge(
                  data: IconThemeData(color: iconColor),
                  child: DefaultTextStyle.merge(
                    style: TextStyle(color: textColor),
                    // 글자 크기를 키워도 도장 영역을 넘지 않게 줄입니다.
                    child: FittedBox(child: child),
                  ),
                ),
              ),
      ),
    );
  }
}

/// 도장 모양(-8° 기운 낙관 경로)으로 자르는 clipper. skeleton 도장 자리처럼 같은 모양이
/// 필요한 곳에서 씁니다.
class SealShapeClipper extends CustomClipper<Path> {
  /// clipper를 만듭니다.
  const new();

  @override
  Path getClip(Size size) => _SealPainter.placedPath(size);

  @override
  bool shouldReclip(SealShapeClipper oldClipper) => false;
}

/// 로고 낙관 경로(20 단위 격자)를 크기에 맞춰 그립니다.
class _SealPainter extends CustomPainter {
  new({required this.color, required this.outline});

  static const double _grid = 20;
  static const double _rotateDegrees = -8;
  static const double _outlineWidth = 1.6;

  final Color color;
  final bool outline;

  /// 명세 경로: `M1.2 1.5 q8.8 -1.3 17.6 0 q1.2 8.5 0 17
  /// q-8.8 1.3 -17.6 0 q-1.2 -8.5 0 -17 z`.
  static Path _path() => Path()
    ..moveTo(1.2, 1.5)
    ..relativeQuadraticBezierTo(8.8, -1.3, 17.6, 0)
    ..relativeQuadraticBezierTo(1.2, 8.5, 0, 17)
    ..relativeQuadraticBezierTo(-8.8, 1.3, -17.6, 0)
    ..relativeQuadraticBezierTo(-1.2, -8.5, 0, -17)
    ..close();

  /// [size] 영역 가운데에 -8° 기울여 맞춘 경로(clip용).
  static Path placedPath(Size size) {
    final scale = size.width / _grid;
    final matrix = Matrix4.identity()
      ..translateByDouble(size.width / 2, size.height / 2, 0, 1)
      ..rotateZ(_rotateDegrees * math.pi / 180)
      ..scaleByDouble(scale, scale, 1, 1)
      ..translateByDouble(-_grid / 2, -_grid / 2, 0, 1);
    return _path().transform(matrix.storage);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / _grid;
    canvas
      ..translate(size.width / 2, size.height / 2)
      ..rotate(_rotateDegrees * math.pi / 180)
      ..scale(scale)
      ..translate(-_grid / 2, -_grid / 2);
    final paint = Paint()
      ..color = color
      ..isAntiAlias = true;
    if (outline) {
      // 테두리 두께는 크기와 관계없이 1.6px입니다.
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = _outlineWidth / scale
        ..strokeJoin = StrokeJoin.round;
    }
    canvas.drawPath(_path(), paint);
  }

  @override
  bool shouldRepaint(_SealPainter old) =>
      old.color != color || old.outline != outline;
}
