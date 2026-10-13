import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/theme/app_theme.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';

/// golden 테스트에 붙는 태그. `dart_test.yaml`에 선언돼 있습니다.
const String goldenTag = 'golden';

/// golden 격자의 글자 크기 조합. 2.0은 고정 칸이 1.3에서 멈추는지 보려는 값입니다.
const List<double> goldenTextScales = [1, 1.3, 2];

/// golden 격자의 밝기 조합.
const List<Brightness> goldenBrightnesses = [Brightness.light, Brightness.dark];

/// golden 격자의 언어 조합. 일본어는 글꼴 묶음이 다릅니다.
const List<Locale> goldenLocales = [Locale('ko'), Locale('ja')];

/// 격자 한 칸의 너비(논리 픽셀).
const double goldenCellWidth = 360;

const double _gap = 16;

/// golden 비교 테스트. Linux가 아니면 이유를 출력하고 건너뜁니다.
void goldenTest(
  String description,
  Future<void> Function(WidgetTester tester) body,
) {
  testWidgets(description, (tester) async {
    if (!Platform.isLinux) {
      markTestSkipped(
        'golden은 Linux에서만 비교합니다(현재 ${Platform.operatingSystem}). '
        'tool/goldens_linux.sh로 기준 이미지를 갱신하세요.',
      );
      return;
    }
    await body(tester);
  }, tags: goldenTag);
}

/// 라이트·다크 × ko·ja × 글자 크기 1.0·1.3·2.0 열두 조합을 한 장의 격자로 그려
/// `test/goldens/<name>.png`와 비교합니다.
///
/// 격자의 가로는 글자 크기, 세로는 밝기×언어입니다. [fixedCells]가 true면
/// 칸이 고정된 컴포넌트 안의 글자 배율이 2.0에서도 1.3에 멈추는지 확인합니다.
/// 측정 대상은 [fixedCellTarget]이 돌려주는 finder(칸 안에서 찾음)이고, 없으면
/// 첫 [Text]입니다. 측정 방식은 [effectiveTextScale]을 봅니다.
Future<void> goldenMatrix(
  WidgetTester tester,
  String name,
  Widget Function() build, {
  bool fixedCells = false,
  Finder Function()? fixedCellTarget,
}) async {
  final gridKey = GlobalKey();
  final width =
      goldenTextScales.length * goldenCellWidth +
      (goldenTextScales.length + 1) * _gap;
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = Size(width, 12000);
  addTearDown(tester.view.reset);

  final rows = <Widget>[
    for (final brightness in goldenBrightnesses)
      for (final locale in goldenLocales)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final scale in goldenTextScales)
              Padding(
                padding: const EdgeInsets.only(left: _gap, top: _gap),
                child: _GoldenCell(
                  key: _cellKey(brightness, locale, scale),
                  brightness: brightness,
                  locale: locale,
                  scale: scale,
                  child: build(),
                ),
              ),
          ],
        ),
  ];

  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: MediaQueryData.fromView(tester.view),
        child: Align(
          alignment: Alignment.topLeft,
          child: RepaintBoundary(
            key: gridKey,
            child: ColoredBox(
              color: const Color(0xFFFFFFFF),
              child: Padding(
                padding: const EdgeInsets.only(bottom: _gap, right: _gap),
                child: Column(mainAxisSize: MainAxisSize.min, children: rows),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();

  if (fixedCells) {
    for (final brightness in goldenBrightnesses) {
      for (final locale in goldenLocales) {
        final at13 = _scaleInCell(
          tester,
          brightness,
          locale,
          1.3,
          fixedCellTarget,
        );
        final at20 = _scaleInCell(
          tester,
          brightness,
          locale,
          2,
          fixedCellTarget,
        );
        // 10pt 글자가 실제로 얼마로 그려지는지 읽습니다. 상한이 없으면 2.0 칸은 20입니다.
        expect(
          at13,
          closeTo(13, 0.001),
          reason: '$name ${brightness.name} $locale: 1.3 칸의 실효 배율',
        );
        expect(
          at20,
          closeTo(at13, 0.001),
          reason: '$name ${brightness.name} $locale: 고정 칸은 2.0에서 1.3에 멈춰야 합니다',
        );
      }
    }
  }

  await expectLater(find.byKey(gridKey), matchesGoldenFile('$name.png'));
}

double _scaleInCell(
  WidgetTester tester,
  Brightness brightness,
  Locale locale,
  double scale,
  Finder Function()? target,
) {
  final matching = target?.call() ?? find.byType(Text);
  final found = find.descendant(
    of: find.byKey(_contentKey(brightness, locale, scale)),
    matching: matching,
  );
  return effectiveTextScale(tester, found);
}

/// [target] 첫 번째 글자 위젯이 실제로 받는 글자 배율(10pt 글자가 그려지는 크기).
///
/// Flutter 동작과 같은 규칙입니다.
/// - [Text]: 자체 `textScaler`가 있으면 그것, 없으면 `MediaQuery.textScalerOf`
///   (`flutter/lib/src/widgets/text.dart`).
/// - [RichText]: MediaQuery를 보지 않고 자체 `textScaler`만 씁니다. 기본값은
///   `TextScaler.noScaling`(`flutter/lib/src/widgets/basic.dart`).
/// - 그 밖의 위젯: `MediaQuery.textScalerOf`.
///
/// 대상이 없으면(아이콘만 있는 칸 등) 실패합니다.
double effectiveTextScale(WidgetTester tester, Finder target) {
  expect(
    target,
    findsWidgets,
    reason:
        '글자 크기 상한을 잴 글자(Text·RichText) 대상이 없습니다. '
        'fixedCellTarget으로 대상을 고르세요.',
  );
  final element = target.evaluate().first;
  final scaler = switch (element.widget) {
    Text(:final textScaler) => textScaler ?? MediaQuery.textScalerOf(element),
    RichText(:final textScaler) => textScaler,
    _ => MediaQuery.textScalerOf(element),
  };
  return scaler.scale(10);
}

Key _cellKey(Brightness brightness, Locale locale, double scale) =>
    ValueKey('golden-cell-${brightness.name}-$locale-$scale');

Key _contentKey(Brightness brightness, Locale locale, double scale) =>
    ValueKey('golden-content-${brightness.name}-$locale-$scale');

/// 한 조합의 칸: 테마·언어·글자 크기를 입히고 이름표를 붙입니다.
class _GoldenCell extends StatelessWidget {
  const new({
    required this.brightness,
    required this.locale,
    required this.scale,
    required this.child,
    super.key,
  });

  final Brightness brightness;
  final Locale locale;
  final double scale;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: goldenCellWidth,
      child: Localizations(
        locale: locale,
        delegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        child: MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: Theme(
            data: buildTheme(brightness: brightness, locale: locale),
            child: Builder(
              builder: (context) {
                final tokens = context.tokens;
                return Material(
                  color: tokens.colors.bgBase,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${brightness.name} ${locale.languageCode} $scale',
                          textScaler: TextScaler.noScaling,
                          style: tokens.typography.captionSm.copyWith(
                            color: tokens.colors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        KeyedSubtree(
                          key: _contentKey(brightness, locale, scale),
                          child: child,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
