import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:myungli_diary/design/components/component_spec.dart';
import 'package:myungli_diary/design/components/sentence/press_ink_target.dart';
import 'package:myungli_diary/design/components/sentence/vertical_hit_slop.dart';
import 'package:myungli_diary/design/interaction/haptics.dart';
import 'package:myungli_diary/design/interaction/motion_prefs.dart';
import 'package:myungli_diary/design/interaction/patterns.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

/// [Segmented]의 항목 하나.
@immutable
final class SegmentedItem<T> {
  /// 값과 보이는 글자로 만듭니다.
  const new(this.value, this.label);

  /// 이 항목을 고르면 돌려줄 값.
  final T value;

  /// 항목 글자. 한 줄이어야 하므로 화면 설계에서 짧게 정합니다.
  final String label;
}

/// 몇 개 중 하나 고르기(`segmented`).
///
/// `bg.sheet` + 1px `line` 알약 트랙 안에서 선택 표시(`action.primary` 알약)가
/// `select.seep-slide`로 옮겨 갑니다. 항목은 2~4개이고 너비가 같습니다. 다른 항목을
/// 누르면 [onChanged]와 selection 햅틱이 한 번 나가고, 이미 고른 항목을 다시 누르면
/// 아무 일도 없습니다. [onChanged]가 null이면 모두 disabled입니다.
///
/// [selected]가 null이면(`T`가 null을 허용할 때) 아직 고르지 않은 상태(`none`)라 선택
/// 표시가 없고 모든 글자가 `text.secondary`입니다. 이때 `input-step` 아래 버튼을 꺼 두는
/// 것은 화면의 몫입니다(`onAction: null`). `none`에서 처음 고르면 표시는 미끄러지지 않고
/// 그 자리에 `appear.seep`으로 나타나고, 그다음 선택부터 `select.seep-slide`입니다.
///
/// 트랙 높이 40은 최소 높이라 기기 글자 크기가 크면 함께 커집니다. 항목 글자는 줄을
/// 바꾸지 않고 자르지도 않습니다. 넘치지 않게 문구와 항목 수를 정하는 것은 화면
/// 설계의 몫입니다.
class Segmented<T> extends StatefulWidget {
  /// 선택 상자를 만듭니다. [label]은 무엇을 고르는지(스크린리더 그룹 라벨)입니다.
  // assert가 목록을 훑으므로 const 생성자가 아닙니다.
  new({
    required this.items,
    required this.selected,
    required this.onChanged,
    required this.label,
    this.identifier,
    super.key,
  }) : assert(items.length >= 2 && items.length <= 4, 'segmented 항목은 2~4개입니다.'),
       assert(
         selected == null || items.any((item) => item.value == selected),
         'selected는 items 안의 값이거나, 아직 고르지 않았다면 null이어야 합니다.',
       );

  /// 명세 대조용 요약.
  static const ComponentSpec spec = ComponentSpec('segmented', {}, {
    'selected',
    'pressed',
    'disabled',
    'none',
  });

  /// 트랙을 찾는 테스트용 키.
  static const Key trackKey = ValueKey('segmented-track');

  /// 선택 표시(알약)를 찾는 테스트용 키.
  static const Key indicatorKey = ValueKey('segmented-indicator');

  /// [index]번째 항목을 찾는 테스트용 키.
  static Key itemKey(int index) => ValueKey('segmented-item-$index');

  static const double _trackHeight = 40;
  static const double _padding = 3;

  /// 항목 2~4개.
  final List<SegmentedItem<T>> items;

  /// 선택된 값.
  final T selected;

  /// 다른 항목을 골랐을 때. null이면 disabled.
  final ValueChanged<T>? onChanged;

  /// 무엇을 고르는지(스크린리더 그룹 라벨).
  final String label;

  /// IA 슬롯 id. 있으면 그룹 Semantics `identifier`로 붙입니다.
  final String? identifier;

  @override
  State<Segmented<T>> createState() => _SegmentedState<T>();
}

class _SegmentedState<T> extends State<Segmented<T>> {
  /// 직전에 선택돼 있던 항목의 자리. 새 표시가 어느 쪽에서 미끄러져 올지 정합니다.
  /// 처음 그린 뒤 바뀐 적이 없으면 null, 직전이 `none`(고르지 않음)이었으면 -1입니다.
  int? _previousIndex;

  /// 직전이 `none`이었으면 새 표시는 미끄러지지 않고 스며 나타납니다.
  bool get _fromNone => _previousIndex == -1;

  int _indexOf(T value) =>
      widget.items.indexWhere((item) => item.value == value);

