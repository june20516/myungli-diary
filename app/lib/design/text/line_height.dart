import 'package:flutter/painting.dart';

/// [style]·[scaler](기기 글자 크기)로 그린 글줄 하나의 높이.
double lineHeightOf(TextStyle style, TextScaler scaler) {
  final painter = TextPainter(
    text: TextSpan(text: '0', style: style),
    textDirection: TextDirection.ltr,
    textScaler: scaler,
    maxLines: 1,
  )..layout();
  final height = painter.height;
  painter.dispose();
  return height;
}
