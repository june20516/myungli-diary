import 'package:flutter/widgets.dart';
import 'package:myungli_diary/design/interaction/motion_prefs.dart';
import 'package:myungli_diary/design/interaction/patterns.dart';

/// [changeKey]가 바뀔 때만 [child]를 `appear.seep`으로 다시 스미게 합니다.
///
/// 처음 그릴 때는 움직이지 않습니다(나타남은 바깥 [SeepPresence] 등이 맡음). 캐시를 먼저 보이고
/// server 응답으로 바꾸는 화면이 씁니다: 내용이 같으면 [changeKey]도 같아 그대로 두고, 다르면
/// 튀지 않게 스밉니다. 트리 모양이 바뀌지 않으므로 [child]의 상태(열린 칩 등)는 유지됩니다.
/// 동작 줄이기 설정이면 투명도만 바뀝니다(`appear.seep` 규칙).
///
/// [SeepPresence]: package:myungli_diary/design/components/feedback/seep_presence.dart
class SeepOnChange extends StatefulWidget {
  /// [changeKey]가 바뀌면 [child]를 다시 스미게 합니다.
  const new({required this.changeKey, required this.child, super.key});

  /// 내용을 나타내는 값. `==`로 비교합니다.
  final Object? changeKey;

  /// 보일 내용.
  final Widget child;

  @override
  State<SeepOnChange> createState() => _SeepOnChangeState();
}

class _SeepOnChangeState extends State<SeepOnChange>
    with SingleTickerProviderStateMixin {
  // 처음에는 끝난 상태(1)라 움직이지 않습니다.
  late final AnimationController _seep = AnimationController(
    vsync: this,
    duration: InteractionPattern.appearSeep.duration,
    value: 1,
  );

  @override
  void didUpdateWidget(SeepOnChange oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.changeKey != oldWidget.changeKey) {
      _seep.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _seep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => animate(
    InteractionPattern.appearSeep,
    t: _seep,
    prefs: MotionPrefs.of(context),
    child: widget.child,
  );
}