  @override
  void didUpdateWidget(Segmented<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected) {
      _previousIndex = oldWidget.items.indexWhere(
        (item) => item.value == oldWidget.selected,
      );
    }
  }

  void _choose(T value) {
    if (value == widget.selected) return;
    unawaited(Haptics.selection());
    widget.onChanged!(value);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.tokens.colors;
    final selectedIndex = _indexOf(widget.selected);
    final enabled = widget.onChanged != null;

    // 트랙(40)이 최소 터치 크기 44보다 낮아 눌림 판정만 위아래로 넓힙니다(기본 44).
    // 판정이 Semantics 같은 중간 상자에서 막히지 않도록 가장 바깥에 둡니다.
    return VerticalHitSlop(
      child: Semantics(
        container: true,
        role: SemanticsRole.radioGroup,
        label: widget.label,
        identifier: widget.identifier,
        child: DecoratedBox(
          key: Segmented.trackKey,
          decoration: BoxDecoration(
            color: colors.bgSheet,
            border: Border.all(color: colors.line),
            borderRadius: BorderRadius.circular(Radii.full),
          ),
          // 항목은 트랙 높이를 모두 차지하고, 알약만 위아래로 3px 들어갑니다.
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Segmented._padding),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < widget.items.length; i++)
                    Expanded(
                      child: _SegmentCell(
                        key: Segmented.itemKey(i),
                        label: widget.items[i].label,
                        selected: i == selectedIndex,
                        enabled: enabled,
                        fromNone: _fromNone,
                        // 이전 표시가 이 항목의 왼쪽(-1)에 있었는지 오른쪽(1)에 있었는지.
                        previousSide: _previousIndex == null || _fromNone
                            ? 0
                            : (_previousIndex! - i).sign.toDouble(),
                        onTap: () => _choose(widget.items[i].value),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 항목 하나. 선택 표시의 들어옴·나감을 자기 안에서 그립니다.
class _SegmentCell extends StatefulWidget {
  const new({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.fromNone,
    required this.previousSide,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final bool enabled;

  /// 직전이 `none`이라 새 표시가 `appear.seep`으로 나타나는지.
  final bool fromNone;
  final double previousSide;
  final VoidCallback onTap;

  @override
  State<_SegmentCell> createState() => _SegmentCellState();
}

class _SegmentCellState extends State<_SegmentCell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _slide = AnimationController(
    vsync: this,
    duration: InteractionPattern.selectSeepSlide.duration,
  )..addStatusListener(_onStatus);

  /// 선택이 풀린 뒤 이전 표시가 사라지는 동안 true입니다.
  bool _outgoing = false;

  @override
  void initState() {
    super.initState();
    // 처음부터 선택된 항목은 애니메이션 없이 선명하게 시작합니다.
    if (widget.selected) _slide.value = 1;
  }

  /// 지금 표시가 따르는 패턴. `none`에서 처음 고른 표시만 `appear.seep`입니다.
  InteractionPattern get _pattern => widget.fromNone && widget.selected
      ? InteractionPattern.appearSeep
      : InteractionPattern.selectSeepSlide;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _slide.duration = patternDuration(_pattern, MotionPrefs.of(context));
  }

  @override
  void didUpdateWidget(_SegmentCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected == oldWidget.selected) return;
    _outgoing = !widget.selected;
    _slide
      ..duration = patternDuration(_pattern, MotionPrefs.of(context))
      ..forward(from: 0);
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && _outgoing && mounted) {
      setState(() => _outgoing = false);
    }
  }

  @override
  void dispose() {
    _slide.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final prefs = MotionPrefs.of(context);
    final selected = widget.selected;
    final labelColor = !widget.enabled
        ? colors.disabledFg
        : selected
        ? colors.actionOnPrimary
        : colors.textSecondary;
    // disabled: 명세는 라벨 색(`color.disabled.fg`)만 정합니다. 선택 알약이 그대로
    // `action.primary`로 남으면 눌릴 것처럼 보여서 알약도 `color.disabled.bg`로 죽입니다.
    const radius = BorderRadius.all(Radius.circular(Radii.full));

    final pill = DecoratedBox(
      key: Segmented.indicatorKey,
      decoration: BoxDecoration(
        color: widget.enabled ? colors.actionPrimary : colors.disabledBg,
        borderRadius: radius,
      ),
      child: const SizedBox.expand(),
    );

    final indicator = selected || _outgoing
        ? Positioned.fill(
            child: animate(
              _pattern,
              t: _slide,
              prefs: prefs,
              options: PatternOptions(
                previousSide: Offset(widget.previousSide, 0),
                outgoing: _outgoing,
              ),
              child: pill,
            ),
          )
        : null;

    // 항목 칸은 트랙 높이 40 이상을 모두 차지하고 알약만 위아래로 3px 들어갑니다.
    // 눌림 영역이 칸 너비를 모두 차지하도록 너비를 채웁니다.
    final content = ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: Segmented._trackHeight,
        minWidth: double.infinity,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Segmented._padding),
        child: Stack(
          alignment: Alignment.center,
          children: [
            ?indicator,
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Space.s12,
                vertical: Space.s4,
              ),
              child: Text(
                widget.label,
                maxLines: 1,
                softWrap: false,
                textAlign: TextAlign.center,
                style: tokens.typography.labelLg.copyWith(color: labelColor),
              ),
            ),
          ],
        ),
      ),
    );

    final target = widget.enabled
        ? PressInkTarget(
            semanticLabel: widget.label,
            onTap: widget.onTap,
            borderRadius: radius,
            inkColor: labelColor,
            child: content,
          )
        : content;

    // 명세 a11y는 항목 role을 radio로 적었지만 Flutter `SemanticsRole`에는 radio가 없습니다.
    // 그래서 Flutter 표준대로 그룹은 `radioGroup`, 항목은 `inMutuallyExclusiveGroup` +
    // `checked`(선택된 것만 true)로 표현합니다. 눌림 노드의 button 의미는 덮어씁니다.
    return Semantics(
      container: true,
      excludeSemantics: true,
      inMutuallyExclusiveGroup: true,
      checked: selected,
      enabled: widget.enabled,
      label: widget.label,
      onTap: widget.enabled ? widget.onTap : null,
      child: target,
    );
  }
}
