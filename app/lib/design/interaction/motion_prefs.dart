import 'package:flutter/widgets.dart';

/// 움직임 대체 규칙(`interaction.json` `fallbacks`)이 읽는 기기 설정 묶음.
@immutable
final class MotionPrefs {
  /// 설정 묶음을 만듭니다.
  const new({
    required this.reduceMotion,
    required this.reduceTransparency,
    required this.lowEnd,
  });

  /// [MediaQuery]에서 기기 설정을 읽습니다.
  ///
  /// [MotionPrefsScope]가 위에 있으면 그 값을 먼저 씁니다.
  /// Flutter에는 투명도 줄이기 전용 값이 없어 대비 높이기(`highContrast`)를
  /// 대신 읽습니다. 저사양 판단은 기기에서 알 수 없으므로 기본은 false입니다.
  factory of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<MotionPrefsScope>();
    if (scope != null) return scope.prefs;
    return MotionPrefs(
      reduceMotion: MediaQuery.disableAnimationsOf(context),
      reduceTransparency: MediaQuery.highContrastOf(context),
      lowEnd: false,
    );
  }

  /// 동작 줄이기: 이동·크기·흐림을 빼고 투명도만 남깁니다.
  final bool reduceMotion;

  /// 투명도 줄이기: 반투명 탭 바를 불투명 `bg.sheet`로 바꿉니다.
  final bool reduceTransparency;

  /// 저사양 기기: 패턴의 `lowEnd` 값대로 흐림을 뺍니다.
  final bool lowEnd;
}

/// 하위 트리의 [MotionPrefs]를 정합니다. 저사양 감지 결과를 싣거나 Widgetbook·테스트에서 씁니다.
class MotionPrefsScope extends InheritedWidget {
  /// 범위를 만듭니다.
  const new({required this.prefs, required super.child, super.key});

  /// 하위에 줄 설정.
  final MotionPrefs prefs;

  @override
  bool updateShouldNotify(MotionPrefsScope oldWidget) =>
      prefs.reduceMotion != oldWidget.prefs.reduceMotion ||
      prefs.reduceTransparency != oldWidget.prefs.reduceTransparency ||
      prefs.lowEnd != oldWidget.prefs.lowEnd;
}
