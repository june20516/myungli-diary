import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/action/primary_button.dart';
import 'package:myungli_diary/design/components/action/social_login_button.dart';
import 'package:myungli_diary/design/components/action/social_provider_text.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';
import 'package:phosphor_glyphs/phosphor_glyphs.dart';

import '../input/input_harness.dart';

Color? _faceColor(WidgetTester tester) =>
    (tester
                .widget<DecoratedBox>(find.byKey(SocialLoginButton.faceKey))
                .decoration
            as BoxDecoration)
        .color;

Border? _faceBorder(WidgetTester tester) =>
    (tester
                    .widget<DecoratedBox>(find.byKey(SocialLoginButton.faceKey))
                    .decoration
                as BoxDecoration)
            .border
        as Border?;

/// 버튼 안 PNG 로고의 자산 이름.
String _pngLogo(WidgetTester tester) =>
    (tester.widget<Image>(find.byType(Image)).image as AssetImage).assetName;

Widget _connected({
  SocialProvider provider = SocialProvider.kakao,
  VoidCallback? onPressed,
  bool loading = false,
  bool disabled = false,
}) => Center(
  child: SocialLoginButton(
    provider: provider,
    label: '카카오',
    connected: true,
    connectedLabel: '연결됨',
    unlinkHint: '연결 끊기',
    loading: loading,
    disabled: disabled,
    animated: false,
    onPressed: onPressed,
  ),
);

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

    testWidgets('SocialLoginSystemFont가 시스템 글꼴 자리를 채우고 인자가 먼저', (tester) async {
      await tester.pumpWidget(
        inputApp(
          SocialLoginSystemFont(
            fontFamily: 'Fallback',
            child: Center(
              child: Column(
                children: [
                  SocialLoginButton(
                    provider: SocialProvider.apple,
                    label: 'Apple로 로그인',
                    onPressed: () {},
                  ),
                  SocialLoginButton(
                    provider: SocialProvider.google,
                    label: 'Google로 로그인',
                    systemFontFamily: 'Explicit',
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
        ),
      );
      final apple = tester.widget<Text>(find.text('Apple로 로그인')).style!;
      expect(apple.inherit, isFalse);
      expect(apple.fontFamily, 'Fallback');
      final google = tester.widget<Text>(find.text('Google로 로그인')).style!;
      expect(google.fontFamily, 'Explicit');
      // 카카오는 앱 글꼴 그대로입니다.
      final kakao = tester.widget<Text>(find.text('카카오 로그인')).style!;
      expect(kakao.fontFamily, isNot('Fallback'));
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

  group('social-login-button 2.7.0', () {
    test('제공자 문구·이름은 ARB의 ui.login.provider·ui.login-methods.row입니다', () {
      final l10n = lookupAppLocalizations(const Locale('ko'));
      expect(
        [for (final p in SocialProvider.values) socialProviderLabel(l10n, p)],
        ['카카오 로그인', 'LINE으로 로그인', 'Google 계정으로 로그인', 'Apple로 로그인'],
      );
      expect(
        [for (final p in SocialProvider.values) socialProviderName(l10n, p)],
        ['카카오', 'LINE', 'Google', 'Apple'],
      );
    });

    testWidgets('line·google 변형이 그려집니다', (tester) async {
      Future<void> pump(SocialProvider provider, Brightness brightness) async {
        await tester.pumpWidget(
          inputApp(
            Center(
              child: SocialLoginButton(
                provider: provider,
                label: provider == SocialProvider.line
                    ? 'LINE으로 로그인'
                    : 'Google 계정으로 로그인',
                onPressed: () {},
              ),
            ),
            brightness: brightness,
          ),
        );
        await tester.pumpAndSettle();
      }

      await pump(SocialProvider.line, Brightness.light);
      expect(_faceColor(tester), SocialLoginButton.lineBackground);
      expect(_pngLogo(tester), 'assets/brand/line/line_icon.png');
      expect(find.byKey(SocialLoginButton.separatorKey), findsOneWidget);
      expect(
        tester.widget<Text>(find.text('LINE으로 로그인')).style!.color,
        SocialLoginButton.lineForeground,
      );

      await pump(SocialProvider.google, Brightness.light);
      expect(_faceColor(tester), SocialLoginButton.googleLight.background);
      expect(
        _faceBorder(tester)!.top.color,
        SocialLoginButton.googleLight.border,
      );
      expect(
        _faceBorder(tester)!.top.width,
        SocialLoginButton.googleBorderWidth,
      );
      expect(
        _faceBorder(tester)!.top.strokeAlign,
        BorderSide.strokeAlignInside,
      );
      expect(_pngLogo(tester), 'assets/brand/google/g_logo_light.png');
      final google = tester.widget<Text>(find.text('Google 계정으로 로그인')).style!;
      expect(google.color, SocialLoginButton.googleLight.foreground);
      expect(google.fontSize, SocialLoginButton.googleFontSize);
      expect(google.fontWeight, FontWeight.w500);
      // Google Sans가 없어 시스템 글꼴입니다(앱 글꼴 상속 없음).
      expect(google.inherit, isFalse);
      expect(find.byKey(SocialLoginButton.separatorKey), findsNothing);

      await pump(SocialProvider.google, Brightness.dark);
      expect(_faceColor(tester), SocialLoginButton.googleDark.background);
      expect(_pngLogo(tester), 'assets/brand/google/g_logo_dark.png');
    });

    testWidgets('로고는 왼쪽 안쪽 16에 고정하고 글자는 가운데입니다', (tester) async {
      await tester.pumpWidget(
        inputApp(
          Center(
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
      );
      final face = tester.getRect(find.byKey(SocialLoginButton.faceKey));
      final logo = tester.getRect(find.byType(SvgPicture));
      expect(logo.left - face.left, SocialLoginButton.logoInset);
      expect(logo.width, SocialLoginButton.logoSize);
      expect(
        tester.getCenter(find.text('카카오 로그인')).dx,
        moreOrLessEquals(face.center.dx, epsilon: 0.5),
      );
    });

    testWidgets('line 꺼짐은 흐리지 않고 가이드의 흰 바탕·테두리·글자색입니다', (tester) async {
      await tester.pumpWidget(
        inputApp(
          const Center(
            child: SocialLoginButton(
              provider: SocialProvider.line,
              label: 'LINE으로 로그인',
              onPressed: null,
            ),
          ),
        ),
      );
      expect(_faceColor(tester), SocialLoginButton.lineDisabledBackground);
      expect(
        _faceBorder(tester)!.top.color,
        SocialLoginButton.lineDisabledBorder,
      );
      expect(
        tester.widget<Text>(find.text('LINE으로 로그인')).style!.color,
        SocialLoginButton.lineDisabledForeground,
      );
      expect(find.byType(Opacity), findsNothing);
    });

    testWidgets('line 눌림은 검정 30% 덮개입니다', (tester) async {
      await tester.pumpWidget(
        inputApp(
          Center(
            child: SocialLoginButton(
              provider: SocialProvider.line,
              label: 'LINE으로 로그인',
              onPressed: () {},
            ),
          ),
        ),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('LINE으로 로그인')),
      );
      await tester.pump();
      expect(
        _faceColor(tester),
        Color.alphaBlend(
          SocialLoginButton.linePressedOverlay,
          SocialLoginButton.lineBackground,
        ),
      );
      await gesture.up();
      await tester.pump();
      expect(_faceColor(tester), SocialLoginButton.lineBackground);
    });

    testWidgets('line은 키보드 확정(Enter·Space)으로 onPressed가 불립니다', (tester) async {
      var pressed = 0;
      await tester.pumpWidget(
        inputApp(
          Center(
            child: SocialLoginButton(
              provider: SocialProvider.line,
              label: 'LINE으로 로그인',
              onPressed: () => pressed++,
            ),
          ),
        ),
      );
      FocusScope.of(tester.element(find.byType(SocialLoginButton))).nextFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(pressed, 2);
    });

    testWidgets('connected면 제공자 이름과 연결됨 라벨, 제공자 바탕색이 아닙니다', (tester) async {
      final handle = tester.ensureSemantics();
      var pressed = 0;
      await tester.pumpWidget(inputApp(_connected(onPressed: () => pressed++)));
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(SocialLoginButton));
      expect(_faceColor(tester), context.tokens.colors.bgSheet);
      expect(_faceBorder(tester)!.top.color, context.tokens.colors.line);
      expect(find.text('카카오'), findsOneWidget);
      final state = tester.widget<Text>(find.text('연결됨'));
      expect(state.style!.color, context.tokens.colors.actionPrimary);
      final check = tester.widget<Icon>(find.byType(Icon));
      expect(check.icon, PhosphorIconsRegular.check);
      expect(check.size, SocialLoginButton.connectedIconSize);
      // 로고는 제공자 색 배지 20px 안의 심볼 14px입니다.
      final badge = tester.getSize(find.byKey(SocialLoginButton.badgeKey));
      expect(badge, const Size.square(20));
      expect(
        tester.getSize(find.byType(SvgPicture)),
        const Size.square(SocialLoginButton.badgeSymbolSize),
      );

      final data = tester
          .getSemantics(find.bySemanticsLabel('카카오, 연결됨'))
          .getSemanticsData();
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.hint, '연결 끊기');
      expect(data.hasAction(SemanticsAction.tap), isTrue);
      await tester.tap(find.text('카카오'));
      await tester.pumpAndSettle();
      expect(pressed, 1);
      handle.dispose();
    });

    testWidgets('connected이고 onPressed가 null이면 누를 수 없고 button 역할·힌트가 없습니다', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(inputApp(_connected()));
      await tester.pumpAndSettle();
      final data = tester
          .getSemantics(find.bySemanticsLabel('카카오, 연결됨'))
          .getSemanticsData();
      expect(data.flagsCollection.isButton, isFalse);
      expect(data.hint, isEmpty);
      expect(data.hasAction(SemanticsAction.tap), isFalse);
      // 모양은 그대로입니다(흐리지 않음).
      expect(find.byType(Opacity), findsNothing);
      handle.dispose();
    });

    testWidgets('connected disabled는 줄 전체를 흐리고 누를 수 없습니다', (tester) async {
      var pressed = 0;
      await tester.pumpWidget(
        inputApp(_connected(disabled: true, onPressed: () => pressed++)),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<Opacity>(find.byType(Opacity)).opacity,
        SocialLoginButton.disabledOpacity,
      );
      await tester.tap(find.text('카카오'));
      expect(pressed, 0);
    });

    testWidgets('connected loading은 줄 전체가 숨쉬고 누를 수 없습니다', (tester) async {
      var pressed = 0;
      await tester.pumpWidget(
        inputApp(_connected(loading: true, onPressed: () => pressed++)),
      );
      await tester.pump();
      expect(find.byKey(SocialLoginButton.breathingKey), findsOneWidget);
      expect(find.text('카카오'), findsOneWidget);
      await tester.tap(find.text('카카오'));
      expect(pressed, 0);
    });

    testWidgets('connected 배지: Google은 흰 원, LINE은 초록 사각입니다', (tester) async {
      BoxDecoration badge() =>
          tester
                  .widget<DecoratedBox>(find.byKey(SocialLoginButton.badgeKey))
                  .decoration
              as BoxDecoration;

      await tester.pumpWidget(
        inputApp(_connected(provider: SocialProvider.google)),
      );
      expect(badge().color, const Color(0xFFFFFFFF));
      expect(badge().shape, BoxShape.circle);
      expect(_pngLogo(tester), 'assets/brand/google/g_logo_light.png');

      await tester.pumpWidget(
        inputApp(_connected(provider: SocialProvider.line)),
      );
      expect(badge().color, SocialLoginButton.lineBackground);
      expect(
        badge().borderRadius,
        const BorderRadius.all(Radius.circular(Radii.xs)),
      );
    });
  });
}
