import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/design/components/frame/ad_banner.dart';
import 'package:myungli_diary/design/components/frame/app_bar.dart';
import 'package:myungli_diary/design/components/frame/sheet.dart';
import 'package:myungli_diary/design/components/frame/tab_bar.dart';
import 'package:myungli_diary/design/elements/app_icon.dart';
import 'package:myungli_diary/design/interaction/motion_prefs.dart';
import 'package:myungli_diary/design/interaction/patterns.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:phosphor_glyphs/phosphor_glyphs.dart';

import '../support/fonts.dart';
import '../support/golden.dart';

const MotionPrefs _transparent = MotionPrefs(
  reduceMotion: false,
  reduceTransparency: true,
  lowEnd: false,
);

const AppGlyph _share = AppGlyph(
  light: PhosphorIconsLight.shareNetwork,
  regular: PhosphorIconsRegular.shareNetwork,
);
const AppGlyph _more = AppGlyph(
  light: PhosphorIconsLight.dotsThree,
  regular: PhosphorIconsRegular.dotsThree,
);

/// 틀 뒤로 내용이 비쳐 지나가는 모습을 보이려고 깔아 두는 줄무늬.
class _Behind extends StatelessWidget {
  const new({required this.child, this.height = 140});

  final Widget child;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = context.tokens.colors;
    return SizedBox(
      height: height,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Positioned.fill(
            child: Row(
              children: [
                for (var i = 0; i < 12; i++)
                  Expanded(
                    child: ColoredBox(
                      color: i.isEven
                          ? colors.actionPrimary
                          : colors.textSecondary,
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

Widget _tabBars() => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  spacing: 12,
  children: [
    _Behind(child: MyungliTabBar(index: 0, onSelect: (_) {})),
    _Behind(child: MyungliTabBar(index: 3, onSelect: (_) {})),
    MotionPrefsScope(
      prefs: _transparent,
      child: _Behind(child: MyungliTabBar(index: 2, onSelect: (_) {})),
    ),
  ],
);

Widget _appBars() => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  spacing: 8,
  children: [
    MyungliAppBar.tabRoot(
      title: '오늘',
      actions: [
        AppBarAction(icon: _share, semanticLabel: '공유', onPressed: () {}),
        AppBarAction(icon: _more, semanticLabel: '더보기', onPressed: () {}),
      ],
    ),
    MyungliAppBar.inner(
      title: '일기',
      onBack: () {},
      status: const Text('저장됨'),
      actions: [
        AppBarAction(icon: _more, semanticLabel: '더보기', onPressed: () {}),
      ],
    ),
    MyungliAppBar.inner(
      title: '아주 아주 긴 제목이 한 줄에 다 들어가지 않을 때는 줄임표로 자릅니다',
      onBack: () {},
    ),
  ],
);

Widget _sheetScene({
  required double maxHeight,
  required double sceneHeight,
  bool stacked = false,
}) {
  return Builder(
    builder: (context) {
      final colors = context.tokens.colors;
      Widget frame() => MyungliSheetFrame(
        maxHeight: maxHeight,
        semanticLabel: '풀이',
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text('오늘은 힘을 얻는 날입니다. 서두르지 말고 한 가지에 집중해 보세요.'),
        ),
      );
      return SizedBox(
        height: sceneHeight,
        child: Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: colors.bgBase)),
            Positioned.fill(child: ColoredBox(color: colors.scrim)),
            Align(
              alignment: Alignment.bottomCenter,
              child: stacked
                  ? animate(
                      InteractionPattern.sheetStack,
                      t: const AlwaysStoppedAnimation(1),
                      prefs: MotionPrefs.of(context),
                      options: const PatternOptions(
                        stackLayer: StackLayer.sheet,
                      ),
                      child: frame(),
                    )
                  : frame(),
            ),
          ],
        ),
      );
    },
  );
}

Widget _sheets() => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  spacing: 12,
  children: [
    _sheetScene(maxHeight: 200, sceneHeight: 260),
    _sheetScene(maxHeight: 240, sceneHeight: 260, stacked: true),
  ],
);

Widget _adBanners() {
  Widget banner() => AdBannerFrame(
    child: Builder(
      builder: (context) => SizedBox(
        width: 320,
        height: 50,
        child: ColoredBox(color: context.tokens.colors.line),
      ),
    ),
  );
  Widget stack() => _Behind(
    height: 220,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        banner(),
        MyungliTabBar(index: 0, onSelect: (_) {}, topBorder: false),
      ],
    ),
  );
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 12,
    children: [
      stack(),
      MotionPrefsScope(prefs: _transparent, child: stack()),
    ],
  );
}

void main() {
  setUpAll(() async {
    await loadBundledFonts();
    await loadPhosphorFonts();
  });

  goldenTest('tab-bar: 선택·투명도 줄이기', (tester) async {
    await goldenMatrix(tester, 'frame_tab_bar', _tabBars);
  });

  goldenTest('app-bar: tab-root·inner·긴 제목', (tester) async {
    await goldenMatrix(tester, 'frame_app_bar', _appBars);
  });

  goldenTest('sheet: 덮개 위 시트, 아래 층이 물러난 모습', (tester) async {
    await goldenMatrix(tester, 'frame_sheet', _sheets);
  });

  goldenTest('ad-banner: 탭 바 위에 한 덩어리, 투명도 줄이기', (tester) async {
    await goldenMatrix(tester, 'frame_ad_banner', _adBanners);
  });
}
