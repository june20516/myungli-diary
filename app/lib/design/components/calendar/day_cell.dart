import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:myungli_diary/design/components/component_spec.dart';
import 'package:myungli_diary/design/elements/seal.dart';
import 'package:myungli_diary/design/interaction/motion_prefs.dart';
import 'package:myungli_diary/design/interaction/patterns.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

/// 날짜 칸의 길흉(`day-cell` `parts.luckFill`).
enum DayLuck {
  /// 좋은 날: `calendar.good.bg`로 채웁니다.
  good,

  /// 보통 날: 채우지 않습니다.
  neutral,

  /// 조심할 날: `calendar.caution.bg`로 채웁니다.
  caution,
}

/// 날짜 칸 하나에 그릴 값. 화면 모델에서 바꿔 넘기는 design 계층 값입니다.
@immutable
final class DayCellData {
  /// 칸 값을 만듭니다.
  ///
  /// [luck]·[lunarText]가 null이면 그 층을 그리지 않습니다(아직 받지 못한 달).
  /// [lunarText]는 쓰는 쪽이 고른 글자입니다: 초하루 'M.1', 절기 날은 절기 이름
  /// ([lunarBold] true), 그 밖에는 일(日)만.
  const new({
    required this.date,
    required this.semanticLabel,
    this.luck,
    this.lunarText,
    this.lunarBold = false,
    this.diaryWritten = false,
    this.eventCount = 0,
  });

  /// 양력 날짜.
  final CalendarDate date;

  /// 길흉. null이면 채우지 않습니다.
  final DayLuck? luck;

  /// 음력·절기 글자. null이면 그리지 않습니다.
  final String? lunarText;

  /// 절기 날처럼 음력 글자를 굵게 그릴지.
  final bool lunarBold;

  /// 일기를 쓴 날인지(옅은 도장).
  final bool diaryWritten;

  /// 그날 일정 수. 1 이상이면 점을 찍습니다.
  final int eventCount;

  /// 스크린리더 라벨("M월 D일 요일, 음력 M.D 또는 절기, 길흉 낱말, 일기 씀, 일정 N개, 오늘").
  final String semanticLabel;
}

/// 날짜 칸이 달 격자의 한 줄(Semantics `row`) 안에 있음을 알립니다.
///
/// 이 아래의 [DayCell]은 Semantics role `cell`(명세 `gridcell`)로 읽힙니다. Flutter는
/// `cell`이 `row` 안에만 있도록 검사하므로, 홀로 쓰는 칸(Widgetbook 등)은 role 없이 읽힙니다.
class DayCellGridRow extends InheritedWidget {
  /// 격자 줄 표시를 만듭니다.
  const new({required super.child, super.key});

  /// [context] 위에 격자 줄이 있는지.
  static bool isInGrid(BuildContext context) =>
      context.getInheritedWidgetOfExactType<DayCellGridRow>() != null;

  @override
  bool updateShouldNotify(DayCellGridRow oldWidget) => false;
}

/// 날짜 칸(`day-cell`): 길흉 채우기·일기 도장·오늘 윤곽·숫자·선택 밑줄·일정 점과 음력.
///
/// 표시는 모두 같은 자리에서 겹쳐 그립니다(빼기 처리 없음). 겹침 순서는 [layerOrder]입니다.
/// 칸 안 글자는 시스템 글자 크기를 [textScaleMax]배까지만 따르고, 그 배율에서 내용이
/// [height]를 넘으면 칸이 늘어납니다. 눌림은 `press.ink`, 선택은 `mark.underline-grow`입니다.
class DayCell extends StatefulWidget {
  /// 칸을 만듭니다. [onTap]이 null이거나 [disabled]면 누를 수 없습니다.
  const new({
    required this.data,
    required this.isToday,
    required this.isSelected,
    required this.outsideMonth,
    required this.onTap,
    this.disabled = false,
    super.key,
  });

  /// 명세 대조용 요약.
  static const ComponentSpec spec = ComponentSpec('day-cell', {}, {
    'diaryWritten',
    'today',
    'selected',
    'selectedOnDiary',
    'hasEvent',
    'outsideMonth',
    'pressed',
    'disabled',
  });

  /// 기본 글자 크기에서의 칸 높이(`parts.container.height`).
  static const double height = 62;

  /// 숫자 상자 한 변(`parts.numberBox.size`).
  static const double numberBoxSize = 32;

  /// 숫자 상자 위 여백(`parts.numberBox.marginTop`).
  static const double numberBoxTop = 6;

  /// 음력 글자 크기(`parts.lunar.fontSize`).
  static const double lunarFontSize = 10.5;

  /// 일정 점 지름(`parts.eventDot.size`).
  static const double eventDotSize = 5;

  /// 음력과 일정 점 사이, 일정 점 아래 여백.
  static const double _dotGap = 2;

  /// 선택 밑줄 너비·두께·숫자와의 간격(`elements.json` `mark.underline-grow`).
  static const double underlineWidth = 14;

  /// 선택 밑줄 두께.
  static const double underlineHeight = 2;

  /// 숫자와 선택 밑줄 사이.
  static const double underlineGap = 2;

