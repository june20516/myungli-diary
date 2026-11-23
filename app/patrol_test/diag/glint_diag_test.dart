// CI 에뮬레이터 진단(2026-11-23~24, A155). 일반 E2E가 아니라 app.yml 수동 실행 입력
// e2e_diag_matrix로만 돕니다. 변형이 없으면(일반 E2E, 로컬 patrol) skip합니다.
//
// 처음에는 `unlock.glint`가 원인이라 보고 그리는 연산만 바꾸는 변형으로 시작했지만, 원인은
// 에뮬레이터 호스트 SwiftShader(deprecated `swiftshader_indirect`)의 SIGSEGV였고 반짝임과
// SeepOnChange는 원인이 아니었습니다. 경과와 판단 계획은
// app/docs/plans/2026-11-24-e2e-emulator-gpu.md에 있습니다. 변형은 다시 진단할 때 쓰려고 둡니다.
//
// 변형:
// * control: 앱의 UnlockGlintScope와 UnlockGlint 그대로(대조군).
// * mask-srcatop: Flutter ShaderMask(ShaderMaskLayer), BlendMode.srcATop,
//   매 프레임 띠 이동.
// * mask-srcin: 위와 같고 BlendMode.srcIn.
// * mask-static: ShaderMask srcATop, 띠를 움직이지 않음(한 번만 그림).
// * foreground: 층 없이 글자 칠(TextStyle.foreground)에 띠 shader, 매 프레임 띠 이동.
// * plain: shader 없이 글자색만 매 프레임 바꿈(애니메이션 자체의 기준).
// * backdrop: control 위 아래쪽에 탭 바와 같은 흐림 바탕(FrameSurface, BackdropFilter)을 겹침.
// * sheet: 흐림 바탕 없는 화면에서 실제 시트(showMyungliSheet)를 열고 그 안에 control.
// * sheet-backdrop: 흐림 바탕이 있는 화면에서 시트를 열고 그 안에 control.
// * sheet-backdrop-noglint: 위와 같고 시트 안은 반짝임 없는 글자.
// * real-noclip, real-noopacity, real-nophysical, real-noshadow:
//   real에서 층 범주 하나를 끔([_setLayerSwitches]).
// * real-mysaju-sheet, part-*: 원인 위젯을 좁히는 변형([_openReal], [_openPart]).
// * real: me_test 앞부분(앱 실행 → 나의 사주 → 사주 표 → 용어 → 열린 풀이 시트)을 그대로 밟음
//   (양성 대조군. CI에서 교착이 재현되던 흐름). real-mysaju, real-chart, real-today는 그 흐름을
//   중간에서 멈추거나 다른 화면에서 같은 시트를 엽니다([_openReal]). 앱의 동작 설정은 기기를 따르므로, CI 기본(기기
//   애니메이션 끔)에서는 반짝임 대신 unlock.mark가 그려집니다. 그래서 real은 띠 확인을 하지
//   않습니다.
//
// 합성 변형은 동작 설정을 직접 줍니다(동작 줄이기 꺼짐). 다만 기기 애니메이션이 꺼져 있으면
// Flutter가 AnimationController 시간을 줄여 띠가 아주 짧게 지나가므로, 띠 확인이 필요한 합성
// 변형은 matrix에서 animations: true로 돌립니다.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart'
    show Finder, expect, find, isTrue;
import 'package:myungli_diary/core/api/gen/model/chart.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/feedback/screen_state_view.dart';
import 'package:myungli_diary/design/components/feedback/seep_on_change.dart';
import 'package:myungli_diary/design/components/frame/app_bar.dart';
import 'package:myungli_diary/design/components/frame/frame_surface.dart';
import 'package:myungli_diary/design/components/frame/section_card.dart';
import 'package:myungli_diary/design/components/frame/section_header.dart';
import 'package:myungli_diary/design/components/frame/sheet.dart';
import 'package:myungli_diary/design/components/input/segmented.dart';
import 'package:myungli_diary/design/components/sentence/term_token.dart';
import 'package:myungli_diary/design/interaction/motion_prefs.dart';
import 'package:myungli_diary/design/interaction/patterns.dart';
import 'package:myungli_diary/design/interaction/unlock_glint.dart';
import 'package:myungli_diary/design/theme/app_theme.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/features/depth/application/depth_sheets.dart';
import 'package:myungli_diary/features/glossary/application/glossary_providers.dart';
import 'package:myungli_diary/features/me/application/chart_providers.dart';
import 'package:myungli_diary/features/me/presentation/chart_text.dart';
import 'package:myungli_diary/features/me/presentation/natal_card.dart';
import 'package:myungli_diary/features/me/presentation/saju_chart_tabs.dart';
import 'package:patrol/patrol.dart';

