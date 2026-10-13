import 'package:flutter/material.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

/// 디자인 토큰(색·글자·그라데이션)을 [ThemeData]에 싣는 확장.
///
/// 위젯은 `context.tokens`로 의미 역할 토큰만 읽습니다.
@immutable
final class MyungliTokens extends ThemeExtension<MyungliTokens> {
  /// 토큰 묶음을 만듭니다.
  const new({
    required this.colors,
    required this.typography,
    required this.gradients,
  });

  /// 의미 역할 색.
  final ColorTokens colors;

  /// 글자 스타일. `ThemeExtension.type`과 겹쳐 `typography`라고 부릅니다.
  final TypeTokens typography;

  /// 그라데이션.
  final GradientTokens gradients;

  @override
  MyungliTokens copyWith({
    ColorTokens? colors,
    TypeTokens? typography,
    GradientTokens? gradients,
  }) {
    return MyungliTokens(
      colors: colors ?? this.colors,
      typography: typography ?? this.typography,
      gradients: gradients ?? this.gradients,
    );
  }

  /// 토큰은 보간하지 않고 절반을 넘으면 다음 값으로 바꿉니다.
  @override
  MyungliTokens lerp(ThemeExtension<MyungliTokens>? other, double t) {
    if (other is! MyungliTokens) return this;
    return t < 0.5 ? this : other;
  }
}

/// `context.tokens`로 현재 테마의 토큰을 읽습니다.
extension TokensContext on BuildContext {
  /// 현재 테마의 [MyungliTokens].
  MyungliTokens get tokens => Theme.of(this).extension<MyungliTokens>()!;
}