  /// 바깥 달 숫자 투명도(`states.outsideMonth.parts.number.opacity`).
  static const double outsideMonthOpacity = 0.35;

  /// 칸 글자 배율 상한(`a11y.textScaleMax`).
  static const double textScaleMax = 1.3;

  /// 길흉 채우기 층.
  static const Key luckFillKey = ValueKey('day-cell-luck-fill');

  /// 일기 도장 층.
  static const Key diarySealKey = ValueKey('day-cell-diary-seal');

  /// 오늘 윤곽 층.
  static const Key todayOutlineKey = ValueKey('day-cell-today-outline');

  /// 숫자 상자 층.
  static const Key numberKey = ValueKey('day-cell-number');

  /// 선택 밑줄 층.
  static const Key underlineKey = ValueKey('day-cell-underline');

  /// 선택 밑줄 막대.
  static const Key underlineBarKey = ValueKey('day-cell-underline-bar');

  /// 일정 점 층.
  static const Key eventDotKey = ValueKey('day-cell-event-dot');

  /// 음력 글자 자리.
  static const Key lunarKey = ValueKey('day-cell-lunar');

  /// 겹침 층을 담은 Stack.
  static const Key layersKey = ValueKey('day-cell-layers');

  /// 겹침 순서(아래부터, `parts.layers.order`).
  static const List<Key> layerOrder = [
    luckFillKey,
    diarySealKey,
    todayOutlineKey,
    numberKey,
    underlineKey,
    eventDotKey,
  ];

  /// 칸 값.
  final DayCellData data;

  /// 오늘인지(윤곽 도장).
  final bool isToday;

  /// 선택된 날인지(굵은 숫자 + 밑줄).
  final bool isSelected;

  /// 보이는 달 바깥 날짜인지(흐린 숫자, 길흉 채우기 없음).
  final bool outsideMonth;

  /// 누를 수 없는 날(date-picker calendar 변형의 미래 날짜).
  final bool disabled;

  /// 눌렀을 때. null이면 누를 수 없습니다.
  final VoidCallback? onTap;

  /// 숫자 상자 가운데에서 칸 위까지의 거리.
  static const double _numberCenterY = numberBoxTop + numberBoxSize / 2;

  @override
  State<DayCell> createState() => _DayCellState();
}

class _DayCellState extends State<DayCell> with TickerProviderStateMixin {
  // 처음부터 선택된 칸은 다 자란 밑줄로 시작합니다.
  late final AnimationController _underline = AnimationController(
    vsync: this,
    duration: InteractionPattern.markUnderlineGrow.duration,
    value: widget.isSelected ? 1 : 0,
  );
  late final AnimationController _press = AnimationController(
    vsync: this,
    duration: InteractionPattern.pressInk.duration,
  );
  late final AnimationController _release = AnimationController(
    vsync: this,
    duration: pressInkReleaseDuration,
  )..addStatusListener(_onReleased);

  Alignment _origin = Alignment.center;

  bool get _enabled => !widget.disabled && widget.onTap != null;

