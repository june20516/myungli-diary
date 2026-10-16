import 'package:flutter/widgets.dart';
import 'package:myungli_diary/design/interaction/patterns.dart';

/// `press.ink`의 눌림·뗌 controller와 번지는 기점을 묶은 State mixin.
///
/// [pressInk]·[pressInkRelease]·[pressInkOrigin]을 `press.ink` 패턴(`animate`)의
/// `t`·`PatternOptions.release`·`origin`에 넘기고, 제스처에서 [pressInkDown]·
/// [pressInkUp]을 부릅니다. 손을 떼는 애니메이션이 끝나면 눌림을 0으로 되돌립니다. controller는 이 mixin이
/// 정리하므로, 쓰는 State는 `TickerProviderStateMixin` 다음에 이 mixin을 섞습니다.
mixin PressInkState<T extends StatefulWidget> on State<T>, TickerProvider {
  /// 눌림 진행(0~1).
  late final AnimationController pressInk = AnimationController(
    vsync: this,
    duration: InteractionPattern.pressInk.duration,
  );

  /// 뗌 진행(0~1). 끝나면 [pressInk]를 0으로 돌립니다.
  late final AnimationController pressInkRelease = AnimationController(
    vsync: this,
    duration: pressInkReleaseDuration,
  )..addStatusListener(_onPressInkReleased);

  /// 얼룩이 번지는 기점(누른 자리). 크기를 모르면 가운데입니다.
  Alignment pressInkOrigin = Alignment.center;

  void _onPressInkReleased(AnimationStatus status) {
    if (status == AnimationStatus.completed) pressInk.value = 0;
  }

  /// 누른 자리에서 눌림을 시작합니다. 기점은 이 위젯 크기 안의 [details] 위치입니다.
  void pressInkDown(TapDownDetails details) {
    final size = context.size;
    pressInkOrigin = size == null || size.isEmpty
        ? Alignment.center
        : Alignment(
            details.localPosition.dx / size.width * 2 - 1,
            details.localPosition.dy / size.height * 2 - 1,
          );
    pressInkRelease.value = 0;
    pressInk.forward(from: 0);
  }

  /// 손을 떼거나 취소했을 때 얼룩을 걷습니다.
  void pressInkUp() => pressInkRelease.forward(from: 0);

  @override
  void dispose() {
    pressInk.dispose();
    pressInkRelease.dispose();
    super.dispose();
  }
}