import '../support/e2e_app.dart';

const _variant = String.fromEnvironment('GLINT_DIAG');

/// 반짝임을 띄워 두는 시간. 대조군 박자(10초마다 2.6초)로 여섯 번 지나갑니다.
const _hold = Duration(seconds: 60);

/// 열린 풀이 시트처럼 문단 여럿을 둡니다.
const _paragraphs = 8;

const _text =
    '오늘은 용신의 기운이 들어오는 날이라 미뤄 둔 일을 시작하기 좋습니다. '
    '다만 서두르면 놓치는 것이 생기니 하나씩 확인하며 나아갑니다.';

const _normalMotion = MotionPrefs(
  reduceMotion: false,
  reduceTransparency: false,
  lowEnd: false,
);

/// 반짝임이 들어간 변형. 띠가 실제로 지나갔는지 봅니다(박자가 멈춰 있으면 진단이 헛돕니다).
const _glintVariants = {'control', 'backdrop', 'sheet', 'sheet-backdrop'};

void main() {
  patrolTest(
    'glint 진단 변형 "$_variant": 반짝임을 ${_hold.inSeconds}초 띄워도 에뮬레이터가 살아 있음',
    skip: _variant.isEmpty,
    ($) async {
      _setLayerSwitches(on: true);
      if (_variant.startsWith('real')) {
        await _openReal($, _variant);
      } else if (_variant.startsWith('part-')) {
        await _openPart($, _variant);
      } else {
        await $.pumpWidget(
          MaterialApp(
            locale: const Locale('ko'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: buildTheme(
              brightness: Brightness.light,
              locale: const Locale('ko'),
            ),
            // 동작 설정은 navigator 위에 두어 시트 route까지 닿게 합니다.
            builder: (context, child) =>
                MotionPrefsScope(prefs: _normalMotion, child: child!),
            home: const Scaffold(
              body: SafeArea(child: _DiagBody(variant: _variant)),
            ),
          ),
        );
        if (_variant.startsWith('sheet')) {
          await $(find.byKey(const ValueKey('diag-open-sheet'))).tap();
        }
      }
      var sawGlint = false;
      final end = DateTime.now().add(_hold);
      while (DateTime.now().isBefore(end)) {
        await Future<void>.delayed(const Duration(seconds: 1));
        await $.pump();
        sawGlint |= $.tester.allRenderObjects
            .whereType<RenderUnlockGlint>()
            .any((render) => render.glinting);
      }
      // Flutter는 테스트 끝에 그리기 debug 스위치가 꺼져 있는지 봅니다.
      _setLayerSwitches(on: false);
      if (_glintVariants.contains(_variant)) expect(sawGlint, isTrue);
    },
  );
}

/// real-no* 변형이면 real 흐름에서 Flutter 그리기 debug 스위치로 층 범주 하나를 끕니다.
/// 끈 뒤 교착이 사라지는 범주가 원인 범주입니다(앱 코드는 그대로).
///
/// * real-noclip: 클립 층(`debugDisableClipLayers`).
/// * real-noopacity: 투명도 층(`debugDisableOpacityLayers`).
/// * real-nophysical: 물리 모양 층(`debugDisablePhysicalShapeLayers`).
/// * real-noshadow: 상자 그림자(`debugDisableShadows`).
void _setLayerSwitches({required bool on}) {
  debugDisableClipLayers = on && _variant == 'real-noclip';
  debugDisableOpacityLayers = on && _variant == 'real-noopacity';
  debugDisablePhysicalShapeLayers = on && _variant == 'real-nophysical';
  debugDisableShadows = on && _variant == 'real-noshadow';
}

/// 실제 앱 흐름 변형. 모두 fake 시나리오 evidence-unlocked로 띄웁니다.
///
/// * real: me_test 앞부분, 나의 사주 → 사주 표(원국) → 표 안 용어 → 열린 풀이 시트.
/// * real-mysaju: 나의 사주 화면까지.
/// * real-chart: 사주 표 화면까지(시트 없음).
/// * real-today: 오늘 화면의 첫 용어 → 열린 풀이 시트(사주 표 없음).
/// * real-mysaju-sheet: 나의 사주 화면(원국표와 오행 막대 카드)의 첫 용어 → 열린 풀이 시트.
Future<void> _openReal(PatrolIntegrationTester $, String name) async {
  final variant = name.startsWith('real-no') ? 'real' : name;
  await launchApp(
    $,
    flow: 'diag',
    scenario: 'evidence-unlocked',
    deviceLocale: const Locale('ko', 'KR'),
  );
  await waitForScreen($, ScreenIds.today);
  if (variant == 'real-today') {
    await $(TermToken).tap();
    await expectScreen($, ScreenIds.explainSheet);
    return;
  }
  await $(find.byKey(const ValueKey('tab-bar.tab.3'))).tap();
  await expectScreen($, ScreenIds.mySaju);
  if (variant == 'real-mysaju') return;
  if (variant == 'real-mysaju-sheet') {
    await _tapFirstTerm($, find.byKey(const ValueKey(ScreenIds.mySaju)));
    return;
  }
  final mySaju = find.byKey(const ValueKey(ScreenIds.mySaju));
  final l10n = AppLocalizations.of($.tester.element(mySaju.first));
  final chartLink = find.descendant(
    of: mySaju,
    matching: find.descendant(
      of: find.byType(SectionHeader),
      matching: find.text(l10n.mySajuChartLink),
    ),
  );
  await $(chartLink).scrollTo();
  await $(chartLink).tap();
  await expectScreen($, ScreenIds.sajuChart);
  final term = $(
    find
        .descendant(
          of: find.byKey(const ValueKey(ScreenIds.sajuChart)),
          matching: find.byType(TermToken),
        )
        .first,
  );
  await term.waitUntilVisible();
  if (variant == 'real-chart') return;
  if (variant != 'real') throw ArgumentError('알 수 없는 GLINT_DIAG 변형: $variant');
  await term.tap();
  await expectScreen($, ScreenIds.explainSheet);
}

/// [scope] 안 첫 용어를 눌러 열린 풀이 시트를 엽니다.
Future<void> _tapFirstTerm(PatrolIntegrationTester $, Finder scope) async {
  final terms = find.descendant(of: scope, matching: find.byType(TermToken));
  // `.first`를 붙인 finder는 대상이 없으면 다시 시도하지 않고 바로 실패하므로, 화면이 그려지고
  // 용어가 생길 때까지 먼저 기다립니다.
  await waitUntil($, () => terms.evaluate().isNotEmpty);
  final term = $(terms.first);
  // 아래에 깔린 화면의 스크롤 영역이 아니라 [scope] 안 스크롤 영역을 굴립니다.
  await term.scrollTo(
    view: find.descendant(of: scope, matching: find.byType(Scrollable)).first,
  );
  await term.tap();
  await expectScreen($, ScreenIds.explainSheet);
}

/// 사주 표 원국 탭 구성 요소를 나눠 둔 진단 화면 변형. 실제 앱을 띄워 나의 사주까지 간 뒤
/// (차트와 provider는 앱 그대로) 그 위에 진단 화면을 push하고, 화면 안 원국표의 첫 용어로
/// 같은 풀이 시트를 엽니다.
///
/// * part-natal: 원국 탭 내용 전체([SajuChartNatalTab]: 섹션 머리, 원국표, 오행 막대, 용신 근거).
/// * part-pillars: 원국표 카드만.
/// * part-pillars-ohaeng: 원국표 카드와 오행 막대 카드.
///
/// 원국 탭 내용만으로는 재현되지 않아(2026-11-23), 사주 표 화면 틀 요소를 하나씩 붙인 변형:
/// * part-list: 원국 탭 내용을 ListView에(사주 표 화면과 같은 스크롤).
/// * part-appbar: 위에 앱 바([MyungliAppBar.inner]).
/// * part-segmented: 탭 고르기([Segmented]).
/// * part-seep: 탭 전환 흐림([SeepOnChange]).
/// * part-statev: 상태 전환 뷰([ScreenStateView]).
Future<void> _openPart(PatrolIntegrationTester $, String variant) async {
  await launchApp(
    $,
    flow: 'diag',
    scenario: 'evidence-unlocked',
    deviceLocale: const Locale('ko', 'KR'),
  );
  await waitForScreen($, ScreenIds.today);
  await $(find.byKey(const ValueKey('tab-bar.tab.3'))).tap();
  await expectScreen($, ScreenIds.mySaju);
  Navigator.of(
    $.tester.element(find.byKey(const ValueKey(ScreenIds.mySaju))),
  ).push(MaterialPageRoute<void>(builder: (_) => _ChartPart(variant: variant)));
  await _tapFirstTerm($, find.byKey(const ValueKey('diag-part')));
}

/// [_openPart]의 진단 화면.
class _ChartPart extends ConsumerWidget {
  const new({required this.variant});

  final String variant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chart = ref.watch(chartControllerProvider).value;
    if (chart == null) return const Scaffold(body: SizedBox.expand());
    final text = ChartText(
      context,
      ref.watch(glossaryProvider).value,
      ref.read(depthSheetsProvider),
    );
    final pillars = SectionCard(
      child: NatalCard.pillars(chart: chart, onTermTap: text.openTerm),
    );
    final natal = SajuChartNatalTab(chart: chart);
    final list = switch (variant) {
      'part-list' => [natal],
      'part-appbar' => [natal],
      'part-segmented' => [
        Segmented<int>(
          items: const [SegmentedItem(0, '원국'), SegmentedItem(1, '만세력과 대운')],
          selected: 0,
          onChanged: (_) {},
          label: '사주 표',
        ),
        const SizedBox(height: 16),
        natal,
      ],
      'part-seep' => [SeepOnChange(changeKey: 'natal', child: natal)],
      'part-statev' => [
        ScreenStateView<Chart>(
          value: ref.watch(chartControllerProvider),
          onRetry: () {},
          skeleton: const SizedBox(height: 400),
          data: (value) => SajuChartNatalTab(chart: value),
        ),
      ],
      _ => null,
    };
    if (list != null) {
      return Scaffold(
        key: const ValueKey('diag-part'),
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (variant == 'part-appbar')
                const MyungliAppBar.inner(title: '사주 표'),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: list,
                ),
              ),
            ],
          ),
        ),
      );
    }
    final content = switch (variant) {
      'part-natal' => natal,
      'part-pillars' => pillars,
      'part-pillars-ohaeng' => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          pillars,
          const SizedBox(height: 16),
          SectionCard(child: NatalCard.ohaeng(chart: chart)),
        ],
      ),
      _ => throw ArgumentError('알 수 없는 GLINT_DIAG 변형: $variant'),
    };
    return Scaffold(
      key: const ValueKey('diag-part'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: content,
        ),
      ),
    );
  }
}

