import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myungli_diary/core/platform/fakes.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';
import 'package:myungli_diary/design/components/frame/app_bar.dart';
import 'package:myungli_diary/design/components/frame/bottom_bar.dart';
import 'package:myungli_diary/design/components/frame/sheet.dart';
import 'package:myungli_diary/design/components/frame/tab_bar.dart';
import 'package:myungli_diary/design/elements/app_icon.dart';
import 'package:myungli_diary/design/interaction/motion_prefs.dart';
import 'package:myungli_diary_widgetbook/stage.dart';
import 'package:phosphor_glyphs/phosphor_glyphs.dart';
import 'package:widgetbook/widgetbook.dart';

const AppGlyph _more = AppGlyph(
  light: PhosphorIconsLight.dotsThree,
  regular: PhosphorIconsRegular.dotsThree,
);

const MotionPrefs _transparent = MotionPrefs(
  reduceMotion: false,
  reduceTransparency: true,
  lowEnd: false,
);

/// 줄무늬 위에 틀을 올려 반투명·흐림이 보이게 합니다.
class _OverStripes extends StatelessWidget {
  const new({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return SizedBox(
      height: 260,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Positioned.fill(
            child: Row(
              children: [
                for (var i = 0; i < 16; i++)
                  Expanded(
                    child: ColoredBox(
                      color: i.isEven ? color : color.withValues(alpha: 0.3),
                      child: const SizedBox.expand(),
                    ),
                  ),
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _TabBarDemo extends StatefulWidget {
  const new({this.initial = 0});

  final int initial;

  @override
  State<_TabBarDemo> createState() => _TabBarDemoState();
}

class _TabBarDemoState extends State<_TabBarDemo> {
  late int _index = widget.initial;
  int _scrollToTop = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _OverStripes(
          child: MyungliTabBar(
            index: _index,
            onSelect: (i) => setState(() => _index = i),
            onScrollToTop: () => setState(() => _scrollToTop++),
          ),
        ),
        Text('맨 위로 $_scrollToTop번'),
      ],
    );
  }
}

Widget _sheetOpener(String label, SheetSize size) => Builder(
  builder: (context) => FilledButton(
    onPressed: () => showMyungliSheet<void>(
      context,
      size: size,
      semanticLabel: label,
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('시트 내용'),
          ),
          TextButton(
            onPressed: () => showMyungliSheet<void>(
              sheetContext,
              size: SheetSize.half,
              builder: (_) => const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('한 단계 더 깊이(sheet.stack)'),
              ),
            ),
            child: const Text('더 깊이'),
          ),
        ],
      ),
    ),
    child: Text(label),
  ),
);

Widget _adBanner({
  required bool adFree,
  required bool consent,
  required bool available,
  MotionPrefs? prefs,
}) {
  final stack = ProviderScope(
    overrides: [
      adsProvider.overrideWithValue(FakeAds(bannerAvailable: available)),
    ],
    child: _OverStripes(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          MyungliBottomBar(
            index: 0,
            onSelect: (_) {},
            showAd: true,
            adFree: adFree,
            consentGiven: consent,
          ),
        ],
      ),
    ),
  );
  return Stage(
    child: prefs == null ? stack : MotionPrefsScope(prefs: prefs, child: stack),
  );
}

/// 화면 틀 카탈로그: tab-bar, app-bar, sheet, ad-banner.
final WidgetbookFolder frameDirectory = WidgetbookFolder(
  name: '화면 틀',
  children: [
    WidgetbookComponent(
      name: 'tab-bar',
      useCases: [
        WidgetbookUseCase(
          name: '선택 · 다시 누르면 맨 위로',
          builder: (context) => const Stage(child: _TabBarDemo()),
        ),
        WidgetbookUseCase(
          name: '투명도 줄이기',
          builder: (context) => const Stage(
            child: MotionPrefsScope(
              prefs: _transparent,
              child: _TabBarDemo(initial: 2),
            ),
          ),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'app-bar',
      useCases: [
        WidgetbookUseCase(
          name: 'tab-root',
          builder: (context) => Stage(
            child: MyungliAppBar.tabRoot(
              title: '오늘',
              actions: [
                AppBarAction(
                  icon: _more,
                  semanticLabel: '더보기',
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
        WidgetbookUseCase(
          name: 'inner',
          builder: (context) => Stage(
            child: MyungliAppBar.inner(
              title: '일기',
              status: const Text('저장됨'),
              actions: [
                AppBarAction(
                  icon: _more,
                  semanticLabel: '더보기',
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'sheet',
      useCases: [
        WidgetbookUseCase(
          name: 'half · 안에서 한 겹 더',
          builder: (context) =>
              Stage(child: _sheetOpener('half 시트 열기', SheetSize.half)),
        ),
        WidgetbookUseCase(
          name: 'full',
          builder: (context) =>
              Stage(child: _sheetOpener('full 시트 열기', SheetSize.full)),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'ad-banner (하단 틀 안)',
      useCases: [
        WidgetbookUseCase(
          name: 'loaded',
          builder: (context) =>
              _adBanner(adFree: false, consent: true, available: true),
        ),
        WidgetbookUseCase(
          name: 'loaded · 투명도 줄이기',
          builder: (context) => _adBanner(
            adFree: false,
            consent: true,
            available: true,
            prefs: _transparent,
          ),
        ),
        WidgetbookUseCase(
          name: 'noFill (자리 없음)',
          builder: (context) =>
              _adBanner(adFree: false, consent: true, available: false),
        ),
        WidgetbookUseCase(
          name: 'adFree (숨김)',
          builder: (context) =>
              _adBanner(adFree: true, consent: true, available: true),
        ),
        WidgetbookUseCase(
          name: 'noConsent (숨김)',
          builder: (context) =>
              _adBanner(adFree: false, consent: false, available: true),
        ),
      ],
    ),
  ],
);
