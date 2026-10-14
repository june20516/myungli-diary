import 'package:flutter/material.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

/// 안내형 화면의 공통 골격. 위쪽 [body]와 아래쪽 [actions] 사이를 비우고,
/// 큰 글자·작은 화면에서는 전체가 스크롤됩니다(잘림 없음).
///
/// 화면이 충분히 크면 [actions]가 바닥에 붙고, 모자라면 [body] 뒤에 이어 붙어
/// 스크롤로 닿습니다.
///
/// 입력 단계 화면은 `InputStep`을 씁니다(키보드 인셋 처리).
class OnboardingPageLayout extends StatelessWidget {
  /// 골격을 만듭니다.
  const new({required this.body, required this.actions, super.key});

  /// 화면 가운데 아래로 놓이는 안내 글.
  final List<Widget> body;

  /// 바닥에 놓이는 버튼들.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: Space.s20),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: IntrinsicHeight(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(),
                ...body,
                const SizedBox(height: Space.s32),
                const Spacer(),
                ...actions,
                const SizedBox(height: Space.s24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