/// [variant]대로 대상 [_paragraphs]개와 칩 바탕 하나를 그립니다.
class _DiagBody extends StatefulWidget {
  const new({required this.variant});

  final String variant;

  @override
  State<_DiagBody> createState() => _DiagBodyState();
}

class _DiagBodyState extends State<_DiagBody>
    with SingleTickerProviderStateMixin {
  /// control 밖 변형의 띠 진행. 대조군과 같은 2.6초로 계속 돕니다.
  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: InteractionPattern.unlockGlint.duration,
  );

  @override
  void initState() {
    super.initState();
    if (const {
      'mask-srcatop',
      'mask-srcin',
      'foreground',
      'plain',
    }.contains(widget.variant)) {
      _sweep.repeat();
    }
  }

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final targets = [
      for (var i = 0; i < _paragraphs; i++)
        Padding(
          padding: const EdgeInsets.all(8),
          child: _target(context, const Text(_text)),
        ),
      Padding(
        padding: const EdgeInsets.all(8),
        child: _target(
          context,
          UnlockGlintBackdrop(
            decoration: BoxDecoration(
              color: const Color(0xFFEDE7F6),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text('용신'),
            ),
          ),
        ),
      ),
    ];
    final list = SingleChildScrollView(child: Column(children: targets));
    switch (widget.variant) {
      case 'control':
        return UnlockGlintScope(child: list);
      case 'backdrop':
        return _withBackdrop(UnlockGlintScope(child: list));
      case 'sheet' || 'sheet-backdrop' || 'sheet-backdrop-noglint':
        final page = Center(
          child: Builder(
            builder: (context) => TextButton(
              key: const ValueKey('diag-open-sheet'),
              onPressed: () => showMyungliSheet<void>(
                context,
                size: SheetSize.half,
                builder: (_) => widget.variant == 'sheet-backdrop-noglint'
                    ? SingleChildScrollView(
                        child: Column(
                          children: [
                            for (var i = 0; i < _paragraphs; i++)
                              const Padding(
                                padding: EdgeInsets.all(8),
                                child: Text(_text),
                              ),
                          ],
                        ),
                      )
                    : UnlockGlintScope(child: list),
              ),
              child: const Text('시트 열기'),
            ),
          ),
        );
        return widget.variant == 'sheet' ? page : _withBackdrop(page);
    }
    return list;
  }

  /// [child] 아래쪽에 탭 바처럼 흐림 바탕을 겹칩니다(뒤 내용이 바뀌면 흐림도 다시 그림).
  Widget _withBackdrop(Widget child) => Stack(
    children: [
      Positioned.fill(child: child),
      const Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        height: 160,
        child: FrameSurface(
          surfaceKey: ValueKey('diag-frame-surface'),
          child: SizedBox.expand(),
        ),
      ),
    ],
  );

  /// 대상 하나를 변형의 연산으로 감쌉니다.
  Widget _target(BuildContext context, Widget child) {
    final gradient = context.tokens.gradients.unlocked;
    Shader shader(Rect bounds, double progress) => unlockGlintShader(
      bounds.size,
      progress,
      gradient.colors,
      gradient.stops,
    );
    switch (widget.variant) {
      case 'control' || 'backdrop' || 'sheet' || 'sheet-backdrop':
        return UnlockGlint(child: child);
      case 'sheet-backdrop-noglint':
        return child;
      case 'mask-srcatop':
      case 'mask-srcin':
      case 'mask-static':
        final mode = widget.variant == 'mask-srcin'
            ? BlendMode.srcIn
            : BlendMode.srcATop;
        return AnimatedBuilder(
          animation: _sweep,
          builder: (context, _) => ShaderMask(
            blendMode: mode,
            shaderCallback: (bounds) => shader(
              bounds,
              widget.variant == 'mask-static' ? 0.5 : _sweep.value,
            ),
            child: child,
          ),
        );
      case 'foreground':
        return LayoutBuilder(
          builder: (context, constraints) => AnimatedBuilder(
            animation: _sweep,
            builder: (context, _) => DefaultTextStyle.merge(
              style: TextStyle(
                foreground: Paint()
                  ..shader = shader(
                    Offset.zero & Size(constraints.maxWidth, 48),
                    _sweep.value,
                  ),
              ),
              child: child,
            ),
          ),
        );
      case 'plain':
        return AnimatedBuilder(
          animation: _sweep,
          builder: (context, _) => DefaultTextStyle.merge(
            style: TextStyle(
              color: Color.lerp(
                gradient.colors.first,
                gradient.colors.last,
                _sweep.value,
              ),
            ),
            child: child,
          ),
        );
    }
    throw ArgumentError('알 수 없는 GLINT_DIAG 변형: ${widget.variant}');
  }
}
