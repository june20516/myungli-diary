import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsData;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/action/primary_button.dart';
import 'package:myungli_diary/design/elements/app_icon.dart';
import 'package:myungli_diary/design/theme/app_theme.dart';

Widget _app(Widget child, {Locale locale = const Locale('ko')}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: buildTheme(brightness: Brightness.light, locale: locale),
  home: Scaffold(body: Center(child: child)),
);

SemanticsData _semantics(WidgetTester tester, Finder finder) =>
    tester.getSemantics(finder).getSemanticsData();

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
        expect(face.height, variant == PrimaryButtonVariant.quiet ? 44 : 52);
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

    testWidgets('quiet: 면 높이가 44여도 위아래 2px 밖(48 안)을 눌러도 동작합니다', (tester) async {
      var pressed = 0;
      await tester.pumpWidget(
        _app(
          PrimaryButton(
            label: '다시 시도',
            variant: PrimaryButtonVariant.quiet,
            onPressed: () => pressed++,
          ),
        ),
      );
      final rect = tester.getRect(find.byKey(PrimaryButton.faceKey));
      await tester.tapAt(Offset(rect.center.dx, rect.bottom + 1.5));
      await tester.pumpAndSettle();
      expect(pressed, 1);
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
