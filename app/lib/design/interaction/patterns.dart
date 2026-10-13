import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:myungli_diary/design/interaction/motion_prefs.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

/// 동작 줄이기일 때 패턴이 따르는 대체 규칙(`interaction.json` `reduceMotion`).
enum ReduceMotionRule {
  /// 이동·크기·흐림을 빼고 투명도만 바꿉니다.
  opacityOnly('opacity-only'),

  /// 시간 0으로 바로 바뀝니다.
  instant('instant');

  new(this.json);

  /// 명세 JSON의 값.
  final String json;
}

/// 저사양 기기에서 패턴이 따르는 규칙(`interaction.json` `lowEnd`).
enum LowEndRule {
  /// 그대로 둡니다.
  same('same'),

  /// 투명도만 바꿉니다.
  opacityOnly('opacity-only'),

  /// 흐림만 빼고 크기 변화는 유지합니다.
  noBlur('no-blur');

  new(this.json);

  /// 명세 JSON의 값.
  final String json;
}

/// 공통 상호작용 패턴 12개. 이름은 `interaction.json` id의 lowerCamelCase입니다.
enum InteractionPattern {
  /// 먹 번짐: 모든 눌림.
  pressInk(
    'press.ink',
    Motion.stamp,
    Motion.seep,
    ReduceMotionRule.opacityOnly,
    LowEndRule.same,
  ),

  /// 스밈 나타남.
  appearSeep(
    'appear.seep',
    Motion.medium,
    Motion.seep,
    ReduceMotionRule.opacityOnly,
    LowEndRule.opacityOnly,
  ),

  /// 스밈 사라짐.
  disappearSeep(
    'disappear.seep',
    Motion.short,
    Motion.standard,
    ReduceMotionRule.opacityOnly,
    LowEndRule.opacityOnly,
  ),

  /// 스밈 이동: segmented·탭 선택 표시.
  selectSeepSlide(
    'select.seep-slide',
    Motion.select,
    Motion.seep,
    ReduceMotionRule.opacityOnly,
    LowEndRule.opacityOnly,
  ),

  /// 먹 숨쉬기: skeleton, 버튼 처리 중 점.
  loadingBreathe(
    'loading.breathe',
    Motion.breathe,
    Motion.standard,
    ReduceMotionRule.opacityOnly,
    LowEndRule.same,
  ),

  /// 낙관 도장이 찍히고 배어듦.
  sealStamp(
    'seal.stamp',
    Motion.stamp,
    Motion.seep,
    ReduceMotionRule.opacityOnly,
    LowEndRule.noBlur,
  ),

  /// 낙관 도장이 번지며 지워짐.
  sealErase(
    'seal.erase',
    Motion.short,
    Motion.standard,
    ReduceMotionRule.opacityOnly,
    LowEndRule.opacityOnly,
  ),

  /// 펼침 밑줄: 가운데에서 좌우로 자람.
  markUnderlineGrow(
    'mark.underline-grow',
    Motion.long,
    Motion.seep,
    ReduceMotionRule.opacityOnly,
    LowEndRule.same,
  ),

  /// 시트가 아래에서 올라옴.
  sheetEnter(
    'sheet.enter',
    Motion.long,
    Motion.enter,
    ReduceMotionRule.opacityOnly,
    LowEndRule.same,
  ),

  /// 시트가 아래로 내려감.
  sheetExit(
    'sheet.exit',
    Motion.medium,
    Motion.exit,
    ReduceMotionRule.opacityOnly,
    LowEndRule.same,
  ),

  /// 시트가 깊어질 때 아래 층이 물러남.
  sheetStack(
    'sheet.stack',
    Motion.long,
    Motion.enter,
    ReduceMotionRule.opacityOnly,
    LowEndRule.same,
  ),

  /// 입력 포커스 테두리.
  focusRing(
    'focus.ring',
    Motion.short,
    Motion.standard,
    ReduceMotionRule.instant,
    LowEndRule.same,
  );

