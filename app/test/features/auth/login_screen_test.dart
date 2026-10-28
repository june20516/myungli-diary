import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/action/social_login_button.dart';
import 'package:myungli_diary/design/theme/app_theme.dart';
import 'package:myungli_diary/features/auth/application/login_controller.dart';
import 'package:myungli_diary/features/auth/presentation/login_screen.dart';

/// 누른 제공자를 기록하고, [gate]가 있으면 그 Future가 끝날 때까지 처리 중으로 둡니다.
class _RecordingController extends LoginController {
  new(this.pressed, {this.gate});

  final List<SocialProvider> pressed;
  final Completer<LoginOutcome>? gate;

  @override
  Future<LoginOutcome> signIn(
    SocialProvider provider, {
    DiscardNotice? showDiscardNotice,
  }) {
    pressed.add(provider);
    return gate?.future ?? Future.value(const LoginCancelled());
  }
}

Future<void> _pumpLogin(
  WidgetTester tester, {
  required Locale locale,
  required List<SocialProvider> pressed,
  Completer<LoginOutcome>? gate,
  double textScale = 1.0,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        loginControllerProvider.overrideWith(
          () => _RecordingController(pressed, gate: gate),
        ),
      ],
      child: MaterialApp(
        locale: locale,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        theme: buildTheme(brightness: Brightness.light, locale: locale),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const LoginScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _button(SocialProvider provider) => find.byWidgetPredicate(
  (w) => w is SocialLoginButton && w.provider == provider,
);

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

void main() {
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
    testWidgets('${entry.key}: 네 버튼이 앱 언어 순서대로 같은 크기', (tester) async {
      await _pumpLogin(tester, locale: Locale(entry.key), pressed: []);
      expect(_shownOrder(tester), entry.value);
      final sizes = {
        for (final provider in SocialProvider.values)
          tester.getSize(_button(provider)),
      };
      expect(sizes, hasLength(1));
    });
  }

  for (final entry in orders.entries) {
    testWidgets('${entry.key}: 320x568, 글자 배율 2.0, 오류 안내가 있어도 넘치지 않음', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await _pumpLogin(
        tester,
        locale: Locale(entry.key),
        pressed: [],
        textScale: 2,
      );
      // 취소로 끝나 오류 안내를 띄웁니다.
      await tester.ensureVisible(_button(SocialProvider.apple));
      await tester.tap(_button(SocialProvider.apple));
      await tester.pumpAndSettle();
      expect(find.byKey(loginErrorKey), findsOneWidget);
      expect(tester.takeException(), isNull);
      for (final provider in SocialProvider.values) {
        await tester.ensureVisible(_button(provider));
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('한 버튼이 처리 중이면 나머지 셋이 꺼짐', (tester) async {
    final gate = Completer<LoginOutcome>();
    final pressed = <SocialProvider>[];
    await _pumpLogin(
      tester,
      locale: const Locale('ko'),
      pressed: pressed,
      gate: gate,
    );
    await tester.tap(_button(SocialProvider.google));
    await tester.pump();

    for (final provider in SocialProvider.values) {
      final button = tester.widget<SocialLoginButton>(_button(provider));
      if (provider == SocialProvider.google) {
        expect(button.loading, isTrue);
      } else {
        expect(button.onPressed, isNull, reason: '$provider');
      }
    }
    gate.complete(const LoginCancelled());
    await tester.pumpAndSettle();
  });

  testWidgets('LINE을 누르면 controller.signIn(line)', (tester) async {
    final pressed = <SocialProvider>[];
    await _pumpLogin(tester, locale: const Locale('ko'), pressed: pressed);
    await tester.tap(_button(SocialProvider.line));
    await tester.pumpAndSettle();
    expect(pressed, [SocialProvider.line]);
  });
}
