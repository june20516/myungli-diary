// CI 에뮬레이터 교착 진단(2026-11-23). 일반 E2E가 아니라 app.yml의 e2e-diag job만 돌립니다.
//
// CI(Linux x86 에뮬레이터, gfxstream)에서 열린 화면의 `unlock.glint`가 처음 그려질 때 에뮬레이터
// 호스트가 교착되어 끝났습니다. 이 테스트는 반짝임 하나만 띄우고, `--dart-define=GLINT_DIAG=<변형>`
// 으로 그리는 연산만 바꿔 어느 연산에서 교착이 나는지 가립니다. 대상 수, 띠 색, 띠 shader는
// 모든 변형이 같습니다. 변형이 없으면(일반 E2E, 로컬 patrol) skip합니다.
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
// * real: me_test 앞부분(앱 실행 → 나의 사주 → 사주 표 → 용어 → 열린 풀이 시트)을 그대로 밟음
//   (양성 대조군. CI에서 교착이 재현되던 흐름).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart' show expect, find, isTrue;
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/frame/frame_surface.dart';
import 'package:myungli_diary/design/components/frame/section_header.dart';
import 'package:myungli_diary/design/components/frame/sheet.dart';
import 'package:myungli_diary/design/components/sentence/term_token.dart';
import 'package:myungli_diary/design/interaction/motion_prefs.dart';
import 'package:myungli_diary/design/interaction/patterns.dart';
import 'package:myungli_diary/design/interaction/unlock_glint.dart';
import 'package:myungli_diary/design/theme/app_theme.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
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
const _glintVariants = {
  'control',
  'backdrop',
  'sheet',
  'sheet-backdrop',
  'real',
};

void main() {
  patrolTest(
    'glint 진단 변형 "$_variant": 반짝임을 ${_hold.inSeconds}초 띄워도 에뮬레이터가 살아 있음',
    skip: _variant.isEmpty,
    ($) async {
      if (_variant == 'real') {
        await _openRealExplainSheet($);
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
            home: const Scaffold(
              body: MotionPrefsScope(
                prefs: _normalMotion,
                child: SafeArea(child: _DiagBody(variant: _variant)),
              ),
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
      if (_glintVariants.contains(_variant)) expect(sawGlint, isTrue);
    },
  );
}

/// me_test 앞부분: 나의 사주 → 사주 표(원국) → 표 안 용어 → 열린 풀이 시트.
Future<void> _openRealExplainSheet(PatrolIntegrationTester $) async {
  await launchApp(
    $,
    flow: 'me',
    scenario: 'evidence-unlocked',
    deviceLocale: const Locale('ko', 'KR'),
  );
  await waitForScreen($, ScreenIds.today);
  await $(find.byKey(const ValueKey('tab-bar.tab.3'))).tap();
  await expectScreen($, ScreenIds.mySaju);
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
  await term.tap();
  await expectScreen($, ScreenIds.explainSheet);
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
