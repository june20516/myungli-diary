import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:myungli_diary/design/interaction/haptics.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

/// 휠 한 줄의 보이는 칸 수(`date-picker`·`time-picker` `wheels.visibleRows`).
const int wheelVisibleRows = 5;

/// 휠 한 칸의 기본 높이(px, `wheels.rowHeight`). 최소 높이입니다.
const double wheelRowHeight = 40;

/// 글자 크기 설정을 반영한 휠 한 칸의 높이.
///
/// 명세 40px은 최소 높이입니다. 글자가 커져 `type.subtitle` 한 줄(위아래 `space.8` 포함)이
/// 40보다 높아지면 칸도 함께 커져, 칸 안에서 글자가 잘리지 않습니다. 이때 휠 전체 높이
/// (칸 수 5)도 비례해 커집니다.
double wheelRowHeightOf(BuildContext context) {
  final style = context.tokens.typography.subtitle;
  final line =
      MediaQuery.textScalerOf(context).scale(style.fontSize!) *
      (style.height ?? 1);
  return math.max(wheelRowHeight, line + Space.s8 * 2);
}

/// 휠 한 줄. `ListWheelScrollView` 위에 얹은 항목 고르기입니다.
///
/// 칸 글자는 `type.subtitle`, `color.text.primary`입니다. 한 칸 넘어갈 때마다
/// selection 햅틱이 한 번 나가고 [onSelectedIndexChanged]가 불립니다. 부모가 [selectedIndex]를
/// 바꾸면 햅틱 없이 그 칸으로 옮깁니다. [enabled]가 false면 끌 수 없고 증가·감소 동작도
/// 없습니다.
///
/// 스크린리더에는 [semanticLabel]을 이름, 고른 칸 글자를 값으로 가진 조절 가능한(증가·감소)
/// 한 노드로 보입니다. 칸 하나하나는 읽지 않습니다.
class Wheel extends StatefulWidget {
  /// 휠을 만듭니다. `WheelGroup` 안에서 [flex]만큼 너비를 나눠 가집니다.
  const new({
    required this.itemCount,
    required this.selectedIndex,
    required this.itemLabel,
    required this.onSelectedIndexChanged,
    required this.semanticLabel,
    this.semanticItemLabel,
    this.enabled = true,
    this.flex = 1,
    this.identifier,
    super.key,
  }) : assert(itemCount > 0, '휠에는 칸이 하나 이상 있어야 합니다.');

  /// 칸 수.
  final int itemCount;

  /// 고른 칸의 자리(0부터).
  final int selectedIndex;

  /// `index`번째 칸의 글자.
  final String Function(int index) itemLabel;

  /// 사용자가 다른 칸으로 옮겼을 때.
  final ValueChanged<int> onSelectedIndexChanged;

  /// 스크린리더 이름(무엇을 고르는 휠인지).
  final String semanticLabel;

  /// 스크린리더가 읽는 칸 글자. null이면 [itemLabel]을 읽습니다(윤달의 '윤' 붙이기 등).
  final String Function(int index)? semanticItemLabel;

  /// false면 끌 수 없습니다.
  final bool enabled;

  /// `WheelGroup` 안의 너비 비율.
  final int flex;

  /// IA 슬롯 id. 있으면 Semantics `identifier`로 붙입니다.
  final String? identifier;

  @override
  State<Wheel> createState() => _WheelState();
}

class _WheelState extends State<Wheel> {
  late FixedExtentScrollController _controller;

  int get _clampedSelected =>
      widget.selectedIndex.clamp(0, widget.itemCount - 1);

  @override
  void initState() {
    super.initState();
    _controller = FixedExtentScrollController(initialItem: _clampedSelected);
  }

