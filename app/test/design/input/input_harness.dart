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
