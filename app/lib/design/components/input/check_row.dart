import 'dart:async';

import 'package:flutter/material.dart';
import 'package:myungli_diary/design/components/component_spec.dart';
import 'package:myungli_diary/design/components/sentence/press_ink_target.dart';
import 'package:myungli_diary/design/components/sentence/vertical_hit_slop.dart';
import 'package:myungli_diary/design/interaction/haptics.dart';
import 'package:myungli_diary/design/interaction/motion_prefs.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

/// [CheckRow] 변형(`check-row` `variants`).
enum CheckRowVariant {
  /// 동의 항목: 줄마다 떨어진 카드. 오른쪽에 '보기' 링크가 붙을 수 있습니다.
  card,

  /// 다른 입력 아래 붙는 체크 하나(시간 '모름'). 바탕·'보기' 링크가 없습니다.
  inline,
}

/// 동의 항목 한 줄(`check-row`).
///
/// 줄을 누르면 [onChanged]가 반대 값으로 불리고 selection 햅틱이 나갑니다.
/// `card`의 '보기'([viewLabel])는 따로 초점을 받는 링크이고, 눌러도 체크는 바뀌지
/// 않으며 [onView]만 불립니다. [onChanged]가 null이면 disabled입니다.
///
/// 줄 높이는 내용에 맞는 최소 높이라 글자가 커지면 줄이 함께 커집니다.
class CheckRow extends StatefulWidget {
  /// 체크 줄을 만듭니다.
  ///
  /// [identifier]는 IA 슬롯 id(체크 줄 Semantics `identifier`), [viewIdentifier]는
  /// '보기' 링크의 슬롯 id입니다.
  const new({
    required this.variant,
    required this.label,
    required this.checked,
    required this.onChanged,
    this.viewLabel,
    this.onView,
    this.identifier,
    this.viewIdentifier,
    super.key,
  });

  /// 명세 대조용 요약.
  static const ComponentSpec spec = ComponentSpec(
    'check-row',
    {'card', 'inline'},
    {'checked', 'pressed', 'disabled'},
  );

  /// 줄 바탕 상자를 찾는 테스트용 키.
  static const Key containerKey = ValueKey('check-row-container');

  /// 체크 상자를 찾는 테스트용 키.
  static const Key boxKey = ValueKey('check-row-box');

  /// 체크 표시(그어지는 선)를 찾는 테스트용 키.
  static const Key checkMarkKey = ValueKey('check-row-check');

  static const double _boxSize = 24;
  static const double _boxBorder = 1.5;
  static const double _inlineMinHeight = 44;
  static const double _minTarget = 48;

  /// 변형.
  final CheckRowVariant variant;

  /// 항목 글자.
  final String label;

  /// 체크 여부.
  final bool checked;

  /// 켜고 끌 때. 새 값을 줍니다. null이면 disabled.
  final ValueChanged<bool>? onChanged;

  /// '보기' 링크 글자. `card`에서만 그립니다.
  final String? viewLabel;

  /// '보기'를 눌렀을 때. 체크는 바뀌지 않습니다.
  final VoidCallback? onView;

  /// IA 슬롯 id.
  final String? identifier;

  /// '보기' 링크의 IA 슬롯 id.
  final String? viewIdentifier;

  @override
  State<CheckRow> createState() => _CheckRowState();
}

