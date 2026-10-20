import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/app/router/app_router.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/api/fake/fake_server.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations_ko.dart';
import 'package:myungli_diary/design/components/action/primary_button.dart';
import 'package:myungli_diary/design/components/feedback/toast.dart';
import 'package:myungli_diary/features/me/presentation/settings_screen.dart';
import 'package:myungli_diary/features/profile/application/account_delete_controller.dart';
import 'package:myungli_diary/features/profile/presentation/account_delete_screen.dart';
import 'package:myungli_diary/testing/covers.dart';

import '../support/app_bar_title.dart';
import '../support/app_harness.dart';
import '../support/onboarding_steps.dart';
import '../support/profile_network.dart';

final _ko = AppLocalizationsKo();

FakeServerInterceptor _fake(ProviderContainer container) =>
    container.read(fakeServerInterceptorProvider)! as FakeServerInterceptor;

/// 계정 삭제 요청(`DELETE /v1/me`)을 붙잡거나 실패시키는 대역.
ProfileRequestGate _deleteGate({int failures = 0, Completer<void>? gate}) =>
    ProfileRequestGate(
      failures: failures,
      gate: gate,
      method: 'DELETE',
      path: '/v1/me',
    );

/// 회원으로 앱을 띄우고 설정 → 계정 삭제를 엽니다. [network]는 대역 서버 바로 앞에 끼웁니다.
Future<ProviderContainer> _openAccountDelete(
  WidgetTester tester, {
  ProfileRequestGate? network,
}) async {
  final container = await pumpApp(tester, scenario: 'member');
  if (network != null) {
    final interceptors = container.read(dioProvider).interceptors;
    interceptors.insert(interceptors.length - 1, network);
  }
  unawaited(
    container.read(routerProvider).push<void>(pathOf(ScreenIds.settings)),
  );
  await pumpUntilScreen(tester, ScreenIds.settings);
  await settleWithIo(tester);
  await tester.ensureVisible(find.byKey(SettingsScreen.accountDeleteRowKey));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(SettingsScreen.accountDeleteRowKey));
  await pumpUntilScreen(tester, ScreenIds.accountDelete);
  await settleWithIo(tester);
  return container;
}

PrimaryButton _button(WidgetTester tester) =>
    tester.widget<PrimaryButton>(find.byKey(AccountDeleteScreen.deleteKey));

Future<void> _tapDelete(WidgetTester tester) async {
  await tester.tap(find.byKey(AccountDeleteScreen.deleteKey));
  await tester.pumpAndSettle();
}

/// 확인 창의 확정(지우기)을 누릅니다.
Future<void> _confirm(WidgetTester tester) async {
  await tester.tap(find.text(_ko.accountDeleteDeleteConfirmDelete).last);
  await tester.pump();
}