  @override
  void didUpdateWidget(Wheel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 부모가 값을 바꿨는데 휠이 다른 칸에 있으면(날수가 줄어 맞춰진 경우 등) 옮겨 놓습니다.
    // 스크롤 위치는 빌드 중에 건드릴 수 없어 프레임이 끝난 뒤에 옮깁니다.
    if (oldWidget.selectedIndex != widget.selectedIndex ||
        oldWidget.itemCount != widget.itemCount) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _syncToParent());
    }
  }

  /// 휠이 부모가 정한 칸에 있지 않으면 옮깁니다. 사용자가 끌거나 튕긴 관성이 남아 있는
  /// 동안에는 건드리지 않습니다(부모가 앞선 칸 값으로 다시 빌드해도 관성을 끊지 않도록).
  /// 스크롤이 멈추면 [NotificationListener]가 다시 맞춥니다.
  void _syncToParent() {
    if (!mounted || !_controller.hasClients) return;
    if (_controller.position.isScrollingNotifier.value) return;
    if (_controller.selectedItem != _clampedSelected) {
      _controller.jumpToItem(_clampedSelected);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onWheelChanged(int index) {
    // 부모가 정한 값과 같은 칸은 사용자가 옮긴 것이 아닙니다(초기 위치, 부모의 변경).
    if (index == widget.selectedIndex || !widget.enabled) return;
    unawaited(Haptics.selection());
    widget.onSelectedIndexChanged(index);
  }

  void _step(int delta) {
    final target = _clampedSelected + delta;
    if (target < 0 || target >= widget.itemCount) return;
    _controller.animateToItem(
      target,
      duration: Motion.short,
      curve: Motion.seep,
    );
  }

  String _labelAt(int index) => (widget.semanticItemLabel ?? widget.itemLabel)(
    index.clamp(0, widget.itemCount - 1),
  );

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final rowHeight = wheelRowHeightOf(context);
    final selected = _clampedSelected;
    final enabled = widget.enabled;

    final list = ListWheelScrollView.useDelegate(
      controller: _controller,
      itemExtent: rowHeight,
      physics: const FixedExtentScrollPhysics(),
      // 거의 평평한 휠: 보이는 칸이 정확히 [wheelVisibleRows]개가 됩니다.
      diameterRatio: 100,
      perspective: 0.0001,
      onSelectedItemChanged: _onWheelChanged,
      childDelegate: ListWheelChildBuilderDelegate(
        childCount: widget.itemCount,
        builder: (context, index) => Center(
          child: Text(
            widget.itemLabel(index),
            maxLines: 1,
            softWrap: false,
            style: tokens.typography.subtitle.copyWith(
              color: tokens.colors.textPrimary,
            ),
          ),
        ),
      ),
    );

    return Semantics(
      container: true,
      identifier: widget.identifier,
      label: widget.semanticLabel,
      value: _labelAt(selected),
      increasedValue: _labelAt(selected + 1),
      decreasedValue: _labelAt(selected - 1),
      enabled: enabled,
      onIncrease: enabled && selected < widget.itemCount - 1
          ? () => _step(1)
          : null,
      onDecrease: enabled && selected > 0 ? () => _step(-1) : null,
      child: ExcludeSemantics(
        child: NotificationListener<ScrollEndNotification>(
          onNotification: (_) {
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _syncToParent(),
            );
            return false;
          },
          child: IgnorePointer(ignoring: !enabled, child: list),
        ),
      ),
    );
  }
}

/// [Wheel] 여럿을 한 줄에 놓고 선택 띠와 위아래 흐림을 입힌 묶음.
///
/// 선택 띠는 `color.status.bg` `radius.md`이고 가운데 한 칸 높이로 모든 휠을 가로지릅니다.
/// 위아래 가장자리는 투명하게 흐려집니다. 높이는 `칸 높이 × 5`입니다.
class WheelGroup extends StatelessWidget {
  /// 휠을 나란히 놓습니다.
  const new({required this.wheels, super.key});

  /// 왼쪽부터의 휠. 너비는 각 [Wheel.flex] 비율입니다.
  final List<Wheel> wheels;

  /// 선택 띠를 찾는 테스트용 키.
  static const Key bandKey = ValueKey('wheel-band');

  @override
  Widget build(BuildContext context) {
    final rowHeight = wheelRowHeightOf(context);
    return SizedBox(
      height: rowHeight * wheelVisibleRows,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: rowHeight * (wheelVisibleRows ~/ 2),
            height: rowHeight,
            child: DecoratedBox(
              key: bandKey,
              decoration: BoxDecoration(
                color: context.tokens.colors.statusBg,
                borderRadius: BorderRadius.circular(Radii.md),
              ),
            ),
          ),
          Positioned.fill(
            child: ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: (bounds) => const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x1FFFFFFF),
                  Color(0xFFFFFFFF),
                  Color(0xFFFFFFFF),
                  Color(0x1FFFFFFF),
                ],
                stops: [0, 0.3, 0.7, 1],
              ).createShader(bounds),
              child: Row(
                children: [
                  for (final wheel in wheels)
                    Expanded(flex: wheel.flex, child: wheel),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
