import 'package:flutter/material.dart';
import 'package:myungli_diary/design/components/component_spec.dart';
import 'package:myungli_diary/design/components/sentence/press_ink_target.dart';
import 'package:myungli_diary/design/elements/app_icon.dart';
import 'package:myungli_diary/design/interaction/motion_prefs.dart';
import 'package:myungli_diary/design/interaction/patterns.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';
import 'package:phosphor_glyphs/phosphor_glyphs.dart';

const AppGlyph _doubleLeft = AppGlyph(
  light: PhosphorIconsLight.caretDoubleLeft,
  regular: PhosphorIconsRegular.caretDoubleLeft,
);

const AppGlyph _doubleRight = AppGlyph(
  light: PhosphorIconsLight.caretDoubleRight,
  regular: PhosphorIconsRegular.caretDoubleRight,
);

/// 가로 스크롤 알림(`scroll-hint`, V90): 데이터가 더 있는 쪽 끝만 흐리고 줄 아래에 좌우
/// 겹 화살표를 둡니다. 글자 안내는 없습니다.
///
/// [child]는 [controller]를 쓰는 가로 스크롤 줄입니다. 화살표를 누르면 보이는 폭만큼 그쪽으로
/// 넘기고(줄 안에서만), 더 없는 쪽의 흐림과 화살표는 없습니다. 화살표는 스크린리더에서 숨기고
/// 줄 자체가 목록으로 읽힙니다.
///
/// [showArrows]가 false면 흐림만 두고 화살표 줄은 그리지 않습니다(카드 안 한 줄, 일기 줄 태그
/// `diary-row.parts.tag.row.hint.parts.arrows.visible: false`, V103).
class ScrollHint extends StatefulWidget {
  /// [child] 가로 스크롤 줄에 알림을 더합니다.
  const new({
    required this.controller,
    required this.child,
    this.showArrows = true,
    super.key,
  });

  /// 명세 대조용 요약.
  static const ComponentSpec spec = ComponentSpec('scroll-hint', {}, {
    'atStart',
    'middle',
    'atEnd',
    'pressed',
  });

  /// 흐림 폭(px). `scroll-hint.parts.fade.width`.
  static const double fadeWidth = 24;

  /// 화살표 터치 크기(px). `scroll-hint.parts.arrows.minTarget`.
  static const double minTarget = 44;

  /// 줄과 화살표 사이 간격(`arrows.marginTop`).
  static const double arrowsGap = Space.s4;

  /// 넘기는 줄이 쓰는 스크롤 컨트롤러.
  final ScrollController controller;

  /// 가로 스크롤 줄.
  final Widget child;

  /// 줄 아래 화살표 줄을 둘지. false면 흐림만입니다.
  final bool showArrows;

  @override
  State<ScrollHint> createState() => _ScrollHintState();
}

class _ScrollHintState extends State<ScrollHint> {
  bool _moreBefore = false;
  bool _moreAfter = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_sync);
  }

  @override
  void didUpdateWidget(ScrollHint oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_sync);
      widget.controller.addListener(_sync);
      // 새 컨트롤러는 자식이 이번 빌드에서 붙이므로 그 뒤에 다시 셉니다.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _sync();
      });
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_sync);
    super.dispose();
  }

  /// 스크롤 위치와 범위로 양쪽에 더 있는지 다시 셉니다.
  void _sync() {
    final controller = widget.controller;
    if (!controller.hasClients) return;
    final position = controller.position;
    if (!position.hasContentDimensions) return;
    const tolerance = 0.5;
    final before = position.pixels > position.minScrollExtent + tolerance;
    final after = position.pixels < position.maxScrollExtent - tolerance;
    if (before == _moreBefore && after == _moreAfter) return;
    setState(() {
      _moreBefore = before;
      _moreAfter = after;
    });
  }

  void _page(int direction) {
    final controller = widget.controller;
    if (!controller.hasClients) return;
    final position = controller.position;
    final target = (position.pixels + direction * position.viewportDimension)
        .clamp(position.minScrollExtent, position.maxScrollExtent);
    if (MotionPrefs.of(context).reduceMotion) {
      controller.jumpTo(target);
    } else {
      controller.animateTo(
        target,
        duration: Motion.short,
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.tokens.colors;
    final fadeDuration = MotionPrefs.of(context).reduceMotion
        ? Duration.zero
        : InteractionPattern.appearSeep.duration;
    final clear = colors.bgSheet.withAlpha(0);
    Widget fade({required bool visible, required bool start}) =>
        PositionedDirectional(
          top: 0,
          bottom: 0,
          start: start ? 0 : null,
          end: start ? null : 0,
          width: ScrollHint.fadeWidth,
          child: IgnorePointer(
            child: AnimatedOpacity(
              opacity: visible ? 1 : 0,
              duration: fadeDuration,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: start
                        ? AlignmentDirectional.centerStart
                        : AlignmentDirectional.centerEnd,
                    end: start
                        ? AlignmentDirectional.centerEnd
                        : AlignmentDirectional.centerStart,
                    colors: [colors.bgSheet, clear],
                  ),
                ),
              ),
            ),
          ),
        );

    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (_) {
        _sync();
        return false;
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            children: [
              widget.child,
              fade(visible: _moreBefore, start: true),
              fade(visible: _moreAfter, start: false),
            ],
          ),
          if (widget.showArrows && (_moreBefore || _moreAfter))
            Padding(
              padding: const EdgeInsets.only(top: ScrollHint.arrowsGap),
              child: ExcludeSemantics(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _Arrow(
                      glyph: _doubleLeft,
                      visible: _moreBefore,
                      duration: fadeDuration,
                      onTap: () => _page(-1),
                    ),
                    _Arrow(
                      glyph: _doubleRight,
                      visible: _moreAfter,
                      duration: fadeDuration,
                      onTap: () => _page(1),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 44 터치 영역 안 16 Light 겹 화살표. 보이지 않을 때도 자리는 지켜 반대쪽이 제 끝에 남습니다.
class _Arrow extends StatelessWidget {
  const new({
    required this.glyph,
    required this.visible,
    required this.duration,
    required this.onTap,
  });

  final AppGlyph glyph;
  final bool visible;
  final Duration duration;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const box = ScrollHint.minTarget;
    // 보이지 않을 때도 자리를 지켜 행 높이가 변하지 않고, 바뀔 때 seep으로 흐려집니다.
    return SizedBox.square(
      dimension: box,
      child: IgnorePointer(
        ignoring: !visible,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: duration,
          child: PressInkTarget(
            semanticLabel: '',
            onTap: onTap,
            inkColor: context.tokens.colors.textSecondary,
            borderRadius: BorderRadius.circular(box / 2),
            child: Center(
              child: AppIcon(
                glyph,
                size: AppIconSize.s16,
                color: context.tokens.colors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
