import 'package:flutter/widgets.dart';
import 'package:myungli_diary/design/interaction/motion_prefs.dart';
import 'package:myungli_diary/design/interaction/patterns.dart';

/// [present]가 true가 되면 `appear.seep`으로 나타나고, false가 되면 `disappear.seep`으로
/// 사라진 뒤 자리를 비웁니다. 처음부터 false면 아무것도 그리지 않습니다.
///
/// toast·notice-banner처럼 상태가 풀리면 저절로 사라지는 표시가 함께 씁니다.
/// [animateInitial]이 false면 처음부터 [present]일 때 움직임 없이 다 나타난 상태로
/// 시작합니다(화면을 열 때 이미 있던 값은 스미지 않고, 연 뒤에 생긴 값만 스밉니다).
class SeepPresence extends StatefulWidget {
  /// 나타남·사라짐을 입힙니다. 사라짐이 끝나면 [onGone]이 불립니다.
  const new({
    required this.present,
    required this.child,
    this.onGone,
    this.animateInitial = true,
    super.key,
  });

  /// 보여야 하는지.
  final bool present;

  /// 보일 내용.
  final Widget child;

  /// 사라짐이 끝났을 때.
  final VoidCallback? onGone;

  /// 처음부터 [present]일 때도 `appear.seep`으로 나타날지. false면 끝난 상태로 시작합니다.
  final bool animateInitial;

  @override
  State<SeepPresence> createState() => _SeepPresenceState();
}

enum _Phase { hidden, showing, hiding }

class _SeepPresenceState extends State<SeepPresence>
    with TickerProviderStateMixin {
  late final AnimationController _in = AnimationController(
    vsync: this,
    duration: InteractionPattern.appearSeep.duration,
  );
  late final AnimationController _out = AnimationController(
    vsync: this,
    duration: InteractionPattern.disappearSeep.duration,
  )..addStatusListener(_onOutStatus);

  _Phase _phase = _Phase.hidden;

  @override
  void initState() {
    super.initState();
    if (!widget.present) return;
    if (widget.animateInitial) {
      _show();
    } else {
      _phase = _Phase.showing;
      _in.value = 1;
    }
  }

  @override
  void didUpdateWidget(SeepPresence oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.present == oldWidget.present) return;
    if (widget.present) {
      _show();
    } else if (_phase == _Phase.showing) {
      _phase = _Phase.hiding;
      _out.forward(from: 0);
    }
  }

  void _show() {
    _out.stop();
    _phase = _Phase.showing;
    _in.forward(from: 0);
  }

  void _onOutStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;
    setState(() => _phase = _Phase.hidden);
    widget.onGone?.call();
  }

  @override
  void dispose() {
    _in.dispose();
    _out.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prefs = MotionPrefs.of(context);
    return switch (_phase) {
      _Phase.hidden => const SizedBox.shrink(),
      _Phase.showing => animate(
        InteractionPattern.appearSeep,
        t: _in,
        prefs: prefs,
        child: widget.child,
      ),
      _Phase.hiding => animate(
        InteractionPattern.disappearSeep,
        t: _out,
        prefs: prefs,
        child: widget.child,
      ),
    };
  }
}
