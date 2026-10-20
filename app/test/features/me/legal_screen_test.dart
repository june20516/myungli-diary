import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/app/entry/entry_providers.dart';
import 'package:myungli_diary/app/router/app_router.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/api/fake/fake_server.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations_ko.dart';
import 'package:myungli_diary/core/platform/external_browser.dart';
import 'package:myungli_diary/core/platform/fakes.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';
import 'package:myungli_diary/design/components/action/settings_row.dart';
import 'package:myungli_diary/design/components/feedback/toast.dart';
import 'package:myungli_diary/features/me/presentation/legal_screen.dart';
import 'package:myungli_diary/testing/covers.dart';

import '../../support/app_bar_title.dart';
import '../../support/app_harness.dart';
import '../../support/onboarding_steps.dart';
import '../../support/profile_network.dart';

final _ko = AppLocalizationsKo();

FakeServerInterceptor _fake(ProviderContainer container) =>
    container.read(fakeServerInterceptorProvider)! as FakeServerInterceptor;

/// 회원으로 앱을 띄우고 `legal`을 엽니다. [network]는 진입 계산 뒤 대역 서버 앞에 끼웁니다.
Future<ProviderContainer> _openLegal(
  WidgetTester tester, {
  List<Override> overrides = const [],
  Interceptor? network,
}) async {
  final container = await pumpApp(
    tester,
    scenario: 'member',
    overrides: overrides,
  );
  if (network != null) {
    final interceptors = container.read(dioProvider).interceptors;
    interceptors.insert(interceptors.length - 1, network);
  }
  unawaited(container.read(routerProvider).push<void>(pathOf(ScreenIds.legal)));
  await pumpUntilScreen(tester, ScreenIds.legal);
  await settleWithIo(tester);
  return container;
}

SettingsRow _row(WidgetTester tester, Key key) =>
    tester.widget<SettingsRow>(find.byKey(key));

Future<void> _tapRow(WidgetTester tester, Key key) async {
  await tester.tap(find.byKey(key));
  await settleWithIo(tester);
}

/// 진입 계산이 받은 앱 설정이 없는 기기(주소를 이 화면이 받아야 함).
final Override _noEntryConfig = entryAppConfigProvider.overrideWithValue(null);

/// 앱 설정 받기(`GET /v1/app-config`)를 붙잡거나 실패시키는 대역.
ProfileRequestGate _configGate({int failures = 0, Completer<void>? gate}) =>
    ProfileRequestGate(
      failures: failures,
      gate: gate,
      method: 'GET',
      path: '/v1/app-config',
    );

void main() {
  testWidgets('제목과 줄 셋: 이용약관·개인정보 처리방침·오픈소스 라이선스(A61)', (tester) async {
    covers(const Covers(decisions: ['D39', 'D80']));
    final container = await _openLegal(tester);
    await expectAppBarTitle(tester, SlotIds.legalBarTitle, _ko.legalBarTitle);

    final rows = tester.widgetList<SettingsRow>(find.byType(SettingsRow));
    expect(
      [for (final row in rows) row.label],
      [_ko.legalTermsLabel, _ko.legalPrivacyLabel, _ko.legalLicensesLabel],
    );
    for (final row in rows) {
      expect(row.variant, SettingsRowVariant.navigate);
      expect(row.onTap, isNotNull);
    }
    // 주소는 진입 계산이 받은 getAppConfig를 다시 씁니다.
    expect(_fake(container).callCountOf('getAppConfig'), 1);
  });

  testWidgets('이용약관·개인정보 처리방침은 화면 언어를 붙여 외부 브라우저로 엽니다(D80)', (tester) async {
    final browser = FakeExternalBrowser();
    await _openLegal(
      tester,
      overrides: [externalBrowserProvider.overrideWithValue(browser)],
    );
    await _tapRow(tester, LegalScreen.termsRowKey);
    await _tapRow(tester, LegalScreen.privacyRowKey);
    expect(browser.opened, [
      Uri.parse('https://example.com/legal/terms?lang=ko'),
      Uri.parse('https://example.com/legal/privacy?lang=ko'),
    ]);
  });

  testWidgets('브라우저를 열지 못하면 오류 toast입니다', (tester) async {
    final browser = FakeExternalBrowser()..failure = const BrowserUnavailable();
    await _openLegal(
      tester,
      overrides: [externalBrowserProvider.overrideWithValue(browser)],
    );
    await _tapRow(tester, LegalScreen.termsRowKey);
    expect(find.byType(ToastPill), findsOneWidget);
    expect(find.text(_ko.errorUnexpected), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await settleWithIo(tester);
  });

  testWidgets('주소를 받는 동안 두 문서 줄은 비활성이고, 받으면 켜집니다', (tester) async {
    final gate = Completer<void>();
    final browser = FakeExternalBrowser();
    final container = await _openLegal(
      tester,
      overrides: [
        _noEntryConfig,
        externalBrowserProvider.overrideWithValue(browser),
      ],
      network: _configGate(gate: gate),
    );
    // push 직후 붙잡힌 요청: 아직 주소가 없습니다.
    expect(_row(tester, LegalScreen.termsRowKey).onTap, isNull);
    expect(_row(tester, LegalScreen.privacyRowKey).onTap, isNull);
    // 오픈소스 라이선스는 주소와 상관없이 눌립니다.
    expect(_row(tester, LegalScreen.licensesRowKey).onTap, isNotNull);

    gate.complete();
    await pumpUntil(
      tester,
      () => _row(tester, LegalScreen.termsRowKey).onTap != null,
    );
    expect(_fake(container).callCountOf('getAppConfig'), 2);
    await _tapRow(tester, LegalScreen.termsRowKey);
    expect(browser.opened.single.toString(), endsWith('/legal/terms?lang=ko'));
  });

  testWidgets('주소를 받지 못하면 오류 toast이고, 두 문서 줄을 누르면 브라우저 대신 다시 받습니다', (
    tester,
  ) async {
    final browser = FakeExternalBrowser();
    final container = await _openLegal(
      tester,
      overrides: [
        _noEntryConfig,
        externalBrowserProvider.overrideWithValue(browser),
      ],
      network: _configGate(failures: 1),
    );
    expect(find.byType(ToastPill), findsOneWidget);
    expect(find.text(_ko.errorServiceUnavailable), findsOneWidget);

    await _tapRow(tester, LegalScreen.privacyRowKey);
    expect(browser.opened, isEmpty);
    expect(_fake(container).callCountOf('getAppConfig'), 2);

    await _tapRow(tester, LegalScreen.privacyRowKey);
    expect(browser.opened, [
      Uri.parse('https://example.com/legal/privacy?lang=ko'),
    ]);
    await tester.pump(const Duration(seconds: 5));
    await settleWithIo(tester);
  });

  testWidgets('오픈소스 라이선스는 showLicensePage이고 GeoNames 고지가 있습니다(#312)', (
    tester,
  ) async {
    await _openLegal(tester);
    // 빠르게 두 번 눌러도 한 번만 엽니다.
    await tester.tap(find.byKey(LegalScreen.licensesRowKey));
    await tester.tap(
      find.byKey(LegalScreen.licensesRowKey),
      warnIfMissed: false,
    );
    await settleWithIo(tester);
    expect(find.byType(LicensePage), findsOneWidget);
    await pumpUntil(tester, () => find.text('GeoNames').evaluate().isNotEmpty);

    Navigator.of(tester.element(find.byType(LicensePage))).pop();
    await settleWithIo(tester);
    expect(find.byType(LicensePage), findsNothing);
    expect(find.byKey(const ValueKey(ScreenIds.legal)), findsOneWidget);
  });
}
