import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsData;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/action/primary_button.dart';
import 'package:myungli_diary/design/elements/app_icon.dart';
import 'package:myungli_diary/design/theme/app_theme.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';
import 'package:phosphor_glyphs/phosphor_glyphs.dart';

Widget _app(Widget child, {Locale locale = const Locale('ko')}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: buildTheme(brightness: Brightness.light, locale: locale),
  home: Scaffold(body: Center(child: child)),
);

SemanticsData _semantics(WidgetTester tester, Finder finder) =>
    tester.getSemantics(finder).getSemanticsData();

const AppGlyph _pencil = AppGlyph(
  light: PhosphorIconsLight.pencilSimple,
  regular: PhosphorIconsRegular.pencilSimple,
);

void main() {
  group('primary-button', () {
    testWidgets('눌리면 onPressed가 한 번 불립니다', (tester) async {
      var pressed = 0;
      await tester.pumpWidget(
        _app(PrimaryButton(label: '다음', onPressed: () => pressed++)),
      );
      await tester.tap(find.text('다음'));
      await tester.pumpAndSettle();
      expect(pressed, 1);
    });

    testWidgets('loading이면 두 번 눌러도 onPressed가 불리지 않고 글자 대신 점이 보입니다', (
      tester,
    ) async {
      var pressed = 0;
      await tester.pumpWidget(
        _app(
          PrimaryButton(label: '다음', loading: true, onPressed: () => pressed++),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.byType(PrimaryButton));
      await tester.tap(find.byType(PrimaryButton));
      expect(pressed, 0);
      expect(find.text('다음'), findsNothing, reason: '글자 자리에 점 세 개');
      expect(find.byKey(PrimaryButton.dotsKey), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('loading이어도 너비는 그대로입니다', (tester) async {
      await tester.pumpWidget(_app(const SizedBox(width: 300, child: _Pair())));
      await tester.pump(const Duration(seconds: 1));
      final idle = tester.getSize(find.byKey(const ValueKey('idle')));
      final busy = tester.getSize(find.byKey(const ValueKey('busy')));
      expect(busy, idle);
      expect(idle.width, 300);
    });

    testWidgets('onPressed가 null이면 Semantics가 꺼짐이고 누를 수 없습니다', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(const PrimaryButton(label: '다음', onPressed: null)),
      );
      final data = _semantics(tester, find.bySemanticsLabel('다음'));
      expect(data.flagsCollection.isEnabled, Tristate.isFalse);
      expect(data.flagsCollection.isButton, isTrue);
      handle.dispose();
    });

    testWidgets('loading이면 "처리 중"을 알립니다(en은 영어)', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(PrimaryButton(label: '다음', loading: true, onPressed: () {})),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(find.bySemanticsLabel('처리 중'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('busyLabel로 알림 문구를 바꿀 수 있습니다', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          PrimaryButton(
            label: '광고 보고 열기',
            loading: true,
            busyLabel: '확인 중',
            onPressed: () {},
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(find.bySemanticsLabel('확인 중'), findsOneWidget);
      handle.dispose();
    });

    for (final variant in PrimaryButtonVariant.values) {
      testWidgets('${variant.name}: 면 높이가 명세와 같습니다', (tester) async {
        await tester.pumpWidget(
          _app(PrimaryButton(label: '다음', variant: variant, onPressed: () {})),
        );
        final face = tester.getSize(find.byKey(PrimaryButton.faceKey));
        // quiet도 filled와 같은 52입니다(V60).
        expect(face.height, 52);
      });
    }

    for (final variant in PrimaryButtonVariant.values) {
      testWidgets('${variant.name}: 글자 배율 3.0에서는 면이 커지고 글자가 안에 들어갑니다', (
        tester,
      ) async {
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(3)),
            child: _app(
              PrimaryButton(label: '다음', variant: variant, onPressed: () {}),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        final face = tester.getRect(find.byKey(PrimaryButton.faceKey));
        final text = tester.getRect(find.text('다음'));
        expect(face.height, greaterThan(variant.height));
        expect(face.top, lessThanOrEqualTo(text.top));
        expect(face.bottom, greaterThanOrEqualTo(text.bottom));
      });
    }

    testWidgets('loading이면 키보드 확정으로도 onPressed가 불리지 않습니다', (tester) async {
      var pressed = 0;
      await tester.pumpWidget(
        _app(
          PrimaryButton(label: '다음', loading: true, onPressed: () => pressed++),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      for (final key in [
        LogicalKeyboardKey.enter,
        LogicalKeyboardKey.space,
        LogicalKeyboardKey.numpadEnter,
      ]) {
        await tester.sendKeyEvent(key);
      }
      expect(pressed, 0);
    });

    testWidgets('disabled이면 키보드 확정에도 아무 일이 없습니다', (tester) async {
      await tester.pumpWidget(
        _app(const PrimaryButton(label: '다음', onPressed: null)),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      expect(tester.takeException(), isNull);
    });

    testWidgets('활성이면 Enter로 확정됩니다(대조군)', (tester) async {
      var pressed = 0;
      await tester.pumpWidget(
        _app(PrimaryButton(label: '다음', onPressed: () => pressed++)),
      );
      final focus = tester.element(find.byType(PrimaryButton));
      FocusScope.of(focus).nextFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(pressed, 1);
    });

    testWidgets('leadingIcon: 글자 앞 8 간격, 묶음이 가운데, Regular, 글자색, 읽지 않습니다', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          SizedBox(
            width: 300,
            child: PrimaryButton(
              label: '날짜 고르기',
              leadingIcon: _pencil,
              onPressed: () {},
            ),
          ),
        ),
      );
      final icon = tester.widget<AppIcon>(find.byType(AppIcon));
      expect(icon.weight, AppIconWeight.regular);
      expect(icon.scalesWithText, isTrue);
      expect(icon.size, AppIconSize.s16, reason: '글자 14는 옆 아이콘 16');
      final iconRect = tester.getRect(find.byType(Icon));
      final textRect = tester.getRect(find.text('날짜 고르기'));
      expect(textRect.left - iconRect.right, 8);
      final face = tester.getRect(find.byKey(PrimaryButton.faceKey));
      expect(
        (iconRect.left + textRect.right) / 2,
        closeTo(face.center.dx, 0.5),
        reason: '묶음이 버튼 가운데',
      );
      expect(tester.widget<Icon>(find.byType(Icon)).color, isNotNull);
      expect(find.bySemanticsLabel('날짜 고르기'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('leadingIcon: 처리 중에는 아이콘도 숨기고 점만 보입니다', (tester) async {
      await tester.pumpWidget(
        _app(
          PrimaryButton(
            label: '날짜 고르기',
            leadingIcon: _pencil,
            loading: true,
            onPressed: () {},
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(AppIcon), findsNothing);
      expect(find.byKey(PrimaryButton.dotsKey), findsOneWidget);
    });

    testWidgets('destructive: showCaution false면 경고 표시가 없습니다', (tester) async {
      await tester.pumpWidget(
        _app(
          PrimaryButton(
            label: '지우기',
            variant: PrimaryButtonVariant.destructive,
            showCaution: false,
            onPressed: () {},
          ),
        ),
      );
      expect(find.byType(AppIcon), findsNothing);
    });

    testWidgets('compact: 높이 44, 좌우 안쪽 12(확인 창 안)', (tester) async {
      await tester.pumpWidget(
        _app(
          SizedBox(
            width: 200,
            child: PrimaryButton(label: '확인', compact: true, onPressed: () {}),
          ),
        ),
      );
      final face = tester.getRect(find.byKey(PrimaryButton.faceKey));
      expect(face.height, 44);
      expect(
        tester.getRect(find.text('확인')).center.dx,
        closeTo(face.center.dx, 0.5),
      );
    });

    group('floating', () {
      Future<void> pumpFloating(WidgetTester tester, {double bottom = 0}) =>
          tester.pumpWidget(
            _app(
              MediaQuery(
                data: MediaQueryData(
                  viewPadding: EdgeInsets.only(bottom: bottom),
                ),
                child: SizedBox(
                  width: 400,
                  height: 800,
                  child: Stack(
                    children: [
                      FloatingPrimaryButton(
                        button: PrimaryButton(label: '쓰기', onPressed: () {}),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );

      testWidgets('아래 고정: 좌우 20, 아래 안전 영역 위 16, shadow.raised', (tester) async {
        await pumpFloating(tester, bottom: 34);
        final face = tester.getRect(find.byKey(PrimaryButton.faceKey));
        final stack = tester.getRect(find.byType(Stack).first);
        expect(face.left - stack.left, 20);
        expect(stack.right - face.right, 20);
        expect(stack.bottom - face.bottom, 16 + 34);
        final box = tester.widget<DecoratedBox>(
          find.byKey(FloatingPrimaryButton.shadowKey),
        );
        expect((box.decoration as BoxDecoration).boxShadow, Shadows.raised);
      });

      test('목록 아래 여백은 버튼 52 + 16 + 16', () {
        expect(FloatingPrimaryButton.listBottomInset, 84);
      });
    });

    testWidgets('destructive는 caution 아이콘이 글자 앞에 있습니다', (tester) async {
      await tester.pumpWidget(
        _app(
          PrimaryButton(
            label: '지우기',
            variant: PrimaryButtonVariant.destructive,
            onPressed: () {},
          ),
        ),
      );
      final icon = tester.getCenter(find.byType(AppIcon));
      final text = tester.getCenter(find.text('지우기'));
      expect(find.byType(AppIcon), findsOneWidget);
      expect(icon.dx, lessThan(text.dx));
    });

    testWidgets('filled·quiet에는 caution 아이콘이 없습니다', (tester) async {
      await tester.pumpWidget(
        _app(PrimaryButton(label: '다음', onPressed: () {})),
      );
      expect(find.byType(AppIcon), findsNothing);
    });

    testWidgets('글자는 한 줄이고 넘치면 말줄임입니다', (tester) async {
      await tester.pumpWidget(
        _app(
          SizedBox(
            width: 120,
            child: PrimaryButton(
              label: '아주 아주 긴 버튼 글자가 들어갑니다',
              onPressed: () {},
            ),
          ),
        ),
      );
      final text = tester.widget<Text>(find.textContaining('아주'));
      expect(text.maxLines, 1);
      expect(text.overflow, TextOverflow.ellipsis);
    });
  });
}

class _Pair extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => Column(
    children: [
      PrimaryButton(key: const ValueKey('idle'), label: '다음', onPressed: () {}),
      PrimaryButton(
        key: const ValueKey('busy'),
        label: '다음',
        loading: true,
        onPressed: () {},
      ),
    ],
  );
}
