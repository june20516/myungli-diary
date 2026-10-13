import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/core/platform/fakes.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';
import 'package:myungli_diary/design/components/frame/ad_banner.dart';
import 'package:myungli_diary/design/components/frame/app_bar.dart';
import 'package:myungli_diary/design/components/frame/sheet.dart';
import 'package:myungli_diary/design/components/frame/tab_bar.dart';
import 'package:myungli_diary/design/elements/app_icon.dart';
import 'package:myungli_diary/design/elements/seal.dart';
import 'package:myungli_diary/design/interaction/motion_prefs.dart';
import 'package:myungli_diary/design/theme/app_theme.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';
import 'package:phosphor_glyphs/phosphor_glyphs.dart';

const MotionPrefs _normal = MotionPrefs(
  reduceMotion: false,
  reduceTransparency: false,
  lowEnd: false,
);
const MotionPrefs _transparent = MotionPrefs(
  reduceMotion: false,
  reduceTransparency: true,
  lowEnd: false,
);

final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

Widget _app(
  Widget home, {
  FakeAds? ads,
  MotionPrefs prefs = _normal,
  Locale locale = const Locale('ko'),
}) {
  return ProviderScope(
    overrides: [adsProvider.overrideWithValue(ads ?? FakeAds())],
    child: MaterialApp(
      navigatorKey: _navigatorKey,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: buildTheme(brightness: Brightness.light, locale: locale),
      home: MotionPrefsScope(
        prefs: prefs,
        child: Align(alignment: Alignment.bottomCenter, child: home),
      ),
    ),
  );
}

/// 기기에 울린 햅틱 종류를 모읍니다.
List<String> _recordHaptics(WidgetTester tester) {
  final calls = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        calls.add(call.arguments as String);
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  return calls;
}

