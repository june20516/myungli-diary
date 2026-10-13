import 'package:flutter/widgets.dart';

/// 화면 아래에 보이는 하단 틀(탭 바 + 안전 영역 + 광고 배너)의 현재 높이를 하위에 알립니다.
///
/// 화면 셸이 `MyungliBottomBar.onHeightChanged` 값을 이 범위로 넘기면, 토스트 같은
/// 떠 있는 표시가 하단 틀 위에 자리를 잡습니다. 범위가 없으면 하단 틀이 없는 것(0)입니다.
class BottomBarInsetScope extends InheritedWidget {
  /// 하단 틀 높이(px)를 하위에 줍니다.
  const new({required this.height, required super.child, super.key});

  /// 하단 틀 높이. 하단 틀이 없으면 0.
  final double height;

  /// [context] 위의 하단 틀 높이. 범위가 없으면 0입니다.
  static double of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<BottomBarInsetScope>()
          ?.height ??
      0;

  @override
  bool updateShouldNotify(BottomBarInsetScope oldWidget) =>
      height != oldWidget.height;
}