  new(this.id, this.duration, this.curve, this.reduceMotion, this.lowEnd);

  /// 명세 id(예: `press.ink`).
  final String id;

  /// 기본 시간. 실제 시간은 [patternDuration]이 대체 규칙을 적용해 줍니다.
  final Duration duration;

  /// 기본 곡선.
  final Cubic curve;

  /// 동작 줄이기 규칙.
  final ReduceMotionRule reduceMotion;

  /// 저사양 규칙.
  final LowEndRule lowEnd;
}

/// `press.ink`를 뗄 때 얼룩이 번지며 사라지는 시간.
const Duration pressInkReleaseDuration = Motion.long;

/// `loading.breathe`에서 줄마다 어긋나는 간격(명세가 직접 적은 값).
const Duration breatheStagger = Duration(milliseconds: 150);

/// `sheet.stack`에서 물러나는 층의 종류.
enum StackLayer {
  /// 아래 화면: 크기 0.92, 밝기 0.9.
  screen,

  /// 아래 시트: 위로 30px, 크기 0.94, 밝기 0.95.
  sheet,
}

/// 패턴 몇 가지만 쓰는 추가 입력.
@immutable
final class PatternOptions {
  /// 추가 입력을 만듭니다. 값이 없으면 각 패턴의 기본 동작입니다.
  const new({
    this.origin = Alignment.center,
    this.release,
    this.inkColor,
    this.borderRadius = BorderRadius.zero,
    this.outgoing = false,
    this.previousSide = const Offset(-1, 0),
    this.index = 0,
    this.stackLayer = StackLayer.screen,
  });

  /// `press.ink`: 누른 자리.
  final Alignment origin;

  /// `press.ink`: 뗄 때의 진행(0→1). null이면 아직 떼지 않았습니다.
  final Animation<double>? release;

  /// `press.ink`: 얼룩 색(그 컴포넌트의 글자색). 없으면 `text.primary`.
  final Color? inkColor;

  /// `press.ink` 얼룩을 자를 모서리, `focus.ring` 테두리 모서리.
  final BorderRadius borderRadius;

  /// `select.seep-slide`: true면 사라지는 이전 표시를 그립니다.
  final bool outgoing;

  /// `select.seep-slide`: 이전 표시가 있던 쪽(-1 왼쪽, 1 오른쪽).
  final Offset previousSide;

  /// `loading.breathe`: 줄 순서. 줄마다 150ms씩 어긋납니다.
  final int index;

  /// `sheet.stack`: 물러나는 층.
  final StackLayer stackLayer;
}

/// 컨트롤러에 줄 시간. 동작 줄이기에서 `instant` 패턴이면 0입니다.
Duration patternDuration(InteractionPattern pattern, MotionPrefs prefs) =>
    prefs.reduceMotion && pattern.reduceMotion == ReduceMotionRule.instant
    ? Duration.zero
    : pattern.duration;

