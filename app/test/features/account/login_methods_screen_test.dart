import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:myungli_diary/app/router/app_router.dart';
import 'package:myungli_diary/core/api/gen/model/login_provider.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations_ko.dart';
import 'package:myungli_diary/design/components/action/primary_button.dart';
import 'package:myungli_diary/design/components/action/social_login_button.dart';
import 'package:myungli_diary/design/theme/app_theme.dart';
import 'package:myungli_diary/features/account/data/account_link_repository.dart';
import 'package:myungli_diary/features/account/presentation/login_methods_screen.dart';

import '../../support/app_bar_title.dart';
import 'fake_identity_api.dart';

final _ko = AppLocalizationsKo();

/// 합치기 화면 자리에 놓는 시험용 화면. 화면 본체는 account-merge 작업이 확인합니다.
const Key _mergeBackKey = ValueKey('test.merge.back');

/// 화면을 띄우고 `account-merge`로 push된 위치를 기록합니다.
final class _Harness {
  new(this.api, this.pushed);

  final FakeIdentityApi api;

  /// 합치기 자리로 push된 위치 기록.
  final List<String> pushed;
}

Future<_Harness> _pump(
  WidgetTester tester, {
  List<LoginProvider>? identities,
  Locale locale = const Locale('ko'),
  FakeIdentityApi? api,
  double textScale = 1.0,
}) async {
  final server = api ?? FakeIdentityApi(identities: identities);
  final pushed = <String>[];
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const LoginMethodsScreen()),
      GoRoute(
        path: pathOf(ScreenIds.accountMerge),
        builder: (context, state) {
          pushed.add(state.uri.path);
          return Scaffold(
            body: TextButton(
              key: _mergeBackKey,
              onPressed: () => context.pop(),
              child: const Text('back'),
            ),
          );
        },
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        accountLinkRepositoryProvider.overrideWithValue(
          AccountLinkRepository(server),
        ),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        locale: locale,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        theme: buildTheme(brightness: Brightness.light, locale: locale),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return _Harness(server, pushed);
}

Finder _button(SocialProvider provider) => find.byWidgetPredicate(
  (w) => w is SocialLoginButton && w.provider == provider,
);

SocialLoginButton _widget(WidgetTester tester, SocialProvider provider) =>
    tester.widget<SocialLoginButton>(_button(provider));

List<SocialProvider> _shownOrder(WidgetTester tester) {
  final buttons = tester.widgetList<SocialLoginButton>(
    find.byType(SocialLoginButton),
  );
  final sorted = buttons.toList()
    ..sort(
      (a, b) => tester
          .getTopLeft(find.byWidget(a))
          .dy
          .compareTo(tester.getTopLeft(find.byWidget(b)).dy),
    );
  return [for (final button in sorted) button.provider];
}

Finder get _mergeCta => find.byKey(LoginMethodsScreen.mergeCtaKey);