void main() {
  testWidgets('제목·안내·삭제 버튼(destructive)이 있습니다', (tester) async {
    covers(
      const Covers(exits: ['settings>account-delete'], decisions: ['D39']),
    );
    await _openAccountDelete(tester);
    await expectAppBarTitle(
      tester,
      SlotIds.accountDeleteBarTitle,
      _ko.accountDeleteBarTitle,
    );
    expect(
      find.byKey(const ValueKey(SlotIds.accountDeleteTitleHead)),
      findsOneWidget,
    );
    expect(find.text(_ko.accountDeleteTitleHead), findsWidgets);
    expect(find.text(_ko.accountDeleteDataBody), findsOneWidget);
    final button = _button(tester);
    expect(button.label, _ko.accountDeleteCtaDelete);
    expect(button.variant, PrimaryButtonVariant.destructive);
    expect(button.identifier, SlotIds.accountDeleteCtaDelete);
    expect(button.onPressed, isNotNull);
  });

  testWidgets(
    '확인 창에서 취소하면 지우지 않고, 확정하면 deleteMe 한 번 → 로그아웃 정리 → welcome(A63)',
    (tester) async {
      covers(const Covers(exits: ['account-delete>welcome']));
      final container = await _openAccountDelete(tester);

      await _tapDelete(tester);
      expect(find.text(_ko.accountDeleteDeleteConfirm), findsOneWidget);
      expect(
        find.bySemanticsIdentifier(SlotIds.accountDeleteDeleteConfirm),
        findsOneWidget,
      );
      await tester.tap(find.text(_ko.accountDeleteDeleteConfirmCancel));
      await settleWithIo(tester);
      expect(
        find.byKey(const ValueKey(ScreenIds.accountDelete)),
        findsOneWidget,
      );
      expect(_fake(container).callCountOf('deleteMe'), 0);

      await _tapDelete(tester);
      await _confirm(tester);
      await pumpUntilScreen(tester, ScreenIds.welcome);
      await settleWithIo(tester);
      expect(_fake(container).callCountOf('deleteMe'), 1);
      // 로그아웃은 revokeAndSignOut(server logout 시도 뒤 로컬 로그아웃)입니다.
      expect(_fake(container).callCountOf('logout'), 1);
      expect(await container.read(tokenStoreProvider).hasSession(), isFalse);
      // 계정 삭제는 server가 기기를 모두 비활성으로 바꾸므로 따로 부르지 않습니다(계약 draft.11).
      expect(_fake(container).callCountOf('deleteDevice'), 0);
    },
  );

  testWidgets('지우지 못하면 오류 toast이고 화면에 남아, 다시 누르면 다시 시도합니다', (tester) async {
    covers(const Covers(states: ['account-delete:error']));
    final container = await _openAccountDelete(
      tester,
      network: _deleteGate(failures: 1),
    );
    await _tapDelete(tester);
    await _confirm(tester);
    await settleWithIo(tester);

    expect(find.byType(ToastPill), findsOneWidget);
    expect(find.text(_ko.errorServiceUnavailable), findsOneWidget);
    expect(find.byKey(const ValueKey(ScreenIds.accountDelete)), findsOneWidget);
    expect(_fake(container).callCountOf('logout'), 0);
    expect(await container.read(tokenStoreProvider).hasSession(), isTrue);
    expect(_button(tester).loading, isFalse);
    expect(_button(tester).onPressed, isNotNull);

    await tester.pump(const Duration(seconds: 5));
    await settleWithIo(tester);
    await _tapDelete(tester);
    await _confirm(tester);
    await pumpUntilScreen(tester, ScreenIds.welcome);
    await settleWithIo(tester);
    expect(_fake(container).callCountOf('deleteMe'), 1);
  });

  testWidgets('삭제 버튼을 빠르게 두 번 눌러도 확인 창은 하나, 지우는 중에는 눌리지 않아 deleteMe는 한 번입니다', (
    tester,
  ) async {
    final gate = Completer<void>();
    final network = _deleteGate(gate: gate);
    final container = await _openAccountDelete(tester, network: network);

    await tester.tap(find.byKey(AccountDeleteScreen.deleteKey));
    await tester.tap(
      find.byKey(AccountDeleteScreen.deleteKey),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
    expect(find.text(_ko.accountDeleteDeleteConfirm), findsOneWidget);

    await _confirm(tester);
    // 처리 중 점이 숨 쉬어 settle되지 않으므로 창이 닫힐 만큼만 흘립니다.
    await tester.pump(const Duration(seconds: 1));
    // 지우는 중: 버튼은 처리 중 표시이고 누름을 받지 않습니다.
    expect(_button(tester).loading, isTrue);
    await tester.tap(
      find.byKey(AccountDeleteScreen.deleteKey),
      warnIfMissed: false,
    );
    await tester.pump(const Duration(seconds: 1));
    expect(find.text(_ko.accountDeleteDeleteConfirm), findsNothing);

    // controller를 직접 다시 불러도 진행 중인 시도를 함께 기다립니다.
    final again = container
        .read(accountDeleteControllerProvider.notifier)
        .delete();

    gate.complete();
    await pumpUntilScreen(tester, ScreenIds.welcome);
    await settleWithIo(tester);
    await again;
    expect(_fake(container).callCountOf('deleteMe'), 1);
  });
}
