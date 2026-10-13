import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:myungli_diary/design/interaction/motion_prefs.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';

/// 탭 바·배너 뒤 흐림(px). `frame.json` `tab-bar.container.backdropBlur`.
const double frameBackdropBlur = 20;

/// 탭 바·광고 배너 위 선 두께(px).
const double frameTopBorderWidth = 0.5;

/// 반투명 틀 바탕. 투명도 줄이기면 `bg.sheet` 불투명에 흐림 없음.
class FrameSurface extends StatelessWidget {
  /// 바탕을 만듭니다. [surfaceKey]는 테스트가 색을 읽는 자리입니다.
  const new({required this.surfaceKey, required this.child, super.key});

  /// 바탕 [ColoredBox]에 붙는 키.
  final Key surfaceKey;

  /// 바탕 위에 올릴 내용.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.tokens.colors;
    if (MotionPrefs.of(context).reduceTransparency) {
      return ColoredBox(key: surfaceKey, color: colors.bgSheet, child: child);
    }
    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(
          sigmaX: frameBackdropBlur,
          sigmaY: frameBackdropBlur,
        ),
        child: ColoredBox(key: surfaceKey, color: colors.barBg, child: child),
      ),
    );
  }
}
