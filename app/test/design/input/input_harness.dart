import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/theme/app_theme.dart';

/// 입력 컴포넌트 테스트용 앱. 본문은 [Scaffold] 안에 놓습니다.
Widget inputApp(
  Widget child, {
  Locale locale = const Locale('ko'),
  Brightness brightness = Brightness.light,
  bool scaffold = true,
}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: buildTheme(brightness: brightness, locale: locale),
  home: scaffold ? Scaffold(body: child) : Material(child: child),
);

/// 햅틱 호출(`HapticFeedback.vibrate`의 인자)을 모읍니다.
List<String> recordHaptics(WidgetTester tester) {
  final calls = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        calls.add(call.arguments as String);
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  return calls;
}

/// [of] 안에서 `press.ink` 얼룩을 그리는 층을 찾습니다.
Finder inkLayer(Finder of) => find.descendant(
  of: of,
  matching: find.byWidgetPredicate(
    (widget) =>
        widget is CustomPaint &&
        widget.painter.runtimeType.toString() == '_InkPainter',
  ),
);

/// [layer]의 paint 호출 가운데 [predicate]를 만족하는 것이 있는지.
/// 만족하지 않는 호출은 건너뜁니다.
bool paintsWhere(
  WidgetTester tester,
  Finder layer,
  bool Function(Symbol method, List<dynamic> arguments) predicate,
) {
  final pattern = paints..something(predicate);
  final matcher = pattern as Matcher;
  return matcher.matches(tester.renderObject(layer), <dynamic, dynamic>{});
}

/// [layer]가 지금 얼룩 원을 그리고 있는지(`press.ink`의 눌림 상태).
bool paintsInk(WidgetTester tester, Finder layer) =>
    paintsWhere(tester, layer, (method, arguments) => method == #drawCircle);
