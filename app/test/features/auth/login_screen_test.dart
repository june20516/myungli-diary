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
  testWidgets('네 버튼이 앱 언어 순서대로 같은 크기', (tester) async {
    final expected = {
      const Locale('ko'): [
        SocialProvider.kakao,
        SocialProvider.line,
        SocialProvider.google,
        SocialProvider.apple,
      ],
      const Locale('ja'): [
        SocialProvider.line,
        SocialProvider.kakao,
        SocialProvider.google,
        SocialProvider.apple,
      ],
      const Locale('en'): [
        SocialProvider.google,
        SocialProvider.kakao,
        SocialProvider.line,
        SocialProvider.apple,
      ],
    };
    for (final entry in expected.entries) {
      await _pumpLogin(tester, locale: entry.key, pressed: []);
      expect(_shownOrder(tester), entry.value, reason: '${entry.key}');
      final sizes = {
        for (final provider in SocialProvider.values)
          tester.getSize(_button(provider)),
      };
      expect(sizes, hasLength(1), reason: '${entry.key} 버튼 크기');
    }
  });

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
