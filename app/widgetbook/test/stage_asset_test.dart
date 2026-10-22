import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/action/social_login_button.dart';
import 'package:myungli_diary/design/theme/app_theme.dart';
import 'package:myungli_diary_widgetbook/stage.dart';

Widget _app(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: buildTheme(brightness: Brightness.light, locale: const Locale('ko')),
  home: Scaffold(body: child),
);

void main() {
  testWidgets('Stage 안에서 공식 로고(앱 자산)가 오류 없이 그려집니다', (tester) async {
    await tester.pumpWidget(
      _app(
        Stage(
          child: Column(
            children: [
              SocialLoginButton(
                provider: SocialProvider.kakao,
                label: '카카오 로그인',
                onPressed: () {},
              ),
              SocialLoginButton(
                provider: SocialProvider.apple,
                label: 'Apple로 로그인',
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(SvgPicture), findsNWidgets(2));
  });

  testWidgets('Stage 안에서 LINE·Google PNG 로고(앱 자산)가 오류 없이 그려집니다', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        Stage(
          child: Column(
            children: [
              SocialLoginButton(
                provider: SocialProvider.line,
                label: 'LINE으로 로그인',
                onPressed: () {},
              ),
              SocialLoginButton(
                provider: SocialProvider.google,
                label: 'Google 계정으로 로그인',
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    );
    // PNG 해독은 실제 비동기 작업이라 가짜 시계 밖에서 끝까지 기다립니다.
    await tester.runAsync(() async {
      for (final element in find.byType(Image).evaluate()) {
        await precacheImage((element.widget as Image).image, element);
      }
    });
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(Image), findsNWidgets(2));
  });

  testWidgets('Stage 번들은 앱 자산 키를 읽고, 기본 번들은 못 읽습니다', (tester) async {
    const key = 'assets/brand/kakao/kakao_symbol.svg';
    late BuildContext inside;
    await tester.pumpWidget(
      _app(
        Stage(
          child: Builder(
            builder: (context) {
              inside = context;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    final bytes = await tester.runAsync(
      () => DefaultAssetBundle.of(inside).load(key),
    );
    expect(bytes!.lengthInBytes, greaterThan(0));
    // 변환이 없으면 같은 키를 찾지 못합니다(Widgetbook에서는 앱이 의존 패키지).
    Object? error;
    await tester.runAsync(
      () =>
          Future<ByteData>(() => rootBundle.load(key))
              .then<void>((_) {}, onError: (Object e) => error = e),
    );
    expect(error, isNotNull);
  });
}
