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
import 'package:myungli_diary/design/components/action/breathing_dots.dart';
import 'package:myungli_diary/design/components/diary/draft_indicator.dart';
import 'package:myungli_diary/design/components/frame/ad_banner.dart';
import 'package:myungli_diary/design/components/frame/app_bar.dart';
import 'package:myungli_diary/design/components/frame/bottom_bar.dart';
import 'package:myungli_diary/design/components/frame/onboarding_page_layout.dart';
import 'package:myungli_diary/design/components/frame/scroll_hint.dart';
import 'package:myungli_diary/design/components/frame/section_header.dart';
import 'package:myungli_diary/design/components/frame/sheet.dart';
import 'package:myungli_diary/design/components/frame/tab_bar.dart';
import 'package:myungli_diary/design/elements/app_icon.dart';
import 'package:myungli_diary/design/elements/seal.dart';
import 'package:myungli_diary/design/interaction/motion_prefs.dart';
import 'package:myungli_diary/design/interaction/patterns.dart';
import 'package:myungli_diary/design/theme/app_theme.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';
import 'package:phosphor_glyphs/phosphor_glyphs.dart';

import '../support/error_text_style.dart';
import '../support/sheet_close.dart';

const MotionPrefs _normal = MotionPrefs(
  reduceMotion: false,
  reduceTransparency: false,
  lowEnd: false,
);
const MotionPrefs _reducedMotion = MotionPrefs(
  reduceMotion: true,
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

/// 폭 360 휴대폰 화면으로 맞춥니다(가로 위치 단언용).
void _phone(WidgetTester tester) {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = const Size(360, 640);
  addTearDown(tester.view.reset);
}

/// 겹 화살표([icon])의 지금 투명도(seep 전환이 끝나면 보임 1, 숨김 0).
double _arrowOpacity(WidgetTester tester, IconData icon) => tester
    .widget<AnimatedOpacity>(
      find.ancestor(
        of: find.byIcon(icon),
        matching: find.byType(AnimatedOpacity),
      ),
    )
    .opacity;

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

    testWidgets('titleIdentifier는 제목 노드의 identifier입니다', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          const MyungliAppBar.tabRoot(
            title: '달력',
            titleIdentifier: 'calendar.bar.title',
          ),
        ),
      );
      final title = find.bySemanticsIdentifier('calendar.bar.title');
      expect(title, findsOneWidget);
      expect(tester.getSemantics(title).label, '달력');
      handle.dispose();
    });

    testWidgets('inner: 제목이 비면 빈 header 노드를 만들지 않습니다', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(const MyungliAppBar.inner(title: '')));
      final headers = find.byWidgetPredicate(
        (widget) => widget is Semantics && widget.properties.header == true,
      );
      expect(headers, findsNothing);
      await tester.pumpWidget(_app(const MyungliAppBar.inner(title: '일기')));
      expect(headers, findsOneWidget);
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

    testWidgets('inner: showBack이 false면 뒤로 버튼이 없습니다', (tester) async {
      await tester.pumpWidget(
        _app(const MyungliAppBar.inner(title: '', showBack: false)),
      );
      expect(find.byKey(const ValueKey('app-bar.back')), findsNothing);
    });

    testWidgets('inner: 뒤로를 숨기면 자리를 비워 두지 않고 제목은 tabRoot와 같은 곳에서 시작합니다', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const MyungliAppBar.tabRoot(title: '오늘')));
      final rootStart = tester.getTopLeft(find.text('오늘')).dx;
      await tester.pumpWidget(
        _app(const MyungliAppBar.inner(title: '오늘', showBack: false)),
      );
      final hiddenStart = tester.getTopLeft(find.text('오늘')).dx;
      expect(hiddenStart, rootStart);
      expect(hiddenStart, Space.s16);
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

    testWidgets('Material 조상이 없는 navigator에 쌓여도 글자가 오류 스타일(노란 밑줄)을 받지 않습니다', (
      tester,
    ) async {
      await open(tester, SheetSize.half, content: const Text('글'));
      await tester.pumpAndSettle();
      final style = DefaultTextStyle.of(tester.element(find.text('글'))).style;
      expectNoErrorTextStyle(style);
    });

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
      final a = find.byKey(const ValueKey('sheet-a'));
      final before = tester.getRect(a);
      await tester.tap(find.text('깊이'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('sheet-b')), findsOneWidget);
      // 아래 층은 크기 그대로 머리 14px만큼 위로 올라갑니다(V110).
      expect(tester.getRect(a).width, closeTo(before.width, 0.01));
      expect(tester.getRect(a).top, closeTo(before.top - 14, 0.01));

      _navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('sheet-b')), findsNothing);
      expect(find.byKey(const ValueKey('sheet-a')), findsOneWidget);
      expect(tester.getRect(a), before);
    });

    testWidgets('바깥을 누르면 맨 위 시트 하나씩 닫힙니다(V100)', (tester) async {
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
      expect(find.byType(MyungliSheetFrame), findsOneWidget);
      expect(find.byKey(const ValueKey('sheet-b')), findsNothing);
      expect(find.text('깊이'), findsOneWidget);
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
      MotionPrefs prefs = _normal,
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
      prefs: prefs,
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

    testWidgets('움직임 줄이기에서 광고 제거가 켜져도 바로 사라지고 선이 탭 바 위로 돌아옵니다', (tester) async {
      // 사라짐이 0초라 배너 갱신 중에 끝나도 하단 틀을 빌드 도중에 다시 그리지 않습니다.
      await tester.pumpWidget(bottom(prefs: _reducedMotion));
      await tester.pumpAndSettle();
      expect(lineIsAboveBanner(tester), isTrue);
      await tester.pumpWidget(bottom(adFree: true, prefs: _reducedMotion));
      await tester.pump();
      expect(tester.takeException(), isNull);
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

    testWidgets('좌우와 아래 안쪽 24, 핸들 자리 높이 24, 제목은 그 아래 8', (tester) async {
      await openBody(
        tester,
        (_) => const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SheetHeading(child: Text('제목', key: ValueKey('title'))),
              SizedBox(key: ValueKey('last'), height: 40),
            ],
          ),
        ),
      );
      final frame = find.byType(MyungliSheetFrame);
      final frameRect = tester.getRect(frame);
      final title = tester.getRect(find.byKey(const ValueKey('title')));
      final last = tester.getRect(find.byKey(const ValueKey('last')));
      expect(title.left - frameRect.left, Space.s24);
      expect(frameRect.right - last.right, Space.s24);
      expect(frameRect.bottom - last.bottom, Space.s24);
      // 핸들 자리 24 + 제목 위 8.
      expect(title.top - frameRect.top, 24 + Space.s8);
      final handle = tester.getRect(find.byKey(const ValueKey('sheet.handle')));
      expect(handle.center.dy - frameRect.top, 12, reason: '핸들 자리 가운데');
      expect(handle.center.dx, closeTo(frameRect.center.dx, 0.01));
      final area = tester.getRect(
        find.byKey(const ValueKey('sheet.handleArea')),
      );
      expect(area.top, frameRect.top);
      expect(area.height, 44, reason: '끌기 터치 44');
      expect(area.width, frameRect.width);
    });

    testWidgets('핸들 자리를 끌면 본문이 스크롤된 상태여도 시트가 내려가고 닫힙니다', (tester) async {
      await openBody(tester, (_) => list(40));
      await tester.drag(
        find.byKey(const ValueKey('sheet-body')),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();
      // 손잡이 아래 30px(핸들 자리 24 밖, 터치 44 안)에서 끕니다.
      final top = tester.getTopLeft(find.byType(MyungliSheetFrame));
      await tester.timedDragFrom(
        top + const Offset(200, 30),
        const Offset(0, 300),
        const Duration(seconds: 1),
      );
      await tester.pumpAndSettle();
      expect(find.byType(MyungliSheetFrame), findsNothing);
    });

    test('닫기 판정: 시트 높이의 정확히 25%에서 닫히고 그 아래는 닫히지 않습니다', () {
      expect(
        sheetShouldDismiss(distance: 135, velocity: 0, sheetHeight: 540),
        isTrue,
      );
      expect(
        sheetShouldDismiss(distance: 134.9, velocity: 0, sheetHeight: 540),
        isFalse,
      );
      expect(
        sheetShouldDismiss(distance: 0, velocity: 701, sheetHeight: 540),
        isTrue,
      );
    });

    // 본문을 맨 위까지 되스크롤하며 경계를 걸친 첫 갱신에서, 스크롤한 몫은 닫기 거리에
    // 들지 않고 경계 아래로 넘어간 몫만 듭니다.
    for (final (beyondDelta, closes) in [(-10.0, false), (10.0, true)]) {
      testWidgets(
        'ios: 경계를 걸친 첫 갱신은 넘어간 몫만 셉니다(25% ${beyondDelta < 0 ? '미만' : '초과'})',
        (tester) async {
          debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
          try {
            final controller = ScrollController();
            addTearDown(controller.dispose);
            await openBody(
              tester,
              (_) => ListView(
                key: const ValueKey('sheet-body'),
                controller: controller,
                children: [
                  for (var i = 0; i < 40; i++)
                    SizedBox(height: 48, child: Text('항목 $i')),
                ],
              ),
            );
            controller.jumpTo(60);
            await tester.pump();
            final sheetHeight = tester
                .getSize(find.byType(MyungliSheetFrame))
                .height;
            final gesture = await tester.startGesture(
              tester.getCenter(find.byKey(const ValueKey('sheet-body'))),
            );
            // 드래그 인식 거리(slop)를 넘깁니다. 본문은 아직 범위 안입니다.
            await gesture.moveBy(const Offset(0, 20));
            await tester.pump();
            final remaining = controller.position.pixels;
            expect(remaining, greaterThan(30));
            // 한 번의 이동으로 남은 스크롤을 다 쓰고 경계 아래로 넘어갑니다.
            final beyond = sheetHeight * 0.25 + beyondDelta;
            await gesture.moveBy(Offset(0, remaining + beyond));
            await tester.pump();
            expect(controller.position.pixels, lessThan(0));
            // 멈췄다 놓아 속도로는 닫히지 않게 합니다.
            await tester.pump(const Duration(milliseconds: 300));
            await gesture.up();
            await tester.pumpAndSettle();
            expect(
              find.byType(MyungliSheetFrame),
              closes ? findsNothing : findsOneWidget,
            );
          } finally {
            debugDefaultTargetPlatformOverride = null;
          }
        },
      );
    }

    // F-027: 본문이 half 높이를 조금 넘는 SingleChildScrollView일 때 천천히 끌어
    // 닫으면 시트가 떨리거나 닫히지 않던 버그.
    for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
      testWidgets(
        '${platform.name}: half보다 조금 긴 본문을 천천히 끌면 떨림 없이 따라오고 놓으면 닫힙니다',
        (tester) async {
          debugDefaultTargetPlatformOverride = platform;
          try {
            await openBody(
              tester,
              (_) => const SingleChildScrollView(
                key: ValueKey('sheet-body'),
                child: SizedBox(height: 900 * 0.6 + 80, width: 300),
              ),
            );
            final frame = find.byType(MyungliSheetFrame);
            final tops = <double>[];
            var recording = true;
            tester.binding.addPersistentFrameCallback((_) {
              if (!recording || frame.evaluate().isEmpty) return;
              tops.add(tester.getTopLeft(frame).dy);
            });
            addTearDown(() => recording = false);
            await tester.timedDrag(
              find.byKey(const ValueKey('sheet-body')),
              const Offset(0, 300),
              const Duration(seconds: 1),
            );
            final whileDragging = List<double>.of(tops);
            await tester.pumpAndSettle();
            recording = false;
            for (var i = 1; i < whileDragging.length; i++) {
              expect(
                whileDragging[i],
                greaterThanOrEqualTo(whileDragging[i - 1] - 0.5),
                reason: 'frame $i: ${whileDragging.join(', ')}',
              );
            }
            expect(frame, findsNothing);
          } finally {
            debugDefaultTargetPlatformOverride = null;
          }
        },
      );
    }

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

    testWidgets('ios: bounce 상쇄는 본문 viewport 높이를 바꾸지 않고 놓은 뒤 복귀가 튀지 않습니다', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        await openBody(tester, (_) => list(40));
        final frame = find.byType(MyungliSheetFrame);
        final body = find.byKey(const ValueKey('sheet-body'));
        final item = find.text('항목 0');
        final baseTop = tester.getTopLeft(frame).dy;
        final baseHeight = tester.getSize(body).height;
        final baseRel = tester.getTopLeft(item).dy - baseTop;
        final gesture = await dragSlowlyThenStop(
          tester,
          body,
          waitBeforeRelease: true,
        );
        final moved = tester.getTopLeft(frame).dy - baseTop;
        expect(moved, greaterThan(0));
        // 본문 viewport 높이는 그대로입니다(A120, F-027).
        expect(tester.getSize(body).height, baseHeight);
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
          expect(tester.getSize(body).height, baseHeight, reason: 'frame $i');
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

    testWidgets('쌓여도 덮개는 하나이고 뒤 화면은 크기 그대로입니다(V110)', (tester) async {
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
      expect(width(), 400);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('screen')),
          matching: find.byType(Transform),
        ),
        findsNothing,
      );
      _navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();
      expect(width(), closeTo(400, 0.5));
    });

    testWidgets('화면 셸 안쪽 navigator에서 열어도 셸 바깥에 쌓이고 바깥 누르기는 한 단계씩 닫습니다', (
      tester,
    ) async {
      // 탭 화면처럼 SheetScreenBelow 안쪽에 navigator가 있어도, 시트는 셸 바깥 navigator에
      // 쌓여 덮개가 화면 전체(탭 바 포함)를 덮습니다.
      tester.view
        ..physicalSize = const Size(400, 900)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      late BuildContext inner;
      await tester.pumpWidget(
        _app(
          SheetScreenBelow(
            child: Navigator(
              onGenerateRoute: (_) => MaterialPageRoute<void>(
                builder: (context) {
                  inner = context;
                  return const SizedBox.expand();
                },
              ),
            ),
          ),
        ),
      );
      unawaited(
        showMyungliSheet<void>(
          inner,
          size: SheetSize.half,
          builder: (context) => TextButton(
            onPressed: () => showMyungliSheet<void>(
              context,
              size: SheetSize.full,
              builder: (_) => const SizedBox(height: 100),
            ),
            child: const Text('깊이'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('깊이'));
      await tester.pumpAndSettle();
      expect(find.byType(MyungliSheetFrame), findsNWidgets(2));
      expect(Navigator.of(inner).canPop(), isFalse, reason: '셸 바깥에 쌓임');
      expect(
        tester.getRect(find.byKey(const ValueKey('sheet.scrim'))),
        const Rect.fromLTWH(0, 0, 400, 900),
      );

      await tapSheetScrim(tester);
      await tester.pumpAndSettle();
      expect(find.byType(MyungliSheetFrame), findsOneWidget);

      await tapSheetScrim(tester);
      await tester.pumpAndSettle();
      expect(find.byType(MyungliSheetFrame), findsNothing);
    });

    testWidgets('앱 안의 앱(바깥 작업대 MaterialApp)에서는 안쪽 navigator에 안쪽 테마로 쌓입니다', (
      tester,
    ) async {
      // Widgetbook처럼 바깥 MaterialApp 안에 미리보기용
      // MyungliTokens 테마 MaterialApp이 있는 경우.
      late BuildContext outer;
      late BuildContext inner;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              outer = context;
              return MaterialApp(
                locale: const Locale('ko'),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                theme: buildTheme(
                  brightness: Brightness.light,
                  locale: const Locale('ko'),
                ),
                home: Builder(
                  builder: (context) {
                    inner = context;
                    return const SizedBox.expand();
                  },
                ),
              );
            },
          ),
        ),
      );
      unawaited(
        showMyungliSheet<void>(
          inner,
          size: SheetSize.half,
          builder: (context) => Text(
            '시트',
            style: TextStyle(color: context.tokens.colors.textPrimary),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(MyungliSheetFrame), findsOneWidget);
      expect(Navigator.of(inner).canPop(), isTrue);
      expect(Navigator.of(outer).canPop(), isFalse);
    });
  });
  group('sheet.stack peek (V110)', () {
    const lowerKey = ValueKey('lower');
    const upperKey = ValueKey('upper');

    /// 아래 시트([lower] 크기, 내용 높이 [lowerHeight])를 열고 그 안에서 위 시트를 엽니다.
    /// [settle]이 false면 위 시트를 연 첫 프레임에서 멈춥니다.
    Future<void> openStack(
      WidgetTester tester, {
      required SheetSize lower,
      required double lowerHeight,
      required SheetSize upper,
      required double upperHeight,
      bool reduceMotion = false,
      bool settle = true,
      bool upperBlocksPop = false,
    }) async {
      tester.view
        ..physicalSize = const Size(400, 900)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      // 시트는 home 바깥 navigator에 쌓이므로 기기 설정(MediaQuery)으로 동작 줄이기를 줍니다.
      if (reduceMotion) {
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(disableAnimations: true);
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
      }
      await tester.pumpWidget(_app(const SizedBox.expand()));
      unawaited(
        showMyungliSheet<void>(
          _navigatorKey.currentContext!,
          size: lower,
          semanticLabel: '아래 시트',
          builder: (context) => SingleChildScrollView(
            child: SizedBox(
              key: lowerKey,
              height: lowerHeight,
              child: Align(
                alignment: Alignment.topLeft,
                child: TextButton(
                  onPressed: () => showMyungliSheet<void>(
                    context,
                    size: upper,
                    builder: (_) => PopScope(
                      canPop: !upperBlocksPop,
                      child: SingleChildScrollView(
                        child: SizedBox(key: upperKey, height: upperHeight),
                      ),
                    ),
                  ),
                  child: const Text('깊이'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('깊이'));
      if (settle) await tester.pumpAndSettle();
    }

    Finder frameOf(Key key) => find.ancestor(
      of: find.byKey(key),
      matching: find.byType(MyungliSheetFrame),
    );

    // sheet.stack 덮개는 누르기를 받지 않는(IgnorePointer) 검은 ColoredBox입니다.
    double veilAlpha(WidgetTester tester) => tester
        .widgetList<ColoredBox>(
          find.descendant(
            of: find.byType(IgnorePointer),
            matching: find.byType(ColoredBox),
          ),
        )
        .map((box) => box.color)
        .where((color) => color.r == 0 && color.g == 0 && color.b == 0)
        .map((color) => color.a)
        .fold(0, (a, b) => a > b ? a : b);

    test('올라갈 거리는 위 시트 높이 + 14 - 아래 시트 높이이고 음수면 0입니다', () {
      expect(sheetStackLift(below: 200, above: 540), 354);
      expect(sheetStackLift(below: 554, above: 540), 0);
      expect(sheetStackLift(below: 888, above: 540), 0);
    });

    testWidgets('아래 시트가 짧으면 머리 14px가 보이게 올라가고 밝기 0.92, 크기는 그대로', (
      tester,
    ) async {
      await openStack(
        tester,
        lower: SheetSize.half,
        lowerHeight: 200,
        upper: SheetSize.half,
        upperHeight: 4000,
      );
      final lower = tester.getRect(frameOf(lowerKey));
      final upper = tester.getRect(frameOf(upperKey));
      expect(upper.height, closeTo(540, 0.01));
      expect(
        lower.top,
        closeTo(upper.top - PatternValues.stackPeekHeight, 0.01),
      );
      expect(lower.width, 400, reason: '크기 그대로');
      expect(veilAlpha(tester), closeTo(1 - 0.92, 0.001));
    });

    testWidgets('아래 시트가 이미 더 크면 움직이지 않고 어두워지기만 합니다', (tester) async {
      await openStack(
        tester,
        lower: SheetSize.full,
        lowerHeight: 4000,
        upper: SheetSize.half,
        upperHeight: 4000,
      );
      expect(
        tester.getRect(frameOf(lowerKey)).top,
        closeTo(sheetFullTopGap, 0.01),
      );
      expect(veilAlpha(tester), closeTo(0.08, 0.001));
    });

    testWidgets('올라갈 자리가 없으면 위 시트 높이를 줄여 14px를 남기고 위 시트 안이 스크롤됩니다', (
      tester,
    ) async {
      await openStack(
        tester,
        lower: SheetSize.full,
        lowerHeight: 4000,
        upper: SheetSize.full,
        upperHeight: 4000,
      );
      final lower = tester.getRect(frameOf(lowerKey));
      final upper = tester.getRect(frameOf(upperKey));
      expect(lower.top, closeTo(sheetFullTopGap, 0.01));
      expect(upper.height, closeTo(900 - sheetFullTopGap - 14, 0.01));
      expect(upper.top - lower.top, closeTo(14, 0.01));
      // 줄어든 높이에 들어가지 않는 내용은 위 시트 안에서 스크롤됩니다.
      final scroll = find.ancestor(
        of: find.byKey(upperKey),
        matching: find.byType(Scrollable),
      );
      final position = tester.state<ScrollableState>(scroll.first).position;
      expect(position.maxScrollExtent, greaterThan(0));
    });

    testWidgets('보이는 머리 띠를 누르면 맨 위 시트 하나만 닫힙니다', (tester) async {
      await openStack(
        tester,
        lower: SheetSize.half,
        lowerHeight: 200,
        upper: SheetSize.half,
        upperHeight: 4000,
      );
      final upper = tester.getRect(frameOf(upperKey));
      await tester.tapAt(Offset(200, upper.top - 7));
      await tester.pumpAndSettle();
      expect(find.byKey(upperKey), findsNothing);
      expect(find.byKey(lowerKey), findsOneWidget);
      // 아래 시트는 제자리로 내려오고 덮개가 걷힙니다.
      expect(tester.getRect(frameOf(lowerKey)).bottom, 900);
      expect(veilAlpha(tester), 0);
    });

    testWidgets('바깥 누르기도 PopScope가 막으면 닫지 않습니다', (tester) async {
      await openStack(
        tester,
        lower: SheetSize.half,
        lowerHeight: 200,
        upper: SheetSize.half,
        upperHeight: 100,
        upperBlocksPop: true,
      );
      await tester.tapAt(const Offset(200, 20));
      await tester.pumpAndSettle();
      expect(find.byKey(upperKey), findsOneWidget);
    });

    testWidgets('위 시트를 끌어 내리는 동안 아래 시트가 그 비율만큼 내려오고 덮개도 걷힙니다', (tester) async {
      await openStack(
        tester,
        lower: SheetSize.half,
        lowerHeight: 200,
        upper: SheetSize.half,
        upperHeight: 4000,
      );
      const restingTop = 900 - (24 + 200 + 24.0);
      final liftedTop = tester.getRect(frameOf(lowerKey)).top;
      final lift = restingTop - liftedTop;
      final upperHeight = tester.getRect(frameOf(upperKey)).height;

      final handle = tester.getRect(frameOf(upperKey)).topCenter;
      final gesture = await tester.startGesture(handle + const Offset(0, 10));
      await gesture.moveBy(const Offset(0, 20));
      await gesture.moveBy(const Offset(0, 100));
      await tester.pump();
      final dragged =
          tester.getRect(frameOf(upperKey)).top - (900 - upperHeight);
      final release = dragged / upperHeight;
      expect(release, greaterThan(0));
      expect(
        tester.getRect(frameOf(lowerKey)).top,
        closeTo(restingTop - lift * (1 - release), 0.5),
      );
      expect(veilAlpha(tester), closeTo(0.08 * (1 - release), 0.001));

      // 놓아서 제자리로 돌아오면 다시 올라갑니다.
      await gesture.up();
      await tester.pumpAndSettle();
      expect(tester.getRect(frameOf(lowerKey)).top, closeTo(liftedTop, 0.01));
    });

    testWidgets('기본: 아래 시트는 sheet.stack 동안 올라갑니다(중간 프레임은 사이 값)', (
      tester,
    ) async {
      await openStack(
        tester,
        lower: SheetSize.half,
        lowerHeight: 200,
        upper: SheetSize.half,
        upperHeight: 4000,
        settle: false,
      );
      const restingTop = 900 - (24 + 200 + 24.0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final mid = tester.getRect(frameOf(lowerKey)).top;
      await tester.pumpAndSettle();
      final end = tester.getRect(frameOf(lowerKey)).top;
      expect(mid, lessThan(restingTop));
      expect(mid, greaterThan(end));
    });

    testWidgets('동작 줄이기: 아래 시트는 이동 없이 바로 올라간 자리이고 덮개 투명도만 바뀝니다', (
      tester,
    ) async {
      await openStack(
        tester,
        lower: SheetSize.half,
        lowerHeight: 200,
        upper: SheetSize.half,
        upperHeight: 4000,
        reduceMotion: true,
        settle: false,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final upperTop = 900 - tester.getRect(frameOf(upperKey)).height;
      expect(
        tester.getRect(frameOf(lowerKey)).top,
        closeTo(upperTop - 14, 0.01),
        reason: '중간 프레임에서도 이미 올라간 자리',
      );
      final midVeil = veilAlpha(tester);
      expect(midVeil, greaterThan(0));
      expect(midVeil, lessThan(0.08));
      await tester.pumpAndSettle();
      expect(veilAlpha(tester), closeTo(0.08, 0.001));
    });

    testWidgets('위 시트가 열린 동안 아래 시트(머리 띠 포함)는 스크린리더에서 숨습니다', (tester) async {
      final handle = tester.ensureSemantics();
      await openStack(
        tester,
        lower: SheetSize.half,
        lowerHeight: 200,
        upper: SheetSize.half,
        upperHeight: 100,
      );
      expect(find.semantics.byLabel('아래 시트'), findsNothing);
      expect(find.semantics.byLabel('깊이'), findsNothing);
      // 닫기(바깥) 동작은 맨 위 시트의 것 하나만 보입니다. 누르면 맨 위 시트만 닫힙니다.
      expect(find.semantics.byLabel('닫기'), findsOneWidget);
      tester.semantics.tap(find.semantics.byLabel('닫기'));
      await tester.pumpAndSettle();
      expect(find.byKey(upperKey), findsNothing);
      expect(find.byKey(lowerKey), findsOneWidget);
      expect(find.semantics.byLabel('아래 시트'), findsOneWidget);
      expect(find.semantics.byLabel('닫기'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('pop으로 위 시트를 닫으면 아래 시트가 다시 스크린리더에 보입니다', (tester) async {
      final handle = tester.ensureSemantics();
      await openStack(
        tester,
        lower: SheetSize.half,
        lowerHeight: 200,
        upper: SheetSize.half,
        upperHeight: 100,
      );
      expect(find.semantics.byLabel('아래 시트'), findsNothing);
      _navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.semantics.byLabel('아래 시트'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('내용이 최대 높이를 넘으면 시트 안이 스크롤되고 핸들 자리는 맨 위에 남습니다', (tester) async {
      tester.view
        ..physicalSize = const Size(400, 900)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app(const SizedBox.expand()));
      unawaited(
        showMyungliSheet<void>(
          _navigatorKey.currentContext!,
          size: SheetSize.half,
          builder: (_) => const SingleChildScrollView(
            key: ValueKey('body'),
            child: Column(
              children: [
                SizedBox(height: 2000),
                SizedBox(key: ValueKey('last'), height: 40),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final frame = tester.getRect(find.byType(MyungliSheetFrame));
      expect(frame.height, closeTo(540, 0.01));
      await tester.drag(
        find.byKey(const ValueKey('body')),
        const Offset(0, -3000),
      );
      await tester.pumpAndSettle();
      expect(find.byType(MyungliSheetFrame), findsOneWidget);
      expect(
        tester.getRect(find.byKey(const ValueKey('sheet.handle'))).center.dy,
        frame.top + 12,
        reason: '핸들 자리는 스크롤되지 않음',
      );
      expect(
        tester.getRect(find.byKey(const ValueKey('last'))).bottom,
        closeTo(frame.bottom - Space.s24, 0.01),
        reason: '맨 아래 내용 뒤 space.24',
      );
    });
  });

  group('onboarding-page-layout', () {
    for (final inset in [0.0, 34.0, 48.0]) {
      testWidgets(
        'inset $inset: 버튼만 있는 화면의 맨 아래 버튼은 inset 위 space.16입니다(V106)',
        (tester) async {
          tester.view
            ..physicalSize = const Size(400, 800)
            ..devicePixelRatio = 1
            ..padding = FakeViewPadding(bottom: inset)
            ..viewPadding = FakeViewPadding(bottom: inset);
          addTearDown(() {
            tester.view
              ..reset()
              ..resetPadding()
              ..resetViewPadding();
          });
          await tester.pumpWidget(
            MaterialApp(
              theme: buildTheme(
                brightness: Brightness.light,
                locale: const Locale('ko'),
              ),
              home: const Scaffold(
                body: SafeArea(
                  child: OnboardingPageLayout(
                    body: [Text('안내')],
                    actions: [SizedBox(key: ValueKey('last'), height: 52)],
                  ),
                ),
              ),
            ),
          );
          expect(
            tester.getBottomLeft(find.byKey(const ValueKey('last'))).dy,
            800 - inset - OnboardingPageLayout.bottomGap,
          );
          expect(OnboardingPageLayout.bottomGap, Space.s16);
        },
      );
    }
  });

  group('section-header', () {
    Widget host(
      Widget child, {
      Locale locale = const Locale('ko'),
      double textScale = 1,
    }) => MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: buildTheme(brightness: Brightness.light, locale: locale),
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(360, 640),
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(
          body: Align(alignment: Alignment.topLeft, child: child),
        ),
      ),
    );

    testWidgets('시작선은 부모 내용 여백을 따릅니다(화면 20, 시트 24)', (tester) async {
      _phone(tester);
      Widget inset(double value) => host(
        Padding(
          padding: EdgeInsets.symmetric(horizontal: value),
          child: const SectionHeader(title: '제목'),
        ),
      );
      await tester.pumpWidget(inset(20));
      expect(tester.getTopLeft(find.text('제목')).dx, 20);
      final text = tester.widget<Text>(find.text('제목'));
      final tokens = tester.element(find.text('제목')).tokens;
      expect(text.style!.fontWeight, FontWeight.w600);
      expect(text.style!.fontSize, tokens.typography.labelLg.fontSize);
      expect(text.style!.color, tokens.colors.textPrimary);
      await tester.pumpWidget(inset(24));
      expect(tester.getTopLeft(find.text('제목')).dx, 24);
    });

    testWidgets('설명은 제목 아래 space.2이고 간격 상수는 12, 32입니다', (tester) async {
      await tester.pumpWidget(
        host(const SectionHeader(title: '제목', description: '설명')),
      );
      final gap =
          tester.getTopLeft(find.text('설명')).dy -
          tester.getBottomLeft(find.text('제목')).dy;
      expect(gap, 2);
      final context = tester.element(find.text('설명'));
      expect(
        tester.widget<Text>(find.text('설명')).style!.color,
        context.tokens.colors.textSecondary,
      );
      expect(SectionHeader.contentGap, Space.s12);
      expect(SectionHeader.sectionGap, Space.s32);
    });

    testWidgets('link: 글자와 꺾쇠, 누르면 onTap, 링크로 읽습니다', (tester) async {
      final handle = tester.ensureSemantics();
      var taps = 0;
      await tester.pumpWidget(
        host(
          SectionHeader(
            title: '제목',
            trailing: SectionHeaderLink(label: '더 보기', onTap: () => taps++),
          ),
        ),
      );
      expect(find.byIcon(PhosphorIconsLight.caretRight), findsOneWidget);
      expect(
        tester.getSemantics(find.text('더 보기')).flagsCollection.isLink,
        isTrue,
      );
      await tester.tap(find.text('더 보기'));
      expect(taps, 1);
      handle.dispose();
    });

    testWidgets('action: 아이콘 동작은 44 폭 터치 영역이고 이름으로 읽습니다', (tester) async {
      _phone(tester);
      final handle = tester.ensureSemantics();
      var taps = 0;
      await tester.pumpWidget(
        host(
          SectionHeader(
            title: '제목',
            trailing: SectionHeaderAction(
              icon: const AppGlyph(
                light: PhosphorIconsLight.plus,
                regular: PhosphorIconsRegular.plus,
              ),
              semanticLabel: '추가',
              onTap: () => taps++,
            ),
          ),
        ),
      );
      expect(find.byIcon(PhosphorIconsLight.plus), findsOneWidget);
      await tester.tap(find.byIcon(PhosphorIconsLight.plus));
      expect(taps, 1);
      // 그림 24의 오른쪽 끝이 끝선(부모 내용 끝)에 닿고, 터치 44는 왼쪽으로만 넓어집니다.
      expect(tester.getSize(find.byIcon(PhosphorIconsLight.plus)).width, 24);
      expect(tester.getTopRight(find.byIcon(PhosphorIconsLight.plus)).dx, 360);
      final iconRect = tester.getRect(find.byIcon(PhosphorIconsLight.plus));
      await tester.tapAt(iconRect.centerLeft - const Offset(15, 0));
      expect(taps, 2);
      await tester.tapAt(iconRect.centerLeft - const Offset(25, 0));
      expect(taps, 2);
      await tester.tapAt(iconRect.centerRight + const Offset(8, 0));
      expect(taps, 2);
      handle.dispose();
    });

    testWidgets('ActionWidget은 받은 위젯을 오른쪽 끝에 놓습니다', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        host(
          const SectionHeader(
            title: '제목',
            trailing: SectionHeaderActionWidget(
              SizedBox(key: ValueKey('custom'), width: 200, height: 30),
            ),
          ),
        ),
      );
      expect(tester.getTopRight(find.byKey(const ValueKey('custom'))).dx, 360);
      expect(tester.getSize(find.byKey(const ValueKey('custom'))).width, 200);
    });

    for (final scale in [1.3, 2.0]) {
      testWidgets('ja textScale $scale: 제목이 줄바꿈되어도 오른쪽 자리는 밀려나지 않습니다', (
        tester,
      ) async {
        _phone(tester);
        const title = '今日の運勢と過去の記録をまとめて確認する長い見出しです';
        await tester.pumpWidget(
          host(
            SectionHeader(
              title: title,
              trailing: SectionHeaderLink(label: 'もっと見る', onTap: () {}),
            ),
            locale: const Locale('ja'),
            textScale: scale,
          ),
        );
        expect(tester.takeException(), isNull);
        final titleBox = tester.getRect(find.text(title));
        final link = tester.getRect(find.text('もっと見る'));
        expect(
          titleBox.height,
          greaterThan(
            tester
                    .element(find.text(title))
                    .tokens
                    .typography
                    .labelLg
                    .fontSize! *
                scale *
                1.2,
          ),
        );
        expect(link.right, lessThanOrEqualTo(360 + 0.01));
        expect(titleBox.right, lessThanOrEqualTo(link.left));
      });
    }
  });

  group('scroll-hint', () {
    Widget hint(ScrollController controller, {MotionPrefs prefs = _normal}) =>
        _app(
          prefs: prefs,
          SizedBox(
            width: 300,
            child: ScrollHint(
              controller: controller,
              child: SizedBox(
                height: 40,
                child: ListView(
                  controller: controller,
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (var i = 0; i < 10; i++)
                      SizedBox(width: 100, child: Text('칸$i')),
                  ],
                ),
              ),
            ),
          ),
        );

    testWidgets('처음에는 왼쪽 겹 화살표가 숨고 오른쪽만 보입니다', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(hint(controller));
      await tester.pump();
      expect(_arrowOpacity(tester, PhosphorIconsLight.caretDoubleLeft), 0);
      expect(_arrowOpacity(tester, PhosphorIconsLight.caretDoubleRight), 1);
    });

    testWidgets('오른쪽 화살표는 보이는 폭만큼 넘기고, 끝에서는 숨습니다', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(hint(controller));
      await tester.pump();
      await tester.tap(find.byIcon(PhosphorIconsLight.caretDoubleRight));
      await tester.pumpAndSettle();
      expect(controller.offset, 300);
      expect(_arrowOpacity(tester, PhosphorIconsLight.caretDoubleLeft), 1);
      expect(_arrowOpacity(tester, PhosphorIconsLight.caretDoubleRight), 1);
      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pump();
      await tester.pump();
      expect(_arrowOpacity(tester, PhosphorIconsLight.caretDoubleRight), 0);
      await tester.tap(find.byIcon(PhosphorIconsLight.caretDoubleLeft));
      await tester.pumpAndSettle();
      expect(controller.offset, 400);
    });

    testWidgets('컨트롤러를 바꾸면 옛 리스너를 풀고 새 컨트롤러로 다시 셉니다', (tester) async {
      final first = ScrollController(initialScrollOffset: 700);
      final second = ScrollController();
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      await tester.pumpWidget(hint(first));
      await tester.pumpAndSettle();
      expect(_arrowOpacity(tester, PhosphorIconsLight.caretDoubleLeft), 1);
      expect(_arrowOpacity(tester, PhosphorIconsLight.caretDoubleRight), 0);
      // 리스너 해제 확인용으로 보호된 hasListeners를 읽습니다.
      // ignore: invalid_use_of_protected_member
      expect(first.hasListeners, isTrue);
      await tester.pumpWidget(hint(second));
      await tester.pumpAndSettle();
      // 리스너 해제 확인용으로 보호된 hasListeners를 읽습니다.
      // ignore: invalid_use_of_protected_member
      expect(first.hasListeners, isFalse);
      // 리스너 해제 확인용으로 보호된 hasListeners를 읽습니다.
      // ignore: invalid_use_of_protected_member
      expect(second.hasListeners, isTrue);
      // 새 컨트롤러가 이어받은 끝 쪽 위치로 다시 센 상태입니다.
      expect(second.offset, 700);
      expect(_arrowOpacity(tester, PhosphorIconsLight.caretDoubleLeft), 1);
      expect(_arrowOpacity(tester, PhosphorIconsLight.caretDoubleRight), 0);
    });

    testWidgets('화살표가 바뀌면 한 프레임 뒤 투명도가 0과 1 사이입니다(seep)', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(hint(controller));
      await tester.pump();
      controller.jumpTo(300);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      final fade = tester.widget<FadeTransition>(
        find
            .ancestor(
              of: find.byIcon(PhosphorIconsLight.caretDoubleLeft),
              matching: find.byType(FadeTransition),
            )
            .first,
      );
      expect(fade.opacity.value, inExclusiveRange(0, 1));
      await tester.pumpAndSettle();
      expect(fade.opacity.value, 1);
    });

    testWidgets('움직임 줄이기: 바로 그 자리로 넘어갑니다', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(hint(controller, prefs: _reducedMotion));
      await tester.pump();
      await tester.tap(find.byIcon(PhosphorIconsLight.caretDoubleRight));
      await tester.pump();
      expect(controller.offset, 300);
    });

    testWidgets('화살표는 스크린리더에서 숨고 터치 영역은 44입니다', (tester) async {
      final handle = tester.ensureSemantics();
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(hint(controller));
      await tester.pump();
      final arrow = find.byIcon(PhosphorIconsLight.caretDoubleRight);
      expect(
        find.ancestor(of: arrow, matching: find.byType(ExcludeSemantics)),
        findsWidgets,
      );
      final target = find.ancestor(of: arrow, matching: find.byType(SizedBox));
      expect(tester.getSize(target.first), const Size.square(44));
      handle.dispose();
    });
  });

  group('app-bar edit', () {
    Widget bar({
      Widget? status,
      String title = '일기 쓰기',
      AppBarTextAction? action,
      Locale locale = const Locale('ko'),
      VoidCallback? onBack,
    }) => _app(
      MyungliAppBar.edit(
        onBack: onBack ?? () {},
        title: title,
        status: status,
        textAction: action ?? AppBarTextAction(label: '저장', onTap: () {}),
      ),
      locale: locale,
    );

    testWidgets('높이 44, 가운데 제목은 label.lg이고 정중앙입니다', (tester) async {
      _phone(tester);
      await tester.pumpWidget(bar());
      expect(tester.getSize(find.byType(MyungliAppBar)).height, 44);
      final text = tester.widget<Text>(find.text('일기 쓰기'));
      final tokens = tester.element(find.text('일기 쓰기')).tokens;
      expect(text.style!.fontSize, tokens.typography.labelLg.fontSize);
      expect(tester.getCenter(find.text('일기 쓰기')).dx, 180);
    });

    testWidgets('status가 있으면 가운데 제목 대신 status가 보입니다', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        bar(
          status: const DraftIndicator(
            state: DraftIndicatorState.local,
            label: '임시 저장됨',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('임시 저장됨'), findsOneWidget);
      // 제목은 그려지지 않고(보이지 않음) 머리 이름으로만 남습니다.
      expect(
        find.ancestor(
          of: find.text('일기 쓰기'),
          matching: find.byWidgetPredicate(
            (w) => w is Visibility && !w.visible,
          ),
        ),
        findsOneWidget,
      );
      expect(tester.getCenter(find.byType(DraftIndicator)).dx, 180);
      await tester.pumpWidget(bar());
      await tester.pumpAndSettle();
      expect(find.text('일기 쓰기'), findsOneWidget);
      expect(find.byType(DraftIndicator), findsNothing);
    });

    double alphaOf(WidgetTester tester, String key) => tester
        .widget<Opacity>(
          find
              .ancestor(
                of: find.byKey(ValueKey('app-bar.center.$key')),
                matching: find.byType(Opacity),
              )
              .first,
        )
        .opacity;

    const indicator = DraftIndicator(
      state: DraftIndicatorState.local,
      label: '임시 저장됨',
    );

    testWidgets('제목에서 status로: 들어오는 status는 0에서 올라가고 제목은 1에서 내려갑니다', (
      tester,
    ) async {
      await tester.pumpWidget(bar());
      await tester.pumpWidget(bar(status: indicator));
      expect(alphaOf(tester, 'status'), 0);
      expect(alphaOf(tester, 'title'), 1);
      await tester.pump(const Duration(milliseconds: 100));
      final incoming = alphaOf(tester, 'status');
      final outgoing = alphaOf(tester, 'title');
      expect(incoming, inExclusiveRange(0, 1));
      expect(outgoing, inExclusiveRange(0, 1));
      await tester.pump(const Duration(milliseconds: 50));
      expect(alphaOf(tester, 'status'), greaterThan(incoming));
      expect(alphaOf(tester, 'title'), lessThan(outgoing));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('app-bar.center.title')), findsNothing);
    });

    testWidgets('status에서 제목으로: 들어오는 제목은 0에서 올라가고 status는 1에서 내려갑니다', (
      tester,
    ) async {
      await tester.pumpWidget(bar(status: indicator));
      await tester.pumpAndSettle();
      await tester.pumpWidget(bar());
      expect(alphaOf(tester, 'title'), 0);
      expect(alphaOf(tester, 'status'), 1);
      await tester.pump(const Duration(milliseconds: 100));
      final incoming = alphaOf(tester, 'title');
      final outgoing = alphaOf(tester, 'status');
      expect(incoming, inExclusiveRange(0, 1));
      expect(outgoing, inExclusiveRange(0, 1));
      await tester.pump(const Duration(milliseconds: 50));
      expect(alphaOf(tester, 'title'), greaterThan(incoming));
      expect(alphaOf(tester, 'status'), lessThan(outgoing));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('app-bar.center.status')), findsNothing);
    });

    testWidgets('머리 이름은 status가 있어도 화면 제목입니다', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        bar(
          status: const DraftIndicator(
            state: DraftIndicatorState.saved,
            label: '저장됨',
          ),
        ),
      );
      await tester.pumpAndSettle();
      final headers = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.header == true,
      );
      expect(headers, findsOneWidget);
      expect(tester.getSemantics(headers).label, '일기 쓰기');
      handle.dispose();
    });

    testWidgets('뒤로와 글자 버튼이 동작하고 글자 버튼은 44 이상입니다', (tester) async {
      _phone(tester);
      var backs = 0;
      var saves = 0;
      await tester.pumpWidget(
        bar(
          onBack: () => backs++,
          action: AppBarTextAction(label: '저장', onTap: () => saves++),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('app-bar.back')));
      await tester.tap(find.text('저장'));
      expect((backs, saves), (1, 1));
      final button = find.byType(AppBarTextAction);
      expect(tester.getSize(button).height, greaterThanOrEqualTo(44));
      expect(tester.getSize(button).width, greaterThanOrEqualTo(44));
      expect(tester.getSize(button).width, lessThanOrEqualTo(88));
      expect(tester.getTopRight(button).dx, 344);
      final style = tester.widget<Text>(find.text('저장')).style!;
      final colors = tester.element(find.text('저장')).tokens.colors;
      expect(style.color, colors.actionPrimary);
    });

    testWidgets('enabled false: disabled.fg이고 눌러도 부르지 않습니다', (tester) async {
      var saves = 0;
      await tester.pumpWidget(
        bar(
          action: AppBarTextAction(
            label: '저장',
            onTap: () => saves++,
            enabled: false,
          ),
        ),
      );
      final colors = tester.element(find.text('저장')).tokens.colors;
      expect(
        tester.widget<Text>(find.text('저장')).style!.color,
        colors.disabledFg,
      );
      await tester.tap(find.text('저장'), warnIfMissed: false);
      expect(saves, 0);
    });

    testWidgets('saving: 점 셋, 폭은 그대로, 다시 누를 수 없고 busy로 읽습니다', (tester) async {
      final handle = tester.ensureSemantics();
      var saves = 0;
      await tester.pumpWidget(
        bar(
          action: AppBarTextAction(label: '저장', onTap: () => saves++),
        ),
      );
      final before = tester.getSize(find.byType(AppBarTextAction));
      await tester.pumpWidget(
        bar(
          action: AppBarTextAction(
            label: '저장',
            onTap: () => saves++,
            saving: true,
          ),
        ),
      );
      expect(tester.getSize(find.byType(AppBarTextAction)), before);
      expect(find.byType(BreathingDots), findsOneWidget);
      await tester.tap(find.byType(AppBarTextAction), warnIfMissed: false);
      expect(saves, 0);
      final l10n = AppLocalizations.of(
        tester.element(find.byType(AppBarTextAction)),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('저장')).hint,
        l10n.actionBusy,
      );
      handle.dispose();
    });

    testWidgets('en 긴 글자: 최대 폭 88에서 한 줄 말줄임입니다', (tester) async {
      await tester.pumpWidget(
        bar(
          action: AppBarTextAction(label: 'Save the whole entry', onTap: () {}),
          locale: const Locale('en'),
        ),
      );
      expect(tester.getSize(find.byType(AppBarTextAction)).width, 88);
      final text = tester.widget<Text>(find.text('Save the whole entry'));
      expect(text.maxLines, 1);
      expect(text.overflow, TextOverflow.ellipsis);
      expect(tester.takeException(), isNull);
    });
  });
}