void main() {
  group('tab-bar', () {
    Widget bar({
      int index = 0,
      ValueChanged<int>? onSelect,
      VoidCallback? onTop,
    }) => MyungliTabBar(
      index: index,
      onSelect: onSelect ?? (_) {},
      onScrollToTop: onTop,
    );

    testWidgets('탭 4개의 이름이 ARB로 나옵니다', (tester) async {
      await tester.pumpWidget(_app(bar()));
      for (final label in ['오늘', '달력', '일기', '나']) {
        expect(find.text(label), findsOneWidget);
      }
    });

    testWidgets('다른 탭을 누르면 onSelect와 selection 햅틱', (tester) async {
      final haptics = _recordHaptics(tester);
      final selected = <int>[];
      await tester.pumpWidget(_app(bar(onSelect: selected.add)));
      await tester.tap(find.text('일기'));
      expect(selected, [2]);
      expect(haptics, ['HapticFeedbackType.selectionClick']);
    });

    testWidgets('선택된 탭을 다시 누르면 맨 위로만 올리고 햅틱도 없습니다', (tester) async {
      final haptics = _recordHaptics(tester);
      final selected = <int>[];
      var top = 0;
      await tester.pumpWidget(
        _app(bar(index: 1, onSelect: selected.add, onTop: () => top++)),
      );
      await tester.tap(find.text('달력'));
      expect(selected, isEmpty);
      expect(top, 1);
      expect(haptics, isEmpty);
    });

    testWidgets('탭마다 역할 tab, 선택 알림, 최소 터치 48', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(bar(index: 1)));
      for (var i = 0; i < 4; i++) {
        final finder = find.byKey(ValueKey('tab-bar.tab.$i'));
        final node = tester.getSemantics(finder);
        expect(node.getSemanticsData().role, SemanticsRole.tab, reason: '$i');
        expect(
          node.getSemanticsData().flagsCollection.isSelected,
          i == 1 ? Tristate.isTrue : Tristate.isFalse,
          reason: '$i',
        );
        final size = tester.getSize(finder);
        expect(size.width, greaterThanOrEqualTo(48));
        expect(size.height, greaterThanOrEqualTo(48));
      }
      handle.dispose();
    });

    testWidgets('도장은 선택된 탭 하나에만 있고 바뀌면 옮겨 갑니다', (tester) async {
      await tester.pumpWidget(_app(bar()));
      await tester.pumpAndSettle();
      expect(find.byType(Seal), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('tab-bar.tab.0')),
          matching: find.byType(Seal),
        ),
        findsOneWidget,
      );
      await tester.pumpWidget(_app(bar(index: 3)));
      // 이전 도장은 지워지는 중이고 새 도장은 찍히는 중입니다.
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(Seal), findsNWidgets(2));
      await tester.pumpAndSettle();
      expect(find.byType(Seal), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('tab-bar.tab.3')),
          matching: find.byType(Seal),
        ),
        findsOneWidget,
      );
    });

    testWidgets('선택 탭은 Regular 아이콘, 나머지는 Light', (tester) async {
      await tester.pumpWidget(_app(bar(index: 2)));
      await tester.pumpAndSettle();
      final icons = tester
          .widgetList<AppIcon>(find.byType(AppIcon))
          .map((i) => i.weight)
          .toList();
      expect(icons, [
        AppIconWeight.light,
        AppIconWeight.light,
        AppIconWeight.regular,
        AppIconWeight.light,
      ]);
    });

    testWidgets('높이 72에 아래 안전 영역을 더하고 위 0.5px 선', (tester) async {
      tester.view
        ..devicePixelRatio = 1
        ..padding = const FakeViewPadding(bottom: 34)
        ..viewPadding = const FakeViewPadding(bottom: 34);
      addTearDown(() {
        tester.view
          ..resetDevicePixelRatio()
          ..resetPadding()
          ..resetViewPadding();
      });
      await tester.pumpWidget(_app(bar()));
      expect(tester.getSize(find.byType(MyungliTabBar)).height, 72 + 34);
      final line = tester.widget<DecoratedBox>(
        find.byKey(const ValueKey('tab-bar.top-border')),
      );
      final border = (line.decoration as BoxDecoration).border! as Border;
      expect(border.top.width, 0.5);
    });

    testWidgets('글자 크기 2.0에서도 넘치지 않고 탭이 48 이상', (tester) async {
      tester.view
        ..physicalSize = const Size(360, 800)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _app(
          MediaQuery(
            data: const MediaQueryData(
              size: Size(360, 800),
              textScaler: TextScaler.linear(2),
            ),
            child: bar(),
          ),
          locale: const Locale('ja'),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byKey(const ValueKey('tab-bar.tab.1'))).height,
        greaterThanOrEqualTo(48),
      );
    });

    testWidgets('투명도 줄이기는 bg.sheet 불투명에 흐림 없음', (tester) async {
      await tester.pumpWidget(_app(bar()));
      expect(find.byType(BackdropFilter), findsOneWidget);
      await tester.pumpWidget(_app(bar(), prefs: _transparent));
      expect(find.byType(BackdropFilter), findsNothing);
      final context = tester.element(find.byType(MyungliTabBar));
      final surface = tester.widget<ColoredBox>(
        find.byKey(const ValueKey('tab-bar.surface')),
      );
      expect(surface.color, context.tokens.colors.bgSheet);
    });
  });

  group('app-bar', () {
    testWidgets('tab-root: 높이 44, 제목은 header', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(const MyungliAppBar.tabRoot(title: '오늘')));
      expect(tester.getSize(find.byType(MyungliAppBar)).height, 44);
      expect(find.text('오늘'), findsOneWidget);
      expect(
        tester
            .getSemantics(find.text('오늘'))
            .getSemanticsData()
            .flagsCollection
            .isHeader,
        isTrue,
      );
      handle.dispose();
    });

    testWidgets('inner: 뒤로 버튼은 44 이상이고 onBack을 부릅니다', (tester) async {
      final handle = tester.ensureSemantics();
      var backs = 0;
      await tester.pumpWidget(
        _app(MyungliAppBar.inner(title: '일기', onBack: () => backs++)),
      );
      final back = find.bySemanticsLabel('뒤로');
      expect(back, findsOneWidget);
      final size = tester.getSize(find.byKey(const ValueKey('app-bar.back')));
      expect(size.width, greaterThanOrEqualTo(44));
      expect(size.height, greaterThanOrEqualTo(44));
      await tester.tap(find.byKey(const ValueKey('app-bar.back')));
      expect(backs, 1);
      handle.dispose();
    });

    testWidgets('동작은 두 개까지이고 각각 44 터치 영역', (tester) async {
      var taps = 0;
      AppBarAction action(String label) => AppBarAction(
        icon: const AppGlyph(
          light: PhosphorIconsLight.heart,
          regular: PhosphorIconsRegular.heart,
        ),
        semanticLabel: label,
        onPressed: () => taps++,
      );
      await tester.pumpWidget(
        _app(
          MyungliAppBar.tabRoot(
            title: '오늘',
            actions: [action('하나'), action('둘')],
          ),
        ),
      );
      final targets = find.byType(AppBarAction);
      expect(targets, findsNWidgets(2));
      expect(tester.getSize(targets.first), const Size(44, 44));
      await tester.tap(targets.last);
      expect(taps, 1);
      await tester.pumpWidget(
        _app(
          MyungliAppBar.tabRoot(
            title: 'x',
            actions: [action('1'), action('2'), action('3')],
          ),
        ),
      );
      expect(tester.takeException(), isA<AssertionError>());
    });

    testWidgets('바탕·그림자·선이 없습니다', (tester) async {
      await tester.pumpWidget(_app(const MyungliAppBar.tabRoot(title: '오늘')));
      final bar = find.byType(MyungliAppBar);
      expect(
        find.descendant(of: bar, matching: find.byType(PhysicalModel)),
        findsNothing,
      );
      expect(
        find.descendant(of: bar, matching: find.byType(BackdropFilter)),
        findsNothing,
      );
      expect(
        find.descendant(of: bar, matching: find.byType(ColoredBox)),
        findsNothing,
      );
    });
  });

  group('sheet', () {
    Future<void> open(
      WidgetTester tester,
      SheetSize size, {
      Widget? content,
    }) async {
      await tester.pumpWidget(_app(const SizedBox.expand()));
      unawaited(
        showMyungliSheet<void>(
          _navigatorKey.currentContext!,
          size: size,
          builder: (_) => content ?? const SizedBox(height: 4000),
        ),
      );
    }

    testWidgets('half는 화면의 60%까지', (tester) async {
      tester.view
        ..physicalSize = const Size(400, 900)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await open(tester, SheetSize.half);
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byType(MyungliSheetFrame)).height,
        closeTo(900 * 0.6, 0.01),
      );
    });

    testWidgets('full은 위 안전 영역 + 12까지', (tester) async {
      tester.view
        ..physicalSize = const Size(400, 900)
        ..devicePixelRatio = 1
        ..padding = const FakeViewPadding(top: 47)
        ..viewPadding = const FakeViewPadding(top: 47);
      addTearDown(() {
        tester.view
          ..reset()
          ..resetPadding()
          ..resetViewPadding();
      });
      await open(tester, SheetSize.full);
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byType(MyungliSheetFrame)).height,
        closeTo(900 - 47 - 12, 0.01),
      );
    });

    testWidgets('sheet.enter: 420ms 동안 enter 곡선으로 올라옵니다', (tester) async {
      tester.view
        ..physicalSize = const Size(400, 900)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await open(tester, SheetSize.half);
      await tester.pump(); // 첫 프레임: 진행 0
      final height = tester.getSize(find.byType(MyungliSheetFrame)).height;
      expect(tester.getTopLeft(find.byType(MyungliSheetFrame)).dy, 900);
      await tester.pump(const Duration(milliseconds: 210));
      final v = Motion.enter.transform(0.5);
      expect(
        tester.getTopLeft(find.byType(MyungliSheetFrame)).dy,
        closeTo(900 - height + (1 - v) * height, 0.5),
      );
      await tester.pump(const Duration(milliseconds: 210));
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.byType(MyungliSheetFrame)).dy,
        closeTo(900 - height, 0.01),
      );
    });

    testWidgets('손잡이 36x4와 덮개 scrim', (tester) async {
      await open(tester, SheetSize.half);
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byKey(const ValueKey('sheet.handle'))),
        const Size(36, 4),
      );
      final context = tester.element(find.byType(MyungliSheetFrame));
      final scrim = tester.widget<ColoredBox>(
        find.descendant(
          of: find.byKey(const ValueKey('sheet.scrim')),
          matching: find.byType(ColoredBox),
        ),
      );
      expect(scrim.color, context.tokens.colors.scrim);
    });

    testWidgets('접근성: 닫기 라벨 덮개와 dialog 역할', (tester) async {
      final handle = tester.ensureSemantics();
      await open(tester, SheetSize.half);
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('닫기'), findsOneWidget);
      expect(
        tester
            .getSemantics(find.byType(MyungliSheetFrame))
            .getSemanticsData()
            .role,
        SemanticsRole.dialog,
      );
      handle.dispose();
    });

    testWidgets('뒤로 가기는 맨 위 시트 하나만 닫습니다(stack)', (tester) async {
      tester.view
        ..physicalSize = const Size(400, 900)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app(const SizedBox.expand()));
      unawaited(
        showMyungliSheet<void>(
          _navigatorKey.currentContext!,
          size: SheetSize.half,
          builder: (context) => SizedBox(
            key: const ValueKey('sheet-a'),
            height: 4000,
            child: TextButton(
              onPressed: () => showMyungliSheet<void>(
                context,
                size: SheetSize.half,
                builder: (_) =>
                    const SizedBox(key: ValueKey('sheet-b'), height: 4000),
              ),
              child: const Text('깊이'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final before = tester.getSize(find.byKey(const ValueKey('sheet-a')));
      await tester.tap(find.text('깊이'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('sheet-b')), findsOneWidget);
      // 아래 층은 0.94배로 물러납니다.
      final a = find.byKey(const ValueKey('sheet-a'));
      final scaled = tester.getBottomRight(a).dx - tester.getTopLeft(a).dx;
      expect(scaled, closeTo(before.width * 0.94, 0.5));

      _navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('sheet-b')), findsNothing);
      expect(find.byKey(const ValueKey('sheet-a')), findsOneWidget);
      final restored = tester.getBottomRight(a).dx - tester.getTopLeft(a).dx;
      expect(restored, closeTo(before.width, 0.5));
    });

    testWidgets('덮개를 누르면 쌓인 시트가 모두 닫힙니다', (tester) async {
      tester.view
        ..physicalSize = const Size(400, 900)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app(const SizedBox.expand()));
      unawaited(
        showMyungliSheet<void>(
          _navigatorKey.currentContext!,
          size: SheetSize.half,
          builder: (context) => TextButton(
            onPressed: () => showMyungliSheet<void>(
              context,
              size: SheetSize.half,
              builder: (_) =>
                  const SizedBox(key: ValueKey('sheet-b'), height: 100),
            ),
            child: const Text('깊이'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('깊이'));
      await tester.pumpAndSettle();
      expect(find.byType(MyungliSheetFrame), findsNWidgets(2));
      await tester.tapAt(const Offset(200, 20));
      await tester.pumpAndSettle();
      expect(find.byType(MyungliSheetFrame), findsNothing);
    });

    testWidgets('아래로 끌면 맨 위 시트가 닫힙니다', (tester) async {
      tester.view
        ..physicalSize = const Size(400, 900)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await open(tester, SheetSize.half);
      await tester.pumpAndSettle();
      await tester.fling(
        find.byKey(const ValueKey('sheet.handle')),
        const Offset(0, 300),
        1500,
      );
      await tester.pumpAndSettle();
      expect(find.byType(MyungliSheetFrame), findsNothing);
    });
  });

  group('ad-banner', () {
    Widget banner({
      bool adFree = false,
      bool consent = true,
      FakeAds? ads,
      MotionPrefs prefs = _normal,
    }) => _app(
      AdBanner(adFree: adFree, consentGiven: consent),
      ads: ads,
      prefs: prefs,
    );

    double height(WidgetTester tester) =>
        tester.getSize(find.byType(AdBanner)).height;

    testWidgets('adFree는 높이 0', (tester) async {
      await tester.pumpWidget(banner(adFree: true));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(AdBanner)), Size.zero);
    });

    testWidgets('noConsent는 높이 0', (tester) async {
      await tester.pumpWidget(banner(consent: false));
      await tester.pumpAndSettle();
      expect(height(tester), 0);
    });

    testWidgets('loading은 자리를 잡지 않고 loaded는 광고+여백+선', (tester) async {
      await tester.pumpWidget(banner());
      expect(height(tester), 0);
      await tester.pumpAndSettle();
      // 광고 50 + 위아래 space.4 + 위 선 0.5.
      expect(height(tester), 50 + 4 + 4 + 0.5);
    });

    testWidgets('noFill은 처음부터 자리를 잡지 않아 레이아웃이 튀지 않습니다', (tester) async {
      await tester.pumpWidget(banner(ads: FakeAds(bannerAvailable: false)));
      final heights = <double>[height(tester)];
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        heights.add(height(tester));
      }
      expect(heights, everyElement(0));
    });

    testWidgets('불러오기 오류도 noFill과 같습니다', (tester) async {
      await tester.pumpWidget(
        banner(ads: FakeAds(bannerFailWith: const OfflineError())),
      );
      await tester.pumpAndSettle();
      expect(height(tester), 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('광고 제거가 켜지면 자리째 사라집니다', (tester) async {
      await tester.pumpWidget(banner());
      await tester.pumpAndSettle();
      expect(height(tester), greaterThan(0));
      await tester.pumpWidget(banner(adFree: true));
      await tester.pump(const Duration(milliseconds: 100));
      expect(height(tester), inExclusiveRange(0, 58.5));
      await tester.pumpAndSettle();
      expect(height(tester), 0);
    });

    testWidgets('loaded 바탕은 bar.bg 흐림, 투명도 줄이기는 bg.sheet', (tester) async {
      await tester.pumpWidget(banner());
      await tester.pumpAndSettle();
      expect(find.byType(BackdropFilter), findsOneWidget);
      await tester.pumpWidget(banner(prefs: _transparent));
      await tester.pumpAndSettle();
      expect(find.byType(BackdropFilter), findsNothing);
      final context = tester.element(find.byType(AdBanner));
      final surface = tester.widget<ColoredBox>(
        find.byKey(const ValueKey('ad-banner.surface')),
      );
      expect(surface.color, context.tokens.colors.bgSheet);
    });

    testWidgets('region 역할과 광고 라벨', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(banner());
      await tester.pumpAndSettle();
      final node = tester
          .getSemantics(find.byKey(const ValueKey('ad-banner.region')))
          .getSemanticsData();
      expect(node.role, SemanticsRole.region);
      expect(node.label, '광고');
      handle.dispose();
    });
  });
}