  @override
  void didUpdateWidget(DayCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected && !oldWidget.isSelected) {
      _underline.forward(from: 0);
    } else if (!widget.isSelected) {
      _underline.value = 0;
    }
  }

  @override
  void dispose() {
    _underline.dispose();
    _press.dispose();
    _release.dispose();
    super.dispose();
  }

  void _onReleased(AnimationStatus status) {
    if (status == AnimationStatus.completed) _press.value = 0;
  }

  void _down(TapDownDetails details) {
    final size = context.size;
    if (size == null || size.isEmpty) return;
    _origin = Alignment(
      details.localPosition.dx / size.width * 2 - 1,
      details.localPosition.dy / size.height * 2 - 1,
    );
    _release.value = 0;
    _press.forward(from: 0);
  }

  void _up() => _release.forward(from: 0);

  void _tap() {
    _up();
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final cell = MediaQuery.withClampedTextScaling(
      maxScaleFactor: DayCell.textScaleMax,
      child: Builder(builder: _layers),
    );
    final enabled = _enabled;
    return Semantics(
      container: true,
      role: DayCellGridRow.isInGrid(context) ? SemanticsRole.cell : null,
      label: widget.data.semanticLabel,
      selected: widget.isSelected,
      enabled: widget.disabled ? false : (enabled ? true : null),
      onTap: enabled ? widget.onTap : null,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: enabled ? _down : null,
          onTapUp: enabled ? (_) => _tap() : null,
          onTapCancel: enabled ? _up : null,
          child: animate(
            InteractionPattern.pressInk,
            t: _press,
            prefs: MotionPrefs.of(context),
            options: PatternOptions(
              origin: _origin,
              release: _release,
              inkColor: context.tokens.colors.textPrimary,
              borderRadius: const BorderRadius.all(Radius.circular(Radii.sm)),
            ),
            child: cell,
          ),
        ),
      ),
    );
  }

  /// 글자 배율 상한을 입힌 [context]에서 겹침 층을 그립니다.
  Widget _layers(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final type = tokens.typography;
    final scaler = MediaQuery.textScalerOf(context);
    final data = widget.data;

    final numberStyle = _numberStyle(tokens);
    final numberHeight = _lineHeight(numberStyle, scaler);
    final lunarStyle = type.captionSm.copyWith(
      fontSize: DayCell.lunarFontSize,
      color: colors.textSecondary,
      fontWeight: data.lunarBold ? FontWeight.w700 : null,
    );
    // 음력 줄 자리는 글자가 없어도 비워 두어 일정 점 위치가 칸마다 같습니다.
    final lunarHeight =
        scaler.scale(DayCell.lunarFontSize) * (lunarStyle.height ?? 1);
    const lunarTop = DayCell.numberBoxTop + DayCell.numberBoxSize;
    final dotTop = lunarTop + lunarHeight + DayCell._dotGap;
    final cellHeight = math.max(
      DayCell.height,
      dotTop + DayCell.eventDotSize + DayCell._dotGap,
    );

    final luck = widget.outsideMonth ? null : data.luck;
    final luckColor = switch (luck) {
      DayLuck.good => colors.calendarGoodBg,
      DayLuck.caution => colors.calendarCautionBg,
      DayLuck.neutral || null => null,
    };
    final lunarText = data.lunarText;

    Widget centeredAt(double top, double height, Widget child, {Key? key}) =>
        Positioned(
          key: key,
          top: top,
          left: 0,
          right: 0,
          height: height,
          child: Center(child: child),
        );

    final sealTop = DayCell._numberCenterY - SealSize.cell.logical / 2;
    Widget number = Text(
      '${data.date.day}',
      maxLines: 1,
      softWrap: false,
      textAlign: TextAlign.center,
      style: numberStyle,
    );
    if (widget.outsideMonth) {
      number = Opacity(opacity: DayCell.outsideMonthOpacity, child: number);
    }

    return SizedBox(
      height: cellHeight,
      child: Stack(
        key: DayCell.layersKey,
        clipBehavior: Clip.none,
        children: [
          if (luckColor != null)
            Positioned.fill(
              key: DayCell.luckFillKey,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: luckColor,
                  borderRadius: const BorderRadius.all(
                    Radius.circular(Radii.sm),
                  ),
                ),
              ),
            ),
          if (data.diaryWritten)
            centeredAt(
              sealTop,
              SealSize.cell.logical,
              const Seal(size: SealSize.cell, variant: SealVariant.soft),
              key: DayCell.diarySealKey,
            ),
          if (widget.isToday)
            centeredAt(
              sealTop,
              SealSize.cell.logical,
              const Seal(size: SealSize.cell, variant: SealVariant.outline),
              key: DayCell.todayOutlineKey,
            ),
          centeredAt(
            DayCell.numberBoxTop,
            DayCell.numberBoxSize,
            number,
            key: DayCell.numberKey,
          ),
          if (lunarText != null)
            centeredAt(
              lunarTop,
              lunarHeight,
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  lunarText,
                  maxLines: 1,
                  softWrap: false,
                  style: lunarStyle,
                ),
              ),
              key: DayCell.lunarKey,
            ),
          if (widget.isSelected)
            centeredAt(
              DayCell._numberCenterY + numberHeight / 2 + DayCell.underlineGap,
              DayCell.underlineHeight,
              animate(
                InteractionPattern.markUnderlineGrow,
                t: _underline,
                prefs: MotionPrefs.of(context),
                child: DecoratedBox(
                  key: DayCell.underlineBarKey,
                  decoration: BoxDecoration(
                    color: colors.actionPrimary,
                    borderRadius: const BorderRadius.all(
                      Radius.circular(Radii.full),
                    ),
                  ),
                  child: const SizedBox(
                    width: DayCell.underlineWidth,
                    height: DayCell.underlineHeight,
                  ),
                ),
              ),
              key: DayCell.underlineKey,
            ),
          if (data.eventCount > 0)
            centeredAt(
              dotTop,
              DayCell.eventDotSize,
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.actionPrimary,
                  shape: BoxShape.circle,
                ),
                child: const SizedBox.square(dimension: DayCell.eventDotSize),
              ),
              key: DayCell.eventDotKey,
            ),
        ],
      ),
    );
  }

  /// 상태에 따른 숫자 글자: 선택(+일기)·누를 수 없음·평소.
  TextStyle _numberStyle(MyungliTokens tokens) {
    final colors = tokens.colors;
    final base = tokens.typography.numericCalendar;
    if (widget.disabled) return base.copyWith(color: colors.disabledFg);
    if (widget.isSelected) {
      // 옅은 도장 위 sage 숫자는 대비를 위해 한 단계 진한 seal.on-soft(V24).
      return base.copyWith(
        color: widget.data.diaryWritten
            ? colors.sealOnSoft
            : colors.actionPrimary,
        fontWeight: FontWeight.w700,
      );
    }
    return base.copyWith(color: colors.textPrimary);
  }

  /// [style]·[scaler]로 그린 한 줄의 높이.
  static double _lineHeight(TextStyle style, TextScaler scaler) {
    final painter = TextPainter(
      text: TextSpan(text: '0', style: style),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    final height = painter.height;
    painter.dispose();
    return height;
  }
}