/// [pattern]을 [child]에 입힙니다. [t]는 0→1로 가는 선형 진행이고 곡선은 여기서 입힙니다.
///
/// 흐림은 대상 자신에게만 겁니다(배경 흐림 아님). 동작 줄이기와 저사양 규칙은
/// [prefs]대로 적용합니다.
Widget animate(
  InteractionPattern pattern, {
  required Animation<double> t,
  required Widget child,
  required MotionPrefs prefs,
  PatternOptions options = const PatternOptions(),
}) {
  final listenable =
      pattern == InteractionPattern.pressInk && options.release != null
      ? Listenable.merge([t, options.release])
      : t;
  return AnimatedBuilder(
    animation: listenable,
    child: child,
    builder: (context, child) {
      final effect = _Effect(pattern, prefs, t);
      return switch (pattern) {
        InteractionPattern.pressInk => _pressInk(
          context,
          effect,
          options,
          child!,
        ),
        InteractionPattern.appearSeep => _appearSeep(effect, child!),
        InteractionPattern.disappearSeep => _disappearSeep(effect, child!),
        InteractionPattern.selectSeepSlide => _selectSlide(
          effect,
          options,
          child!,
        ),
        InteractionPattern.loadingBreathe => _breathe(
          effect,
          t,
          options,
          child!,
        ),
        InteractionPattern.sealStamp => _sealStamp(effect, child!),
        InteractionPattern.sealErase => _sealErase(effect, child!),
        InteractionPattern.markUnderlineGrow => _underlineGrow(effect, child!),
        InteractionPattern.sheetEnter => _sheetEnter(effect, child!),
        InteractionPattern.sheetExit => _sheetExit(effect, child!),
        InteractionPattern.sheetStack => _sheetStack(effect, options, child!),
        InteractionPattern.focusRing => _focusRing(
          context,
          effect,
          options,
          child!,
        ),
      };
    },
  );
}

/// 시트 바깥 덮개의 투명도. `sheet.enter`·`sheet.exit`의 [t]를 그대로 받습니다.
///
/// 덮개는 시트보다 짧은 `fade`(280ms) 동안 `standard` 곡선으로 바뀝니다.
Widget animateScrim(
  InteractionPattern pattern, {
  required Animation<double> t,
  required MotionPrefs prefs,
}) {
  assert(
    pattern == InteractionPattern.sheetEnter ||
        pattern == InteractionPattern.sheetExit,
    '덮개는 sheet.enter·sheet.exit만 가집니다.',
  );
  return AnimatedBuilder(
    animation: t,
    builder: (context, _) {
      final effect = _Effect(pattern, prefs, t);
      final local = math.min(
        1,
        effect.progress *
            pattern.duration.inMicroseconds /
            Motion.fade.inMicroseconds,
      );
      final eased = Motion.standard.transform(local.toDouble());
      final opacity = pattern == InteractionPattern.sheetEnter
          ? eased
          : 1 - eased;
      return Opacity(
        opacity: opacity,
        child: ColoredBox(color: context.tokens.colors.scrim),
      );
    },
  );
}

/// 한 번의 프레임에서 패턴이 쓸 값과 대체 규칙 판정.
final class _Effect {
  new(this.pattern, this.prefs, Animation<double> t)
    : progress = _progressOf(pattern, prefs, t.value);

  final InteractionPattern pattern;
  final MotionPrefs prefs;

  /// 대체 규칙을 적용한 0~1 진행.
  final double progress;

  static double _progressOf(
    InteractionPattern pattern,
    MotionPrefs prefs,
    double value,
  ) {
    if (prefs.reduceMotion &&
        pattern.reduceMotion == ReduceMotionRule.instant) {
      return value > 0 ? 1 : 0;
    }
    return value;
  }

  /// 이동·크기·흐림을 모두 빼고 투명도만 쓸지.
  bool get opacityOnly =>
      prefs.reduceMotion ||
      (prefs.lowEnd && pattern.lowEnd == LowEndRule.opacityOnly);

  /// 흐림을 뺄지.
  bool get noBlur =>
      opacityOnly || (prefs.lowEnd && pattern.lowEnd == LowEndRule.noBlur);

  /// 곡선을 입힌 진행.
  double get eased => pattern.curve.transform(progress.clamp(0, 1));
}

/// 대상 자신에게 흐림을 겁니다. CSS `blur(r)`의 r은 표준편차라 sigma로 그대로 씁니다.
Widget _blurSelf(double sigma, Widget child) => ImageFiltered(
  enabled: sigma > 0,
  imageFilter: ui.ImageFilter.blur(
    sigmaX: sigma,
    sigmaY: sigma,
    tileMode: TileMode.decal,
  ),
  child: child,
);

Widget _fade(double opacity, Widget child) =>
    Opacity(opacity: opacity.clamp(0, 1), child: child);

