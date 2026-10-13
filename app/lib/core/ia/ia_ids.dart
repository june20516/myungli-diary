import 'package:myungli_diary/core/ia/gen/ia.g.dart';

final Set<String> _screenIdSet = {for (final screen in iaScreens) screen.id};

/// IA 화면 id이면 그대로, 아니면 null. release에서도 거릅니다.
String? sanitizeScreenId(String screenId) =>
    _screenIdSet.contains(screenId) ? screenId : null;
