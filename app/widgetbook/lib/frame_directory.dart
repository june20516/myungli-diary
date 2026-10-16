import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myungli_diary/core/api/gen/model/rendered_text.dart';
import 'package:myungli_diary/core/api/gen/model/segment.dart';
import 'package:myungli_diary/core/platform/fakes.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';
import 'package:myungli_diary/design/components/feedback/skeleton.dart';
import 'package:myungli_diary/design/components/frame/app_bar.dart';
import 'package:myungli_diary/design/components/frame/bottom_bar.dart';
import 'package:myungli_diary/design/components/frame/prose_page_body.dart';
import 'package:myungli_diary/design/components/frame/sheet.dart';
import 'package:myungli_diary/design/components/frame/tab_bar.dart';
import 'package:myungli_diary/design/components/sentence/sentence_block.dart';
import 'package:myungli_diary/design/elements/app_icon.dart';
import 'package:myungli_diary/design/interaction/motion_prefs.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
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

/// 안내 글 문단 하나(`sentence-block` `body`).
Widget _proseParagraph(String text) => SentenceBlock(
  variant: SentenceBlockVariant.body,
  text: RenderedText(segments: [Segment(text: text)]),
);

/// 안내 글 화면 한 장. [loading]이면 셋째 문단 자리에 skeleton을 둡니다.
Widget _prosePage({required bool loading}) => Stage(
  child: SizedBox(
    height: 520,
    child: Builder(
      builder: (context) => Column(
        children: [
          MyungliAppBar.inner(title: '계산 기준', onBack: () {}),
          Expanded(
            child: ProsePageBody(
              paragraphs: [
                _proseParagraph(
                  '명리 해석은 한국에서 널리 쓰는 기준을 따라요. 여러 유파 가운데 하나로, 근거가 있는 기준이에요.',
                ),
                _proseParagraph(
                  '지장간은 하나만 고르지 않고 모두 보여 드려요. 유파마다 처리가 달라서 다른 앱과 결과가 다를 수 있어요.',
                ),
                if (loading)
                  SkeletonBlock(
                    lineStyle: context.tokens.typography.sentenceBody,
                  )
                else
                  _proseParagraph(
                    '출생 시각은 동경 127.5° 기준으로 30분을 빼서 계산해요. 진태양시는 쓰지 않아요.',
                  ),
                _proseParagraph('음력은 한국천문연구원 기준의 한국 음력을 따라요.'),
              ],
            ),
          ),
        ],
      ),
    ),
  ),
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
      name: 'prose-page-body (안내 글 본문)',
      useCases: [
        WidgetbookUseCase(
          name: '문단',
          builder: (context) => _prosePage(loading: false),
        ),
        WidgetbookUseCase(
          name: '문단 자리 불러오는 중',
          builder: (context) => _prosePage(loading: true),
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