Widget _appearSeep(_Effect e, Widget child) {
  final v = e.eased;
  final body = e.noBlur ? child : _blurSelf(8 * (1 - v), child);
  return _fade(v, body);
}

Widget _disappearSeep(_Effect e, Widget child) {
  final v = e.eased;
  final body = e.noBlur ? child : _blurSelf(8 * v, child);
  return _fade(1 - v, body);
}

Widget _selectSlide(_Effect e, PatternOptions o, Widget child) {
  if (o.outgoing) {
    // 이전 표시는 fade(280ms) 동안 standard 곡선으로 먼저 사라집니다.
    final local = math.min(
      1,
      e.progress *
          InteractionPattern.selectSeepSlide.duration.inMicroseconds /
          Motion.fade.inMicroseconds,
    );
    final v = Motion.standard.transform(local.toDouble());
    if (e.opacityOnly) return _fade(1 - v, child);
    return _fade(
      1 - v,
      Transform.scale(scale: 1 + 0.06 * v, child: _blurSelf(6 * v, child)),
    );
  }
  final v = e.eased;
  if (e.opacityOnly) return _fade(v, child);
  return _fade(
    v,
    FractionalTranslation(
      translation: o.previousSide * (0.15 * (1 - v)),
      child: Transform.scale(
        scale: 0.92 + 0.08 * v,
        child: _blurSelf(6 * (1 - v), child),
      ),
    ),
  );
}

Widget _breathe(
  _Effect e,
  Animation<double> t,
  PatternOptions o,
  Widget child,
) {
  // 컨트롤러가 repeat(reverse: true)로 0→1→0을 오가므로 한 주기(0~1)로 펴서 어긋남을 줍니다.
  final phase = t.status == AnimationStatus.reverse
      ? 1 - t.value / 2
      : t.value / 2;
  final shift =
      o.index *
      breatheStagger.inMicroseconds /
      (InteractionPattern.loadingBreathe.duration.inMicroseconds * 2);
  final shifted = (phase - shift) % 1;
  final folded = shifted < 0.5 ? shifted * 2 : 2 - shifted * 2;
  final v = e.pattern.curve.transform(folded);
  return _fade(0.55 + 0.45 * v, child);
}

Widget _sealStamp(_Effect e, Widget child) {
  final p = e.progress.clamp(0, 1).toDouble();
  final double scale;
  final double opacity;
  final double blur;
  if (p < 0.35) {
    final l = Motion.stampPress.transform(p / 0.35);
    scale = 1.2 - 0.2 * l;
    opacity = 0.55 * l;
    blur = 3 - 1.5 * l;
  } else {
    final l = Motion.seep.transform((p - 0.35) / 0.65);
    scale = 1;
    opacity = 0.55 + 0.45 * l;
    blur = 1.5 * (1 - l);
  }
  if (e.opacityOnly) return _fade(opacity, child);
  final scaled = Transform.scale(scale: scale, child: child);
  return _fade(opacity, e.noBlur ? scaled : _blurSelf(blur, scaled));
}

Widget _sealErase(_Effect e, Widget child) {
  final v = e.eased;
  final body = e.noBlur ? child : _blurSelf(5 * v, child);
  return _fade(1 - v, body);
}

Widget _underlineGrow(_Effect e, Widget child) {
  final v = e.eased;
  if (e.opacityOnly) return _fade(v, child);
  return Transform.scale(scaleX: v, scaleY: 1, child: child);
}

Widget _sheetEnter(_Effect e, Widget child) {
  final v = e.eased;
  if (e.opacityOnly) return _fade(v, child);
  return FractionalTranslation(translation: Offset(0, 1 - v), child: child);
}

Widget _sheetExit(_Effect e, Widget child) {
  final v = e.eased;
  if (e.opacityOnly) return _fade(1 - v, child);
  return FractionalTranslation(translation: Offset(0, v), child: child);
}

