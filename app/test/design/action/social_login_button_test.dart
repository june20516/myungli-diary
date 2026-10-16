import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/design/components/action/primary_button.dart';
import 'package:myungli_diary/design/components/action/social_login_button.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';

import '../input/input_harness.dart';

Color? _faceColor(WidgetTester tester) =>
    (tester
                .widget<DecoratedBox>(find.byKey(SocialLoginButton.faceKey))
                .decoration
            as BoxDecoration)
        .color;

void main() {
  group('social-login-button', () {
    testWidgets('눌리면 onPressed가 한 번 불립니다', (tester) async {
      var pressed = 0;
      await tester.pumpWidget(
        inputApp(
          Center(
            child: SocialLoginButton(
              provider: SocialProvider.kakao,
              label: '카카오 로그인',
              onPressed: () => pressed++,
            ),
          ),
        ),
      );
      await tester.tap(find.text('카카오 로그인'));
      await tester.pumpAndSettle();
      expect(pressed, 1);
    });

    testWidgets('loading이면 누름을 무시하고 글자 대신 점이 보입니다', (tester) async {
      var pressed = 0;
      await tester.pumpWidget(
        inputApp(
          Center(
            child: SocialLoginButton(
              provider: SocialProvider.kakao,
              label: '카카오 로그인',
              loading: true,
              onPressed: () => pressed++,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.byType(SocialLoginButton));
      await tester.tap(find.byType(SocialLoginButton));
      expect(pressed, 0);
      expect(find.text('카카오 로그인'), findsNothing);
      expect(find.byKey(PrimaryButton.dotsKey), findsNothing);
      expect(find.byKey(SocialLoginButton.dotsKey), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('onPressed가 null이면 꺼짐으로 읽히고 흐리게 보입니다', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        inputApp(
          const Center(
            child: SocialLoginButton(
              provider: SocialProvider.apple,
              label: 'Apple로 로그인',
              onPressed: null,
            ),
          ),
        ),
      );
      final data = tester
          .getSemantics(find.bySemanticsLabel('Apple로 로그인'))
          .getSemanticsData();
      expect(data.flagsCollection.isEnabled, Tristate.isFalse);
      expect(data.hasAction(SemanticsAction.tap), isFalse);
      expect(
        tester.widget<Opacity>(find.byType(Opacity)).opacity,
        SocialLoginButton.disabledOpacity,
      );
      expect(SocialLoginButton.disabledOpacity, 0.4);
      handle.dispose();
    });

    testWidgets('제공자·밝기에 맞는 공식 로고를 씁니다', (tester) async {
      String logo() {
        final loader =
            tester.widget<SvgPicture>(find.byType(SvgPicture)).bytesLoader
                as SvgAssetLoader;
        return loader.assetName;
      }

      Future<void> pump(SocialProvider provider, Brightness brightness) async {
        await tester.pumpWidget(
          inputApp(
            Center(
              child: SocialLoginButton(
                provider: provider,
                label: '로그인',
                onPressed: () {},
              ),
            ),
            brightness: brightness,
          ),
        );
        // 밝기가 바뀌면 테마가 보간되므로 끝까지 기다립니다.
        await tester.pumpAndSettle();
      }

      await pump(SocialProvider.kakao, Brightness.light);
      expect(logo(), 'assets/brand/kakao/kakao_symbol.svg');
      await pump(SocialProvider.apple, Brightness.light);
      expect(logo(), 'assets/brand/apple/apple_logo_white.svg');
      await pump(SocialProvider.apple, Brightness.dark);
      expect(logo(), 'assets/brand/apple/apple_logo_black.svg');
    });

    testWidgets('Apple 글자는 시스템 글꼴(앱 글꼴 상속 없음), 카카오는 앱 글꼴입니다', (tester) async {
      await tester.pumpWidget(
        inputApp(
          Center(
            child: Column(
              children: [
                SocialLoginButton(
                  provider: SocialProvider.apple,
                  label: 'Apple로 로그인',
                  onPressed: () {},
                ),
                SocialLoginButton(
                  provider: SocialProvider.kakao,
                  label: '카카오 로그인',
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
      );
      final apple = tester.widget<Text>(find.text('Apple로 로그인')).style!;
      expect(apple.inherit, isFalse);
      expect(apple.fontFamily, isNull);
      // 크기·굵기는 type.label.lg입니다(`label.apple`).
      final labelLg = tester
          .element(find.text('Apple로 로그인'))
          .tokens
          .typography
          .labelLg;
      expect(apple.fontSize, labelLg.fontSize);
      expect(apple.fontWeight, labelLg.fontWeight);
      final kakao = tester.widget<Text>(find.text('카카오 로그인')).style!;
      expect(kakao.fontFamily, isNotNull);
    });

    testWidgets('카카오는 공식 노랑 바탕에 심볼과 레이블입니다', (tester) async {
      await tester.pumpWidget(
        inputApp(
          Center(
            child: SocialLoginButton(
              provider: SocialProvider.kakao,
              label: '카카오 로그인',
              onPressed: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(_faceColor(tester), const Color(0xFFFEE500));
      expect(find.byType(SvgPicture), findsOneWidget);
      expect(
        tester.getSize(find.byKey(SocialLoginButton.faceKey)).height,
        greaterThanOrEqualTo(52),
      );
    });

    testWidgets('Apple은 라이트에서 검정 바탕입니다', (tester) async {
      await tester.pumpWidget(
        inputApp(
          Center(
            child: SocialLoginButton(
              provider: SocialProvider.apple,
              label: 'Apple로 로그인',
              onPressed: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(_faceColor(tester), const Color(0xFF000000));
    });

    testWidgets('다크 테마의 Apple 바탕은 흰색입니다', (tester) async {
      await tester.pumpWidget(
        inputApp(
          Center(
            child: SocialLoginButton(
              provider: SocialProvider.apple,
              label: 'Apple로 로그인',
              onPressed: () {},
            ),
          ),
          brightness: Brightness.dark,
        ),
      );
      await tester.pumpAndSettle();
      expect(_faceColor(tester), const Color(0xFFFFFFFF));
    });

    testWidgets('글자가 커지면 면이 함께 커지고 잘리지 않습니다', (tester) async {
      await tester.pumpWidget(
        inputApp(
          MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Center(
              child: SizedBox(
                width: 320,
                child: SocialLoginButton(
                  provider: SocialProvider.kakao,
                  label: '카카오 로그인',
                  onPressed: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byKey(SocialLoginButton.faceKey)).height,
        greaterThanOrEqualTo(52),
      );
    });
  });
}
