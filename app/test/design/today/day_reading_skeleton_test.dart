import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/today/day_reading_skeleton.dart';
import 'package:myungli_diary/design/elements/skeleton_bone.dart';
import 'package:myungli_diary/design/theme/app_theme.dart';

Widget _app(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: buildTheme(brightness: Brightness.light, locale: const Locale('ko')),
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  testWidgets('배지·문장 3줄·칩 4개·질문 카드 자리입니다', (tester) async {
    await tester.pumpWidget(_app(const DayReadingSkeleton()));
    expect(find.byType(SkeletonBone), findsNWidgets(1 + 3 + 4 + 1));
  });

  testWidgets('guideCard가 false면 질문 카드 자리를 두지 않습니다(day-sheet)', (tester) async {
    await tester.pumpWidget(_app(const DayReadingSkeleton(guideCard: false)));
    expect(find.byType(SkeletonBone), findsNWidgets(1 + 3 + 4));
  });
}
