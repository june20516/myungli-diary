import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

/// Material 조상이 없을 때 Flutter가 글자에 입히는 오류 스타일(`_errorTextStyle`)의 값.
const double _errorFontSize = 48;
const Color _errorColor = Color(0xD0FF0000);

/// [style]이 Material 오류 스타일(노란 겹밑줄·48 크기·빨간 글자)이 아닌지 봅니다.
///
/// 밑줄만 보면 다른 상속 경로로 크기·색만 오류 값을 받은 경우를 놓치므로 셋을 함께 봅니다.
void expectNoErrorTextStyle(TextStyle? style, {String? reason}) {
  expect(style?.decoration, isNot(TextDecoration.underline), reason: reason);
  expect(style?.fontSize, isNot(_errorFontSize), reason: reason);
  expect(style?.color, isNot(_errorColor), reason: reason);
}