class _CheckRowState extends State<CheckRow>
    with SingleTickerProviderStateMixin {
  // 체크 표시가 0→1로 그어지는 `drawDuration`(motion.duration.short)과 `seep` 곡선.
  late final AnimationController _draw = AnimationController(
    vsync: this,
    duration: Motion.short,
    value: widget.checked ? 1 : 0,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _draw.duration = MotionPrefs.of(context).reduceMotion
        ? Duration.zero
        : Motion.short;
  }

  @override
  void didUpdateWidget(CheckRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.checked == oldWidget.checked) return;
    if (widget.checked) {
      _draw.forward();
    } else {
      _draw.reverse();
    }
  }

  @override
  void dispose() {
    _draw.dispose();
    super.dispose();
  }

  void _toggle() {
    unawaited(Haptics.selection());
    widget.onChanged!(!widget.checked);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final card = widget.variant == CheckRowVariant.card;
    final enabled = widget.onChanged != null;
    final labelColor = enabled ? colors.textPrimary : colors.disabledFg;
    const radius = BorderRadius.all(Radius.circular(Radii.md));

    final box = AnimatedBuilder(
      animation: _draw,
      builder: (context, _) {
        final filled = widget.checked || _draw.value > 0;
        // disabled: 명세는 라벨 색(`color.disabled.fg`)만 정합니다. 체크된 상자가
        // `action.primary`로 남으면 눌릴 것처럼 보여서 상자 채움도 `color.disabled.fg`로 죽입니다.
        final fill = enabled ? colors.actionPrimary : colors.disabledFg;
        return DecoratedBox(
          key: CheckRow.boxKey,
          decoration: BoxDecoration(
            color: filled ? fill : null,
            borderRadius: BorderRadius.circular(Radii.sm),
            border: Border.all(
              width: CheckRow._boxBorder,
              color: filled ? fill : colors.line,
            ),
          ),
          child: SizedBox.square(
            dimension: CheckRow._boxSize,
            child: CustomPaint(
              key: CheckRow.checkMarkKey,
              painter: _CheckPainter(
                progress: Motion.seep.transform(_draw.value),
                color: colors.actionOnPrimary,
              ),
            ),
          ),
        );
      },
    );

    final row = Row(
      children: [
        box,
        const SizedBox(width: Space.s12),
        Expanded(
          child: Text(
            widget.label,
            style: tokens.typography.bodyUi.copyWith(color: labelColor),
          ),
        ),
      ],
    );

    final toggleBody = card
        ? Padding(padding: const EdgeInsets.all(Space.s16), child: row)
        : ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: CheckRow._inlineMinHeight,
            ),
            child: Center(heightFactor: 1, child: row),
          );

    var toggle = enabled
        ? PressInkTarget(
            semanticLabel: widget.label,
            onTap: _toggle,
            borderRadius: radius,
            inkColor: labelColor,
            child: toggleBody,
          )
        : toggleBody;
    // 체크 상자는 button이 아니라 checkbox로 읽힙니다. 눌림 노드의 button 의미는 덮어씁니다.
    toggle = Semantics(
      container: true,
      excludeSemantics: true,
      checked: widget.checked,
      enabled: enabled,
      identifier: widget.identifier,
      label: widget.label,
      onTap: enabled ? _toggle : null,
      child: toggle,
    );

    final viewLabel = widget.viewLabel;
    final onView = widget.onView;
    final showView = card && viewLabel != null && onView != null;

    final line = Row(
      children: [
        Expanded(child: toggle),
        if (showView)
          _ViewLink(
            label: viewLabel,
            identifier: widget.viewIdentifier,
            onView: onView,
          ),
      ],
    );

    final framed = Padding(
      padding: EdgeInsets.only(bottom: card ? Space.s8 : 0),
      child: DecoratedBox(
        key: CheckRow.containerKey,
        decoration: BoxDecoration(
          color: card ? colors.bgSheet : null,
          borderRadius: radius,
        ),
        child: line,
      ),
    );
    // inline은 높이 44라 눌림 판정만 위아래로 48까지 넓힙니다. 판정이 안쪽 상자에서
    // 막히지 않도록 가장 바깥에 둡니다.
    return card
        ? framed
        : VerticalHitSlop(minHeight: CheckRow._minTarget, child: framed);
  }
}

/// 카드 오른쪽 '보기' 링크. 체크와 따로 초점을 받고 눌림 영역은 48px입니다.
class _ViewLink extends StatelessWidget {
  const new({required this.label, required this.onView, this.identifier});

  final String label;
  final String? identifier;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final color = tokens.colors.actionPrimary;
    return Padding(
      padding: const EdgeInsets.only(right: Space.s4),
      // PressInkTarget 안쪽(Stack)이 제약을 느슨하게 풀어 주므로 최소 크기는 child에 둡니다.
      // 그래야 눌림 영역이 48이고 글자가 그 안에서 세로 가운데에 놓입니다.
      child: PressInkTarget(
        link: true,
        semanticLabel: label,
        identifier: identifier,
        onTap: onView,
        inkColor: color,
        borderRadius: const BorderRadius.all(Radius.circular(Radii.sm)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: CheckRow._minTarget,
            minHeight: CheckRow._minTarget,
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.s12),
              child: Text(
                label,
                style: tokens.typography.labelMd.copyWith(color: color),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 체크 표시를 [progress](0~1)만큼 긋습니다.
class _CheckPainter extends CustomPainter {
  const new({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final path = Path()
      ..moveTo(size.width * 0.24, size.height * 0.52)
      ..lineTo(size.width * 0.43, size.height * 0.70)
      ..lineTo(size.width * 0.76, size.height * 0.32);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final metric = path.computeMetrics().first;
    canvas.drawPath(metric.extractPath(0, metric.length * progress), paint);
  }

  @override
  bool shouldRepaint(_CheckPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