Widget _sheetStack(_Effect e, PatternOptions o, Widget child) {
  final v = e.eased;
  final isSheet = o.stackLayer == StackLayer.sheet;
  // 밝기는 필터가 아니라 검은 덮개의 투명도로 냅니다(밝기 0.9 → 덮개 0.1).
  final veil = (isSheet ? 0.05 : 0.1) * v;
  final dimmed = Stack(
    children: [
      child,
      Positioned.fill(
        child: IgnorePointer(
          child: ColoredBox(
            color: const Color(0xFF000000).withValues(alpha: veil),
          ),
        ),
      ),
    ],
  );
  if (e.opacityOnly) return dimmed;
  final scale = isSheet ? 1 - 0.06 * v : 1 - 0.08 * v;
  return Transform(
    alignment: Alignment.center,
    transform: Matrix4.translationValues(0, isSheet ? -30 * v : 0, 0)
      ..scaleByDouble(scale, scale, 1, 1),
    child: dimmed,
  );
}

Widget _focusRing(
  BuildContext context,
  _Effect e,
  PatternOptions o,
  Widget child,
) {
  final colors = context.tokens.colors;
  final v = e.eased;
  return DecoratedBox(
    position: DecorationPosition.foreground,
    decoration: BoxDecoration(
      borderRadius: o.borderRadius,
      border: Border.all(
        width: 1 + v,
        color: Color.lerp(colors.line, colors.actionPrimary, v)!,
      ),
    ),
    child: child,
  );
}

Widget _pressInk(
  BuildContext context,
  _Effect e,
  PatternOptions o,
  Widget child,
) {
  final release = o.release?.value ?? 0;
  final releaseEased = Motion.seep.transform(release.clamp(0, 1));
  return Stack(
    children: [
      child,
      Positioned.fill(
        child: IgnorePointer(
          child: CustomPaint(
            painter: _InkPainter(
              color: o.inkColor ?? context.tokens.colors.textPrimary,
              origin: o.origin,
              grow: e.eased,
              release: releaseEased,
              fadeOnly: e.opacityOnly,
              borderRadius: o.borderRadius,
            ),
          ),
        ),
      ),
    ],
  );
}

/// 누른 자리에서 번지는 원형 얼룩. 이 층 안에서만 자릅니다.
class _InkPainter extends CustomPainter {
  new({
    required this.color,
    required this.origin,
    required this.grow,
    required this.release,
    required this.fadeOnly,
    required this.borderRadius,
  });

  static const double _alpha = 0.12;

  final Color color;
  final Alignment origin;
  final double grow;
  final double release;
  final bool fadeOnly;
  final BorderRadius borderRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.clipRRect(borderRadius.toRRect(bounds));
    final center = origin.alongSize(size);
    final farthest = [
      bounds.topLeft,
      bounds.topRight,
      bounds.bottomLeft,
      bounds.bottomRight,
    ].map((corner) => (corner - center).distance).reduce(math.max);
    final alpha = _alpha * (1 - release);
    if (fadeOnly) {
      // 동작 줄이기: 번짐 없이 전체가 투명도만 바뀝니다.
      canvas.drawRect(
        bounds,
        Paint()..color = color.withValues(alpha: alpha * grow),
      );
      return;
    }
    final radius = farthest * grow * (1 + 0.15 * release);
    if (radius <= 0) return;
    final tint = color.withValues(alpha: alpha);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = ui.Gradient.radial(
          center,
          radius,
          [tint, tint, tint.withValues(alpha: 0)],
          [0, 0.7, 1],
        ),
    );
  }

  @override
  bool shouldRepaint(_InkPainter old) =>
      old.color != color ||
      old.origin != origin ||
      old.grow != grow ||
      old.release != release ||
      old.fadeOnly != fadeOnly ||
      old.borderRadius != borderRadius;
}
