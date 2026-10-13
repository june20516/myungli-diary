import 'package:flutter/widgets.dart';
import 'package:myungli_diary/app/router/placeholder_screen.dart';
import 'package:myungli_diary/app/screens/launch_screen.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/ia/ia_model.dart';

/// 화면 하나의 등록 정보.
final class ScreenSpec {
  /// [id] 화면을 [builder]로 만듭니다.
  const new(this.id, this.builder, {this.handledStates = const {}});

  /// IA 화면 id.
  final String id;

  /// 화면 본체를 만듭니다.
  final WidgetBuilder builder;

  /// 이 화면이 직접 처리하는 IA 상태 id. 기반 단계에서는 비어 있습니다.
  final Set<String> handledStates;
}

/// page 화면 registry. 시트·system 화면은 route가 없어 넣지 않습니다.
/// 기반에서는 모두 [PlaceholderScreen]이고, 화면 task가 하나씩 교체합니다.
final Map<String, ScreenSpec> screenRegistry = {
  for (final screen in iaScreens)
    // launch는 아래에서 본체로 등록합니다.
    if (screen.presentation == IaPresentation.page &&
        screen.id != ScreenIds.launch)
      screen.id: ScreenSpec(
        screen.id,
        (context) => PlaceholderScreen(screen.id),
      ),
  ScreenIds.launch: const ScreenSpec(
    ScreenIds.launch,
    _buildLaunch,
    handledStates: launchHandledStates,
  ),
};

Widget _buildLaunch(BuildContext context) => const LaunchScreen();