void main() {
  testWidgets('app-bar 제목은 login-methods.bar.title 슬롯', (tester) async {
    await _pump(tester);
    await expectAppBarTitle(
      tester,
      SlotIds.loginMethodsBarTitle,
      _ko.loginMethodsBarTitle,
    );
  });

  group('줄', () {
    final orders = {
      'ko': [
        SocialProvider.kakao,
        SocialProvider.line,
        SocialProvider.google,
        SocialProvider.apple,
      ],
      'ja': [
        SocialProvider.line,
        SocialProvider.kakao,
        SocialProvider.google,
        SocialProvider.apple,
      ],
      'en': [
        SocialProvider.google,
        SocialProvider.kakao,
        SocialProvider.line,
        SocialProvider.apple,
      ],
    };
    for (final entry in orders.entries) {
      testWidgets('${entry.key}: 네 줄이 loginProviderOrder 순서', (tester) async {
        await _pump(tester, locale: Locale(entry.key));
        expect(_shownOrder(tester), entry.value);
      });
    }

    testWidgets('연결된 줄은 connected(연결됨), 연결 안 된 줄은 그 제공자 로그인 버튼', (
      tester,
    ) async {
      await _pump(
        tester,
        identities: [LoginProvider.kakao, LoginProvider.google],
      );
      for (final provider in [SocialProvider.kakao, SocialProvider.google]) {
        final button = _widget(tester, provider);
        expect(button.connected, isTrue);
        expect(button.connectedLabel, _ko.loginMethodsRowConnected);
      }
      expect(
        _widget(tester, SocialProvider.kakao).label,
        _ko.loginProviderKakao,
      );
      expect(
        _widget(tester, SocialProvider.google).label,
        _ko.loginProviderGoogle,
      );
      expect(_widget(tester, SocialProvider.line).connected, isFalse);
      expect(_widget(tester, SocialProvider.line).label, _ko.loginLineLabel);
      expect(_widget(tester, SocialProvider.apple).connected, isFalse);
      expect(_widget(tester, SocialProvider.apple).label, _ko.loginAppleLabel);
      expect(find.text(_ko.loginMethodsIntroBody), findsOneWidget);
    });

    testWidgets('하나만 연결이면 그 줄이 꺼지고 last.notice', (tester) async {
      await _pump(tester);
      expect(_widget(tester, SocialProvider.kakao).onPressed, isNull);
      expect(find.text(_ko.loginMethodsLastNotice), findsOneWidget);
      expect(_widget(tester, SocialProvider.line).onPressed, isNotNull);
    });

    testWidgets('둘 이상 연결이면 줄이 눌리고 last.notice가 없음', (tester) async {
      await _pump(
        tester,
        identities: [LoginProvider.kakao, LoginProvider.line],
      );
      expect(_widget(tester, SocialProvider.kakao).onPressed, isNotNull);
      expect(find.text(_ko.loginMethodsLastNotice), findsNothing);
    });
  });

  group('떼기', () {
    testWidgets('dialog 확인 뒤에만 unlink', (tester) async {
      final h = await _pump(
        tester,
        identities: [LoginProvider.kakao, LoginProvider.line],
      );
      await tester.tap(_button(SocialProvider.line));
      await tester.pumpAndSettle();
      expect(
        find.text(_ko.loginMethodsUnlinkConfirm(_ko.loginProviderLine)),
        findsOneWidget,
      );
      expect(h.api.unlinkCalls, isEmpty);

      await tester.tap(find.text(_ko.loginMethodsUnlinkConfirmCancel));
      await tester.pumpAndSettle();
      expect(h.api.unlinkCalls, isEmpty);
      expect(_widget(tester, SocialProvider.line).connected, isTrue);

      await tester.tap(_button(SocialProvider.line));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_ko.loginMethodsUnlinkConfirmUnlink));
      await tester.pumpAndSettle();
      expect(h.api.unlinkCalls, [LoginProvider.line]);
      expect(_widget(tester, SocialProvider.line).connected, isFalse);
    });

    testWidgets('실패하면 errorBodyUnlink', (tester) async {
      final h = await _pump(
        tester,
        identities: [LoginProvider.kakao, LoginProvider.line],
      );
      h.api.unlinkError = problemOf(409, 'auth.last_identity');
      await tester.tap(_button(SocialProvider.line));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_ko.loginMethodsUnlinkConfirmUnlink));
      await tester.pumpAndSettle();
      expect(find.text(_ko.loginMethodsErrorBodyUnlink), findsOneWidget);
      expect(_widget(tester, SocialProvider.line).connected, isTrue);
    });
  });

  group('붙이기', () {
    testWidgets('연결 안 된 줄을 누르면 붙고 connected가 됨', (tester) async {
      final h = await _pump(tester);
      await tester.tap(_button(SocialProvider.line));
      await tester.pumpAndSettle();
      expect(h.api.linkCalls, [LoginProvider.line]);
      expect(_widget(tester, SocialProvider.line).connected, isTrue);
      expect(find.text(_ko.loginMethodsErrorBodyLink), findsNothing);
    });

    testWidgets('LinkInUse면 in-use.body dialog notice이고 이 화면에 남음', (
      tester,
    ) async {
      final h = await _pump(tester);
      h.api.linkError = problemOf(409, 'auth.identity_in_use');
      await tester.tap(_button(SocialProvider.google));
      await tester.pumpAndSettle();
      expect(find.text(_ko.loginMethodsInUseBody), findsOneWidget);
      expect(find.text(_ko.loginMethodsErrorBodyLink), findsNothing);

      await tester.tap(find.text(_ko.actionConfirm));
      await tester.pumpAndSettle();
      expect(find.text(_ko.loginMethodsInUseBody), findsNothing);
      expect(find.byType(LoginMethodsScreen), findsOneWidget);
      expect(h.pushed, isEmpty);
      expect(_widget(tester, SocialProvider.google).connected, isFalse);
    });

    testWidgets('실패하면 errorBodyLink', (tester) async {
      final h = await _pump(tester);
      h.api.linkError = problemOf(401, 'auth.provider_token_invalid');
      await tester.tap(_button(SocialProvider.line));
      await tester.pumpAndSettle();
      expect(find.text(_ko.loginMethodsErrorBodyLink), findsOneWidget);
      expect(find.byType(LoginMethodsScreen), findsOneWidget);
    });

    testWidgets('붙이는 중에는 다른 줄과 합치기 입구가 꺼짐', (tester) async {
      final gate = Completer<void>();
      final h = await _pump(tester, api: FakeIdentityApi()..linkGate = gate);
      await tester.tap(_button(SocialProvider.line));
      await tester.pump();
      expect(_widget(tester, SocialProvider.line).loading, isTrue);
      expect(_widget(tester, SocialProvider.google).onPressed, isNull);
      expect(tester.widget<PrimaryButton>(_mergeCta).onPressed, isNull);
      gate.complete();
      await tester.pumpAndSettle();
      expect(h.api.linkCalls, [LoginProvider.line]);
      expect(tester.widget<PrimaryButton>(_mergeCta).onPressed, isNotNull);
    });
  });

  testWidgets('떼기가 예상 밖 예외여도 안내하고 줄이 다시 눌림', (tester) async {
    final h = await _pump(
      tester,
      identities: [LoginProvider.kakao, LoginProvider.line],
    );
    h.api.unlinkThrows = StateError('boom');
    await tester.tap(_button(SocialProvider.line));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_ko.loginMethodsUnlinkConfirmUnlink));
    await tester.pumpAndSettle();
    expect(find.text(_ko.loginMethodsErrorBodyUnlink), findsOneWidget);
    expect(_widget(tester, SocialProvider.line).onPressed, isNotNull);
    expect(tester.widget<PrimaryButton>(_mergeCta).onPressed, isNotNull);
  });

  group('합치기 입구', () {
    for (final count in [1, 4]) {
      testWidgets('연결 $count개여도 가로선 아래 quiet 버튼이 보임', (tester) async {
        await _pump(
          tester,
          identities: [
            LoginProvider.kakao,
            LoginProvider.line,
            LoginProvider.google,
            LoginProvider.apple,
          ].take(count).toList(),
        );
        final button = tester.widget<PrimaryButton>(_mergeCta);
        expect(button.variant, PrimaryButtonVariant.quiet);
        expect(button.label, _ko.loginMethodsMergeCta);
        final line = find.byKey(LoginMethodsScreen.mergeDividerKey);
        expect(line, findsOneWidget);
        expect(
          tester.getTopLeft(_mergeCta).dy,
          greaterThan(tester.getBottomLeft(line).dy),
        );
      });
    }

    testWidgets('누르면 account-merge로 push하고 돌아오면 목록을 다시 읽음', (tester) async {
      final h = await _pump(tester);
      final listsBefore = h.api.listCalls;
      await tester.ensureVisible(_mergeCta);
      await tester.tap(_mergeCta);
      await tester.pumpAndSettle();
      expect(h.pushed, [pathOf(ScreenIds.accountMerge)]);
      expect(h.api.listCalls, listsBefore);

      // 합치기 쪽에서 다른 수단이 붙은 채 돌아옵니다.
      h.api.identities.add(LoginProvider.line);
      await tester.tap(find.byKey(_mergeBackKey));
      await tester.pumpAndSettle();
      expect(h.api.listCalls, listsBefore + 1);
      expect(_widget(tester, SocialProvider.line).connected, isTrue);
    });
  });

  testWidgets('en 320x568 글자 배율 2.0에서 넘치지 않음', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await _pump(tester, locale: const Locale('en'), textScale: 2);
    h.api.linkError = problemOf(401, 'auth.provider_token_invalid');
    await tester.scrollUntilVisible(
      _button(SocialProvider.apple),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(_button(SocialProvider.apple));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      _mergeCta,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.takeException(), isNull);
  });
}
