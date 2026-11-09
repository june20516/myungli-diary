import 'package:flutter/material.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

/// 두 버튼 묶음(`button.pair`, V60): 세로로 쌓고 주 버튼([filled])이 위, [quiet]가 아래입니다.
///
/// 사이는 `space.8`, 너비는 채웁니다. 가로 배치는 쓰지 않습니다. 확인 창의 두 버튼은
/// dialog 규칙(V65)을 따르므로 이 묶음을 쓰지 않습니다.
class ButtonPair extends StatelessWidget {
  /// 두 버튼을 위아래로 놓습니다.
  const new({required this.filled, required this.quiet, super.key});

  /// 위 버튼(주 동작).
  final Widget filled;

  /// 아래 버튼(보조 동작).
  final Widget quiet;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      filled,
      const SizedBox(height: Space.s8),
      quiet,
    ],
  );
}
