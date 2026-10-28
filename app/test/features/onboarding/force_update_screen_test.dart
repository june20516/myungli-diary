import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations_ko.dart';
import 'package:myungli_diary/core/platform/fakes.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';
import 'package:myungli_diary/core/platform/store_launcher.dart';

import '../../support/app_harness.dart';

final _ko = AppLocalizationsKo();

void main() {
  testWidgets('force-update 버튼은 스토어를 엽니다', (tester) async {
    final container = await pumpApp(tester, scenario: 'force-update');

    expect(find.byKey(const ValueKey(ScreenIds.forceUpdate)), findsOneWidget);
    expect(
      find.byKey(const ValueKey(SlotIds.forceUpdateNoticeHead)),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey(SlotIds.forceUpdateNoticeBody)),
      findsOneWidget,
    );
    // 버전 사유의 이유 문장입니다(W45).
    expect(find.text(_ko.forceUpdateNoticeBody), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey(SlotIds.forceUpdateCtaStore)));
    await tester.pump();
    final launcher = container.read(storeLauncherProvider) as FakeStoreLauncher;
    expect(launcher.opened, 1);
  });

  testWidgets('스토어를 열지 못하면 toast로 알리고 다시 누를 수 있습니다', (tester) async {
    final container = await pumpApp(tester, scenario: 'force-update');
    final launcher = container.read(storeLauncherProvider) as FakeStoreLauncher
      ..failure = const StoreUnavailable();

    await tester.tap(find.byKey(const ValueKey(SlotIds.forceUpdateCtaStore)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(launcher.opened, 1);
    expect(find.text(_ko.errorUnexpected), findsOneWidget);
    expect(
      (container.read(
        crashReporterProvider,
      ) as FakeCrashReporter).errors.single.errorType,
      'StoreUnavailable',
    );

    // toast가 사라지면 다시 누를 수 있습니다.
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
    launcher.failure = null;
    await tester.tap(find.byKey(const ValueKey(SlotIds.forceUpdateCtaStore)));
    await tester.pump();
    expect(launcher.opened, 2);
  });

  testWidgets('시스템 뒤로 가기를 앱이 삼켜 화면을 벗어날 수 없습니다', (tester) async {
    await pumpApp(tester, scenario: 'force-update');

    // 막히지 않았다면 루트 라우트라 false(앱 종료로 넘김)가 돌아옵니다.
    final handled = await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(handled, isTrue);
    expect(find.byKey(const ValueKey(ScreenIds.forceUpdate)), findsOneWidget);
  });

  testWidgets('큰 글자·작은 화면에서도 넘치지 않고 버튼에 닿습니다', (tester) async {
    for (final scale in [2.0, 3.0]) {
      tester.view
        ..physicalSize = const Size(320, 568)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpApp(tester, scenario: 'force-update');

      final button = find.byKey(const ValueKey(SlotIds.forceUpdateCtaStore));
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '글자 배율 $scale');
      expect(button, findsOneWidget);
    }
  });
}
