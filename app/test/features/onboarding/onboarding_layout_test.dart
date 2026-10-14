import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/app/router/app_router.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/design/components/action/primary_button.dart';

import '../../support/app_harness.dart';

Future<void> _open(
  WidgetTester tester,
  ProviderContainer container,
  String screenId,
) async {
  unawaited(container.read(routerProvider).push<void>(pathOf(screenId)));
  await tester.pumpAndSettle();
}

void main() {
  for (final screenId in [ScreenIds.onboardCall, ScreenIds.onboardBirth]) {
    for (final scale in [1.0, 2.0, 3.0]) {
      for (final keyboard in [0.0, 280.0]) {
        testWidgets('$screenId: 글자 $scale배·키보드 $keyboard에서 넘치지 않고 버튼에 닿습니다', (
          tester,
        ) async {
          tester.view
            ..physicalSize = const Size(320, 568)
            ..devicePixelRatio = 1
            ..viewInsets = FakeViewPadding(bottom: keyboard);
          addTearDown(tester.view.reset);
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final container = await pumpApp(tester, scenario: 'new-user');
          await _open(tester, container, screenId);

          expect(tester.takeException(), isNull);
          final button = find.byType(PrimaryButton);
          expect(button, findsOneWidget);
          // 버튼이 화면 안에 있고(키보드가 열렸으면 키보드 위), 스크롤 없이 닿습니다.
          final bottom = tester.getBottomLeft(button).dy;
          expect(bottom, lessThanOrEqualTo(568 - keyboard));
          expect(tester.getTopLeft(button).dy, greaterThanOrEqualTo(0));
        });
      }
    }
  }
}
