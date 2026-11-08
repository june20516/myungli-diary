import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:myungli_diary/design/interaction/motion_prefs.dart';
import 'package:myungli_diary/design/interaction/patterns.dart';

/// 화면 쌓기 이동(push, pop)에 `page.push`를 입히는 전환(V67, A110).
///
/// 새 화면이 오른쪽 24px에서 밀려 들어오며 나타나고, 뒤 화면은 그대로입니다. 뒤로 가기는
/// 같은 움직임을 거꾸로 재생합니다. 동작 줄이기에서는 투명도만 바뀝니다.
///
/// `ThemeData.pageTransitionsTheme`에 Android와 iOS 모두 이 builder 하나를 둡니다. 탭 사이
/// 이동(셸 branch 전환)과 시트(자체 route)는 이 전환을 거치지 않습니다.
///
/// iOS에서는 왼쪽 가장자리를 밀어 뒤로 가는 동작을 남깁니다. 그 인식기는 Flutter가 공개하지
/// 않으므로 [CupertinoRouteTransitionMixin.buildPageTransitions]를 진행 1(끝), 아래 화면
/// 진행 0으로 고정해 불러, Cupertino 자체 이동은 없이 인식기만 감싸 씁니다. 밀기 동안의 진행은
/// route의 animation이 받으므로 이 전환이 손가락을 따라 거꾸로 재생됩니다.
class PagePushTransitionsBuilder extends PageTransitionsBuilder {
  /// 전환을 만듭니다.
  const new();

  @override
  Duration get transitionDuration => InteractionPattern.pagePush.duration;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final page = Theme.of(context).platform == TargetPlatform.iOS
        ? CupertinoRouteTransitionMixin.buildPageTransitions<T>(
            route,
            context,
            kAlwaysCompleteAnimation,
            kAlwaysDismissedAnimation,
            child,
          )
        : child;
    return animatePagePush(
      t: animation,
      prefs: MotionPrefs.of(context),
      child: page,
    );
  }
}
