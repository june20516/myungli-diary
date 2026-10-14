import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

void main() {
  const cases = [
    (Locale('fr', 'FR'), 'en'),
    (Locale('ja', 'JP'), 'ja'),
    (Locale('ko', 'KR'), 'ko'),
  ];
  for (final (device, expected) in cases) {
    testWidgets('기기 $device 이면 화면 언어는 $expected 이다', (tester) async {
      await pumpApp(tester, scenario: 'new-user', locale: device);
      final context = tester.element(find.byType(Navigator).first);
      expect(Localizations.localeOf(context).languageCode, expected);
    });
  }
}
