import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';

/// 시트를 여는 누름. 시트를 열면 시트가 닫힐 때 끝나는 [Future]를 돌려줍니다. 돌려주지
/// 않으면(void) 열림 표시가 없습니다.
typedef SheetTap = FutureOr<void> Function();

/// 용어([termId])를 눌러 시트를 엽니다. [SheetTap]과 같이 시트 Future를 돌려주면 그 용어에
/// 열림 표시가 남습니다.
typedef TermTap = FutureOr<void> Function(String termId);

/// 요소 `open.ring`(V129): 누른 칩이나 용어에 그 시트가 열린 동안 남는 테두리.
///
/// 안쪽 1.5px `action.primary`이고 안쪽에 그려 칩 크기와 글자 자리는 그대로입니다. `hanja-tag`
/// `selected`, `term-token` `open`, `lucky-card` `open`, 달력 규칙 입구 `openState`가
/// 씁니다.
/// 따로 움직이지 않고 시트가 열리고 닫히는 프레임에 바뀌며, 스크린리더는 읽지 않습니다.
abstract final class OpenRing {
  /// 테두리 굵기(`open.ring.border.width`).
  static const double width = 1.5;

  /// 칩 테두리. `BoxDecoration.border`에 넣습니다(기본 `strokeAlign`이 안쪽).
  static Border border(BuildContext context) =>
      Border.all(color: context.tokens.colors.actionPrimary, width: width);
}

/// [SheetOpenTracker]가 칩에 넘기는 값: 지금 열림 표시를 그릴지와 칩에 다는 누름.
final class SheetOpenState {
  /// 열림 여부와 누름을 묶습니다.
  const new({required this.open, required this.onTap});

  /// 누름이 연 시트가 아직 열려 있는지.
  final bool open;

  /// 칩에 그대로 다는 누름. 누를 수 없으면 null입니다.
  final VoidCallback? onTap;
}

/// 누름이 연 시트가 열린 동안 [SheetOpenState.open]을 true로 [builder]에 넘깁니다
/// (`open.ring.while`).
///
/// 칩마다 열림 상태를 쓰는 쪽에서 들고 있지 않아도 되도록, [onTap]이 돌려준 [Future]가 끝날
/// 때(시트가 닫힐 때)까지 이 위젯이 기억합니다. 위에 다른 시트가 쌓여도 아래 화면은 그대로라
/// 표시가 남습니다. [onTap]이 null이면 누를 수 없습니다.
class SheetOpenTracker extends StatefulWidget {
  /// 누름과 열림 표시를 잇습니다.
  const new({required this.onTap, required this.builder, super.key});

  /// 시트를 여는 누름.
  final SheetTap? onTap;

  /// 칩을 그립니다.
  final Widget Function(BuildContext context, SheetOpenState state) builder;

  @override
  State<SheetOpenTracker> createState() => _SheetOpenTrackerState();
}

class _SheetOpenTrackerState extends State<SheetOpenTracker> {
  /// 아직 닫히지 않은 시트 수. 닫히기 전에 다시 눌러도 마지막 시트가 닫힐 때 풀립니다.
  int _pending = 0;

  void _tap() {
    final result = widget.onTap?.call();
    if (result is! Future<void>) return;
    setState(() => _pending++);
    unawaited(
      result.whenComplete(() {
        if (mounted) setState(() => _pending--);
      }),
    );
  }

  @override
  Widget build(BuildContext context) => widget.builder(
    context,
    SheetOpenState(
      open: _pending > 0,
      onTap: widget.onTap == null ? null : _tap,
    ),
  );
}
