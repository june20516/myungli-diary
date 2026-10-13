import 'package:myungli_diary/core/ia/gen/ia.g.dart';

final Map<String, Set<String>> _componentsByScreen = {
  for (final screen in iaScreens) screen.id: screen.components.toSet(),
};

/// IA 슬롯 id가 속한 화면 id(첫 마디). 예: `today.fortune.body` → `today`.
String screenIdOfSlot(String slotId) => slotId.split('.').first;

/// IA 화면 [screenId]의 components에 [componentId]가 있는지. 없는 화면이면 false입니다.
bool screenHasComponent(String screenId, String componentId) =>
    _componentsByScreen[screenId]?.contains(componentId) ?? false;
