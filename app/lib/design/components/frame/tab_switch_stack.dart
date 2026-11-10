import 'package:flutter/widgets.dart';
import 'package:myungli_diary/design/interaction/patterns.dart';

/// 탭 갈래 화면을 겹쳐 두고 `tab.switch`로 바꿉니다(V104, `interaction.json` `tab.switch`).
///
/// [index]가 바뀌면 앞 화면은 투명도 1→0, 새 화면은 0→1로 200ms(`short`, `standard`) 동안
/// 겹치며 바뀝니다. 이동과 크기 변화가 없어 동작 줄이기에서도 같습니다(`opacity-only`).
/// 탭 바는 이 위젯 바깥이라 움직이지 않고, 탭 바 도장과 같은 프레임([index]가 바뀐 build)에
/// 시작합니다.
///
/// * 전환 중에 다른 탭으로 바뀌면 지금 투명도에서 멈추고, 새 탭이 아닌 화면은 모두 그
///   투명도에서 0으로, 새 화면은 지금 투명도(안 보였으면 0)에서 1로 다시 200ms 돌립니다.
///   돌아가는 탭이 이미 반쯤 보이면 0으로 끊지 않고 그 자리에서 이어 올립니다(A122).
/// * 새 화면([index])만 터치를 받고 스크린리더에 보입니다. 앞 화면은 사라지는 동안에도
///   누를 수 없고 읽히지 않습니다.
/// * 보이지 않는 화면은 `Offstage`·`TickerMode` 꺼짐으로 상태(스크롤 위치 등)만 들고
///   있습니다(go_router `indexedStack`과 같음). 사라지는 동안(투명도가 0보다 큼)은 앞 화면의
///   애니메이션도 계속 움직여, 멈춘 프레임이 흐려지지 않게 합니다.
///
/// 같은 [index]로 다시 그리면 아무 일도 없습니다(이미 선택된 탭 다시 누름은 탭 바가 맨
/// 위로 올리기만 합니다).
class TabSwitchStack extends StatefulWidget {
  /// [children] 가운데 [index] 화면을 보입니다.
  const new({required this.index, required this.children, super.key});

  /// 지금 탭.
  final int index;

  /// 탭 순서의 갈래 화면.
  final List<Widget> children;

  @override
  State<TabSwitchStack> createState() => _TabSwitchStackState();
}

class _TabSwitchStackState extends State<TabSwitchStack>
    with SingleTickerProviderStateMixin {
  static const InteractionPattern _pattern = InteractionPattern.tabSwitch;

  /// 0→1 선형 진행. 처음에는 끝난 상태(1)라 지금 탭 화면만 보입니다.
  late final AnimationController _progress = AnimationController(
    vsync: this,
    duration: _pattern.duration,
    value: 1,
  );

  /// 이번 전환을 시작할 때 화면마다의 투명도. 없으면 0입니다.
  Map<int, double> _from = const {};

  @override
  void didUpdateWidget(TabSwitchStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index == widget.index) return;
    // 진행 중인 전환을 지금 투명도에서 멈추고, 거기서 새 전환을 시작합니다.
    _from = {
      for (var i = 0; i < widget.children.length; i++)
        i: _opacityOf(i, target: oldWidget.index),
    };
    _progress.forward(from: 0);
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  /// [target] 탭으로 가는 전환의 지금 진행에서 [i] 화면의 투명도.
  double _opacityOf(int i, {required int target}) {
    final to = i == target ? 1.0 : 0.0;
    final from = _from[i] ?? 0;
    final eased = _pattern.curve.transform(_progress.value);
    return from + (to - from) * eased;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _progress,
      builder: (context, _) => Stack(
        fit: StackFit.expand,
        children: [
          for (var i = 0; i < widget.children.length; i++)
            _branch(i, widget.children[i]),
        ],
      ),
    );
  }

  Widget _branch(int i, Widget child) {
    final current = i == widget.index;
    final opacity = _opacityOf(i, target: widget.index);
    return Offstage(
      offstage: !current && opacity == 0,
      child: TickerMode(
        enabled: current || opacity > 0,
        child: IgnorePointer(
          ignoring: !current,
          child: ExcludeSemantics(
            excluding: !current,
            child: Opacity(opacity: opacity, child: child),
          ),
        ),
      ),
    );
  }
}
