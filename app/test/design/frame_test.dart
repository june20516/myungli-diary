import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/core/platform/ads.dart';
import 'package:myungli_diary/core/platform/fakes.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';
import 'package:myungli_diary/design/components/frame/ad_banner.dart';
import 'package:myungli_diary/design/components/frame/app_bar.dart';
import 'package:myungli_diary/design/components/frame/bottom_bar.dart';
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
  Ads? overrideAds,
  MotionPrefs prefs = _normal,
  Locale locale = const Locale('ko'),
}) {
  return ProviderScope(
    overrides: [adsProvider.overrideWithValue(overrideAds ?? ads ?? FakeAds())],
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

/// 불러오기·해제 횟수를 세는 광고 대역. 배너 안에 접근성 노드가 있습니다.
class _CountingAds implements Ads {
  int loaded = 0;
  int disposed = 0;

  @override
  Future<BannerAdHandle?> loadBanner({required int width}) async {
    loaded++;
    return _CountingBanner(() => disposed++);
  }

  @override
  Future<RewardedAdHandle?> loadRewarded({required String userId}) async =>
      null;
}

class _CountingBanner implements BannerAdHandle {
  new(this._onDispose);

  final VoidCallback _onDispose;

  @override
  Size get size => const Size(320, 50);

  @override
  Widget get view => Semantics(label: '광고 내용', child: const SizedBox());

  @override
  void dispose() => _onDispose();
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

  group('bottom-bar', () {
    Widget bottom({
      bool showAd = true,
      bool adFree = false,
      bool consent = true,
      FakeAds? ads,
      ValueChanged<double>? onHeight,
    }) => _app(
      MyungliBottomBar(
        index: 0,
        onSelect: (_) {},
        showAd: showAd,
        adFree: adFree,
        consentGiven: consent,
        onHeightChanged: onHeight,
      ),
      ads: ads,
    );

    /// 위 0.5px 선 개수(하단 틀 안).
    int lines(WidgetTester tester) => tester
        .widgetList<DecoratedBox>(
          find.descendant(
            of: find.byType(MyungliBottomBar),
            matching: find.byType(DecoratedBox),
          ),
        )
        .where((box) {
          final decoration = box.decoration;
          return decoration is BoxDecoration &&
              decoration.border is Border &&
              (decoration.border! as Border).top.width == 0.5;
        })
        .length;

    bool lineIsAboveBanner(WidgetTester tester) {
      final banner = tester.getTopLeft(
        find.byKey(const ValueKey('ad-banner.region')),
      );
      final tabs = tester.getTopLeft(
        find.byKey(const ValueKey('tab-bar.top-border')),
      );
      return banner.dy < tabs.dy;
    }

    testWidgets('바탕과 흐림은 하나이고 배너가 loaded면 선은 배너 위에 하나', (tester) async {
      await tester.pumpWidget(bottom());
      await tester.pumpAndSettle();
      expect(find.byType(BackdropFilter), findsOneWidget);
      expect(find.byKey(const ValueKey('ad-banner.surface')), findsNothing);
      expect(lines(tester), 1);
      expect(lineIsAboveBanner(tester), isTrue);
    });

    for (final (name, ads, adFree, consent, showAd) in [
      ('noFill', FakeAds(bannerAvailable: false), false, true, true),
      ('adFree', null, true, true, true),
      ('noConsent', null, false, false, true),
      ('탭 루트가 아닌 화면', null, false, true, false),
    ]) {
      testWidgets('$name이면 선은 탭 바 위에 하나', (tester) async {
        await tester.pumpWidget(
          bottom(ads: ads, adFree: adFree, consent: consent, showAd: showAd),
        );
        await tester.pumpAndSettle();
        expect(lines(tester), 1);
        expect(find.byKey(const ValueKey('ad-banner.region')), findsNothing);
      });
    }

    testWidgets('loading 동안에도 선은 하나, loaded가 되면 배너 위로 옮겨 갑니다', (tester) async {
      await tester.pumpWidget(bottom());
      expect(lines(tester), 1);
      expect(find.byKey(const ValueKey('ad-banner.region')), findsNothing);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(lines(tester), 1);
      await tester.pumpAndSettle();
      expect(lines(tester), 1);
      expect(lineIsAboveBanner(tester), isTrue);
    });

    testWidgets('광고 제거가 켜지면 선이 탭 바 위로 돌아옵니다', (tester) async {
      await tester.pumpWidget(bottom());
      await tester.pumpAndSettle();
      await tester.pumpWidget(bottom(adFree: true));
      await tester.pump(const Duration(milliseconds: 100));
      expect(lines(tester), 1);
      await tester.pumpAndSettle();
      expect(lines(tester), 1);
      expect(find.byKey(const ValueKey('ad-banner.region')), findsNothing);
    });

    testWidgets('높이 알림: 상태마다 탭 바 + 안전 영역 + 배너', (tester) async {
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
      final heights = <double>[];
      await tester.pumpWidget(bottom(onHeight: heights.add));
      await tester.pump();
      expect(heights.last, 72 + 34); // loading
      await tester.pumpAndSettle();
      expect(heights.last, 72 + 34 + 58.5); // loaded
      await tester.pumpWidget(bottom(adFree: true, onHeight: heights.add));
      await tester.pumpAndSettle();
      expect(heights.last, 72 + 34); // adFree
      await tester.pumpWidget(
        bottom(ads: FakeAds(bannerAvailable: false), onHeight: heights.add),
      );
      await tester.pumpAndSettle();
      expect(heights.last, 72 + 34); // noFill
      await tester.pumpWidget(bottom(consent: false, onHeight: heights.add));
      await tester.pumpAndSettle();
      expect(heights.last, 72 + 34); // noConsent
    });
  });

  group('ad-banner 보강', () {
    testWidgets('광고 제거 뒤 광고를 놓고, 다시 켜지면 새로 불러옵니다', (tester) async {
      final ads = _CountingAds();
      Widget build({required bool adFree}) =>
          _app(AdBanner(adFree: adFree, consentGiven: true), overrideAds: ads);
      await tester.pumpWidget(build(adFree: false));
      await tester.pumpAndSettle();
      expect(ads.loaded, 1);
      await tester.pumpWidget(build(adFree: true));
      await tester.pumpAndSettle();
      expect(ads.disposed, 1);
      await tester.pumpWidget(build(adFree: false));
      await tester.pumpAndSettle();
      expect(ads.loaded, 2);
    });

    testWidgets('광고 네트워크의 접근성 노드가 보입니다', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          const AdBanner(adFree: false, consentGiven: true),
          overrideAds: _CountingAds(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('광고 내용'), findsOneWidget);
      handle.dispose();
    });
  });

  group('sheet 보강', () {
    Future<void> openBody(WidgetTester tester, WidgetBuilder body) async {
      tester.view
        ..physicalSize = const Size(400, 900)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app(const SizedBox.expand()));
      unawaited(
        showMyungliSheet<void>(
          _navigatorKey.currentContext!,
          size: SheetSize.half,
          builder: body,
        ),
      );
      await tester.pumpAndSettle();
    }

    Widget list(int count) => ListView(
      key: const ValueKey('sheet-body'),
      children: [
        for (var i = 0; i < count; i++)
          SizedBox(height: 48, child: Text('항목 $i')),
      ],
    );

    // 플랫폼마다 본문 스크롤 물리(Clamping·Bouncing)가 달라 둘 다 확인합니다.
    for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
      final bodies = <String, WidgetBuilder>{
        '스크롤 없는 Column': (_) => const Column(
          key: ValueKey('sheet-body'),
          children: [SizedBox(height: 100, width: 300, child: Text('내용'))],
        ),
        '짧은 ListView': (_) => SizedBox(height: 150, child: list(2)),
        '긴 ListView': (_) => list(40),
      };
      for (final entry in bodies.entries) {
        testWidgets('${platform.name}: ${entry.key}에서 끌어내리면 닫힙니다', (
          tester,
        ) async {
          debugDefaultTargetPlatformOverride = platform;
          try {
            await openBody(tester, entry.value);
            await tester.fling(
              find.byKey(const ValueKey('sheet-body')),
              const Offset(0, 400),
              2500,
            );
            await tester.pumpAndSettle();
            expect(find.byType(MyungliSheetFrame), findsNothing);
          } finally {
            debugDefaultTargetPlatformOverride = null;
          }
        });
      }

      testWidgets('${platform.name}: 긴 본문이 스크롤된 상태에서는 스크롤만 합니다', (
        tester,
      ) async {
        debugDefaultTargetPlatformOverride = platform;
        try {
          await openBody(tester, (_) => list(40));
          final body = find.byKey(const ValueKey('sheet-body'));
          await tester.drag(body, const Offset(0, -300));
          await tester.pumpAndSettle();
          final top = tester.getTopLeft(find.byType(MyungliSheetFrame)).dy;
          await tester.drag(body, const Offset(0, 100));
          await tester.pumpAndSettle();
          expect(find.byType(MyungliSheetFrame), findsOneWidget);
          expect(tester.getTopLeft(find.byType(MyungliSheetFrame)).dy, top);
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      });

      testWidgets('${platform.name}: 조금 끌었다 놓으면 제자리로 돌아옵니다', (tester) async {
        debugDefaultTargetPlatformOverride = platform;
        try {
          await openBody(tester, (_) => list(40));
          final frame = find.byType(MyungliSheetFrame);
          final top = tester.getTopLeft(frame).dy;
          await tester.drag(
            find.byKey(const ValueKey('sheet-body')),
            const Offset(0, 40),
          );
          await tester.pumpAndSettle();
          expect(frame, findsOneWidget);
          expect(tester.getTopLeft(frame).dy, closeTo(top, 0.5));
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      });
    }

    testWidgets('android: 시트를 올리는 동안 본문은 스크롤되지 않습니다', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        await openBody(tester, (_) => list(40));
        final body = find.byKey(const ValueKey('sheet-body'));
        final position = tester
            .state<ScrollableState>(find.byType(Scrollable))
            .position;
        final gesture = await tester.startGesture(tester.getCenter(body));
        // 드래그 인식 거리(slop)를 먼저 넘깁니다.
        await gesture.moveBy(const Offset(0, 30));
        await tester.pump();
        await gesture.moveBy(const Offset(0, 100));
        await tester.pump();
        final dragged = tester.getTopLeft(find.byType(MyungliSheetFrame)).dy;
        await gesture.moveBy(const Offset(0, -60));
        await tester.pump();
        expect(position.pixels, 0);
        expect(
          tester.getTopLeft(find.byType(MyungliSheetFrame)).dy,
          lessThan(dragged),
        );
        await gesture.up();
        await tester.pumpAndSettle();
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('ios: 끄는 동안 본문은 시트 이동분만큼 되올려 이중으로 움직이지 않습니다', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        await openBody(tester, (_) => list(40));
        final body = find.byKey(const ValueKey('sheet-body'));
        final firstItem = find.text('항목 0');
        final before = tester.getTopLeft(firstItem).dy;
        final gesture = await tester.startGesture(tester.getCenter(body));
        await gesture.moveBy(const Offset(0, 30));
        await tester.pump();
        await gesture.moveBy(const Offset(0, 120));
        await tester.pump();
        final sheetMoved = tester.getTopLeft(find.byType(MyungliSheetFrame)).dy;
        // 시트 안에서 본문은 제자리입니다(시트 이동만 보임).
        expect(sheetMoved, greaterThan(900 - 540));
        final frameTop = sheetMoved;
        expect(
          tester.getTopLeft(firstItem).dy - frameTop,
          closeTo(before - (900 - 540), 1),
        );
        await gesture.up();
        await tester.pumpAndSettle();
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    Future<TestGesture> dragSlowlyThenStop(
      WidgetTester tester,
      Finder body, {
      required bool waitBeforeRelease,
    }) async {
      final base = tester.binding.currentSystemFrameTimeStamp;
      final gesture = await tester.startGesture(tester.getCenter(body));
      await gesture.moveBy(const Offset(0, 30), timeStamp: base);
      await tester.pump(const Duration(milliseconds: 16));
      for (var i = 1; i <= 4; i++) {
        await gesture.moveBy(
          const Offset(0, 20),
          timeStamp: tester.binding.currentSystemFrameTimeStamp,
        );
        await tester.pump(const Duration(milliseconds: 16));
      }
      if (waitBeforeRelease) {
        await tester.pump(const Duration(milliseconds: 300));
      }
      return gesture;
    }

    testWidgets('놓은 뒤 닫기 판정 전에 위에 다른 시트가 열리면 끌던 시트만 닫습니다', (tester) async {
      // iOS bounce 본문은 손을 뗀 뒤 첫 관성 프레임에서 닫기를 판정합니다. 그 사이
      // 용어 칩 등으로 설명 시트가 겹쳐 열리면, 닫기가 맨 위(새 시트)를 닫으면 안 됩니다.
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        await openBody(
          tester,
          (_) => ListView(
            key: const ValueKey('sheet-body'),
            children: [
              for (var i = 0; i < 40; i++)
                SizedBox(height: 48, child: Text('아래 $i')),
            ],
          ),
        );
        final base = tester.binding.currentSystemFrameTimeStamp;
        final gesture = await tester.startGesture(
          tester.getCenter(find.byKey(const ValueKey('sheet-body'))),
        );
        for (var i = 0; i <= 6; i++) {
          await gesture.moveBy(
            Offset(0, i == 0 ? 30 : 15),
            timeStamp: base + Duration(milliseconds: 8 * i),
          );
        }
        await gesture.up(timeStamp: base + const Duration(milliseconds: 56));
        unawaited(
          showMyungliSheet<void>(
            _navigatorKey.currentContext!,
            size: SheetSize.half,
            builder: (_) => const Text('위 시트'),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 16));
        await tester.pumpAndSettle();

        expect(find.text('위 시트'), findsOneWidget);
        expect(find.text('아래 0'), findsNothing);
        expect(find.byType(MyungliSheetFrame), findsOneWidget);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('겹친 뒤 닫기 판정이 와도 PopScope가 막으면 끌던 시트를 빼지 않습니다', (tester) async {
      // iOS bounce 본문은 손을 뗀 뒤 첫 관성 프레임에서 닫기를 판정합니다. 그 사이
      // 용어 칩 등으로 설명 시트가 겹쳐 열리면, 닫기가 맨 위(새 시트)를 닫으면 안 됩니다.
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        await openBody(
          tester,
          (_) => PopScope(
            canPop: false,
            child: ListView(
              key: const ValueKey('sheet-body'),
              children: [
                for (var i = 0; i < 40; i++)
                  SizedBox(height: 48, child: Text('아래 $i')),
              ],
            ),
          ),
        );
        final base = tester.binding.currentSystemFrameTimeStamp;
        final gesture = await tester.startGesture(
          tester.getCenter(find.byKey(const ValueKey('sheet-body'))),
        );
        for (var i = 0; i <= 6; i++) {
          await gesture.moveBy(
            Offset(0, i == 0 ? 30 : 15),
            timeStamp: base + Duration(milliseconds: 8 * i),
          );
        }
        await gesture.up(timeStamp: base + const Duration(milliseconds: 56));
        unawaited(
          showMyungliSheet<void>(
            _navigatorKey.currentContext!,
            size: SheetSize.half,
            builder: (_) => const Text('위 시트'),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 16));
        await tester.pumpAndSettle();

        expect(find.text('위 시트'), findsOneWidget);
        expect(find.text('아래 0'), findsOneWidget);
        expect(find.byType(MyungliSheetFrame), findsNWidgets(2));
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('ios: 짧게 끌다 멈춘 뒤 놓으면 닫히지 않습니다', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        await openBody(tester, (_) => list(40));
        final gesture = await dragSlowlyThenStop(
          tester,
          find.byKey(const ValueKey('sheet-body')),
          waitBeforeRelease: true,
        );
        await gesture.up();
        await tester.pumpAndSettle();
        expect(find.byType(MyungliSheetFrame), findsOneWidget);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    // 속도 추정기(VelocityTracker)의 정지 판정 시계는 flutter_test 바인딩이 가짜 시계
    // (debugSamplingClock)로 바꿔 주므로, 빠른 놓기도 결정적으로 확인할 수 있습니다.
    testWidgets('ios: 빠르게 끌고 바로 놓으면 거리가 짧아도 닫힙니다', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        await openBody(tester, (_) => list(40));
        final base = tester.binding.currentSystemFrameTimeStamp;
        final gesture = await tester.startGesture(
          tester.getCenter(find.byKey(const ValueKey('sheet-body'))),
        );
        // 8ms마다 15px씩(약 1,900px/s) 끌고, 시간을 흘리지 않고 바로 놓습니다.
        for (var i = 0; i <= 6; i++) {
          await gesture.moveBy(
            Offset(0, i == 0 ? 30 : 15),
            timeStamp: base + Duration(milliseconds: 8 * i),
          );
        }
        final frame = find.byType(MyungliSheetFrame);
        final sheetHeight = tester.getSize(frame).height;
        await gesture.up(timeStamp: base + const Duration(milliseconds: 56));
        // iOS bounce 본문은 놓은 뒤 첫 관성 프레임에서 놓기를 판정합니다. pumpAndSettle의
        // 첫 프레임(100ms)은 정지로 판정되므로 실제 기기처럼 16ms 프레임으로 넘깁니다.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 16));
        await tester.pumpAndSettle();
        expect(frame, findsNothing);
        expect(120, lessThan(sheetHeight * 0.25), reason: '거리로는 닫히지 않는 양');
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('ios: bounce 상쇄로 빈 띠가 없고 놓은 뒤 복귀가 튀지 않습니다', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        await openBody(tester, (_) => list(40));
        final frame = find.byType(MyungliSheetFrame);
        final body = find.byKey(const ValueKey('sheet-body'));
        final item = find.text('항목 0');
        final baseTop = tester.getTopLeft(frame).dy;
        final baseBottom = tester.getBottomLeft(body).dy;
        final baseRel = tester.getTopLeft(item).dy - baseTop;
        final gesture = await dragSlowlyThenStop(
          tester,
          body,
          waitBeforeRelease: true,
        );
        final moved = tester.getTopLeft(frame).dy - baseTop;
        expect(moved, greaterThan(0));
        // 본문 아래 끝이 시트와 같은 양만 움직여 빈 띠가 생기지 않습니다.
        expect(tester.getBottomLeft(body).dy - baseBottom, closeTo(moved, 1));
        expect(
          tester.getTopLeft(item).dy - tester.getTopLeft(frame).dy,
          closeTo(baseRel, 1),
        );
        await gesture.up();
        // 놓은 뒤 되돌아오는 구간을 프레임마다 봅니다.
        var previous = tester.getTopLeft(frame).dy;
        for (var i = 0; i < 60; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          final top = tester.getTopLeft(frame).dy;
          expect(top, lessThanOrEqualTo(previous + 0.5), reason: 'frame $i');
          expect(
            tester.getTopLeft(item).dy - top,
            closeTo(baseRel, 1),
            reason: 'frame $i',
          );
          expect(
            tester.getBottomLeft(body).dy - baseBottom,
            closeTo(top - baseTop, 1),
            reason: 'frame $i',
          );
          previous = top;
        }
        expect(tester.getTopLeft(frame).dy, closeTo(baseTop, 0.5));
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('끌기가 취소되면 제자리로 돌아옵니다', (tester) async {
      await openBody(
        tester,
        (_) => const Column(
          key: ValueKey('sheet-body'),
          children: [SizedBox(height: 100, width: 300, child: Text('내용'))],
        ),
      );
      final frame = find.byType(MyungliSheetFrame);
      final baseTop = tester.getTopLeft(frame).dy;
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('sheet-body'))),
      );
      await gesture.moveBy(const Offset(0, 30));
      await tester.pump();
      await gesture.moveBy(const Offset(0, 80));
      await tester.pump();
      expect(tester.getTopLeft(frame).dy, greaterThan(baseTop));
      await gesture.cancel();
      await tester.pumpAndSettle();
      expect(frame, findsOneWidget);
      expect(tester.getTopLeft(frame).dy, closeTo(baseTop, 0.5));
    });

    testWidgets('닫기가 막히면(PopScope) 시트가 제자리로 돌아오고 다시 끌 수 있습니다', (tester) async {
      await openBody(
        tester,
        (_) => const PopScope(
          canPop: false,
          child: Column(
            key: ValueKey('sheet-body'),
            children: [SizedBox(height: 100, width: 300, child: Text('내용'))],
          ),
        ),
      );
      final frame = find.byType(MyungliSheetFrame);
      final body = find.byKey(const ValueKey('sheet-body'));
      final baseTop = tester.getTopLeft(frame).dy;
      await tester.fling(body, const Offset(0, 400), 2500);
      await tester.pumpAndSettle();
      expect(frame, findsOneWidget);
      expect(tester.getTopLeft(frame).dy, closeTo(baseTop, 0.5));
      // 복구 뒤에도 끌기가 동작합니다.
      final gesture = await tester.startGesture(tester.getCenter(body));
      await gesture.moveBy(const Offset(0, 30));
      await tester.pump();
      await gesture.moveBy(const Offset(0, 60));
      await tester.pump();
      expect(tester.getTopLeft(frame).dy, greaterThan(baseTop));
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('첫 제목으로 스크린리더 초점이 갑니다(첫 SheetHeading만)', (tester) async {
      final handle = tester.ensureSemantics();
      final messages = <Object?>[];
      tester.binding.defaultBinaryMessenger
          .setMockDecodedMessageHandler<dynamic>(SystemChannels.accessibility, (
            message,
          ) async {
            messages.add(message);
            return null;
          });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger
            .setMockDecodedMessageHandler<dynamic>(
              SystemChannels.accessibility,
              null,
            ),
      );
      await tester.pumpWidget(_app(const SizedBox.expand()));
      unawaited(
        showMyungliSheet<void>(
          _navigatorKey.currentContext!,
          size: SheetSize.half,
          builder: (_) => const Column(
            children: [
              SheetHeading(child: Text('첫 제목')),
              SheetHeading(child: Text('둘째 제목')),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      final focus = messages
          .whereType<Map<Object?, Object?>>()
          .where((m) => m['type'] == 'focus')
          .toList();
      expect(focus, hasLength(1));
      handle.dispose();
    });

    testWidgets('쌓여도 덮개는 하나이고 아래 화면이 0.92배로 물러납니다', (tester) async {
      tester.view
        ..physicalSize = const Size(400, 900)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _app(
          const SheetScreenBelow(
            child: SizedBox.expand(key: ValueKey('screen')),
          ),
        ),
      );
      final screen = find.byKey(const ValueKey('screen'));
      double width() =>
          tester.getBottomRight(screen).dx - tester.getTopLeft(screen).dx;
      expect(width(), 400);
      unawaited(
        showMyungliSheet<void>(
          _navigatorKey.currentContext!,
          size: SheetSize.half,
          builder: (context) => TextButton(
            onPressed: () => showMyungliSheet<void>(
              context,
              size: SheetSize.half,
              builder: (_) => const SizedBox(height: 100),
            ),
            child: const Text('깊이'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(width(), 400); // 첫 시트만으로는 화면이 물러나지 않습니다.
      await tester.tap(find.text('깊이'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('sheet.scrim')), findsOneWidget);
      expect(width(), closeTo(400 * 0.92, 0.5));
      _navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();
      expect(width(), closeTo(400, 0.5));
    });
  });
}
