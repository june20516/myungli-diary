import 'package:flutter/widgets.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/css_gradient.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

/// 요소 `unlock.mark`(열린 구역 표시, D118 ②, V112)의 값.
///
/// 동작 줄이기에서 `unlock.glint` 대신 그립니다. 구역 제목 글자는 [UnlockMarkTitle],
/// 구역 왼쪽 세로선은 [UnlockMarkRule]입니다. 장식이라 스크린리더는 읽지 않습니다.
abstract final class UnlockMark {
  /// 세로선 굵기(`rule.width`, px).
  static const double ruleWidth = 2;

  /// 세로선 자리(`rule.offsetStart`, px): 구역 시작 쪽 밖 12.
  static const double ruleOffsetStart = -12;

  /// 세로선 그라데이션 각도(`rule.angle`, CSS 도): 위에서 아래로.
  static const double ruleAngle = 180;
}

/// 구역 제목 글자를 `gradient.unlocked`로 칠합니다(`unlock.mark` `title`).
///
/// 글자 모양 안에만 칠하고(글자색 대신) 배치와 크기는 그대로입니다.
class UnlockMarkTitle extends StatelessWidget {
  /// [child] 글자를 그라데이션으로 칠합니다.
  const new({required this.child, super.key});

  /// 구역 제목 글자.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final gradient = context.tokens.gradients.unlocked;
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: gradient.createShader,
      child: child,
    );
  }
}

/// 구역 시작 쪽 밖 12에 2px `gradient.unlocked` 세로선을 둡니다(`unlock.mark` `rule`).
///
/// 선은 [child]의 위(구역 제목 첫 줄 위)에서 아래(구역 본문 끝)까지이고, [child]의 배치는
/// 움직이지 않습니다. 선은 [child] 밖에 그려지므로 부모가 그 자리를 자르지 않아야 합니다
/// (근거 시트는 안쪽 여백 24 안에 그립니다).
class UnlockMarkRule extends StatelessWidget {
  /// [child] 구역 옆에 세로선을 둡니다.
  const new({required this.child, super.key});

  /// 세로선을 찾는 테스트용 키.
  static const Key ruleKey = ValueKey('unlock.mark.rule');

  /// 구역(제목과 본문).
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final gradient = context.tokens.gradients.unlocked.atCssAngle(
      UnlockMark.ruleAngle,
    );
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        PositionedDirectional(
          start: UnlockMark.ruleOffsetStart,
          top: 0,
          bottom: 0,
          width: UnlockMark.ruleWidth,
          child: ExcludeSemantics(
            child: DecoratedBox(
              key: ruleKey,
              decoration: BoxDecoration(
                gradient: gradient,
                borderRadius: BorderRadius.circular(Radii.full),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
