import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/calendar/day_cell.dart';
import 'package:myungli_diary/design/components/component_spec.dart';
import 'package:myungli_diary/design/components/feedback/seep_on_change.dart';
import 'package:myungli_diary/design/components/feedback/skeleton.dart';
import 'package:myungli_diary/design/elements/app_icon.dart';
import 'package:myungli_diary/design/elements/seal.dart';
import 'package:myungli_diary/design/elements/skeleton_bone.dart';
import 'package:myungli_diary/design/interaction/motion_prefs.dart';
import 'package:myungli_diary/design/interaction/patterns.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';
import 'package:phosphor_glyphs/phosphor_glyphs.dart';

const AppGlyph _caretLeft = AppGlyph(
  light: PhosphorIconsLight.caretLeft,
  regular: PhosphorIconsRegular.caretLeft,
);

const AppGlyph _caretRight = AppGlyph(
  light: PhosphorIconsLight.caretRight,
  regular: PhosphorIconsRegular.caretRight,
);

/// 범례 한 줄: 색 견본과 낱말.
typedef CalendarLegendEntry = ({Color swatch, String label});

/// 한 달 격자(`calendar-month`): 달 제목·이전·다음, 요일 머리, 일요일 시작 6주 42칸, 범례.
///
/// 달 넘김은 이전·다음 버튼과 격자 좌우 밀기 모두로 [onMonthChange]를 부릅니다. 지원 범위
/// ([CalendarMonth.isSupported]) 밖으로는 넘어가지 않고 그쪽 버튼은 흐리게 막힙니다. 넘김
/// 움직임은 격자만 `appear.seep`이고(가로 이동 없음) 머리는 그대로입니다. [loading]이면 이 달
/// 칸의 길흉 채우기·도장 자리만 skeleton이고 숫자는 바로 보입니다.
///
/// 달 제목·요일 머리 글자는 로케일 형식이라 쓰는 쪽이 만들어 넘기고, 이전·다음 버튼의
/// 접근성 이름은 컴포넌트가 ARB에서 고릅니다.
class CalendarMonthView extends StatefulWidget {
  /// 달 격자를 만듭니다.
  ///
  /// [weekdayLabels]는 일요일부터 토요일까지 7개입니다. [cellOf]는 격자 42칸의 날짜마다
  /// 칸 값을 돌려줍니다. [legend]가 있으면 격자 아래에 범례를 두고, [legendIdentifier]는
  /// 그 IA 슬롯 id(`calendar.legend.body`)입니다.
  const new({
    required this.month,
    required this.title,
    required this.weekdayLabels,
    required this.cellOf,
    required this.loading,
    required this.today,
    required this.onSelect,
    required this.onMonthChange,
    this.selected,
    this.legend,
    this.legendIdentifier,
    this.skeletonDelay = SkeletonBlock.defaultDelay,
    this.skeletonAnimated = true,
    super.key,
  }) : assert(weekdayLabels.length == 7, '요일 머리는 일~토 7개입니다.');

  /// 명세 대조용 요약.
  static const ComponentSpec spec = ComponentSpec('calendar-month', {}, {
    'monthChanged',
    'loading',
  });

  /// 이전·다음 터치 영역(`parts.header.prev.target`).
  static const double headerTarget = 44;

  /// 요일 머리 높이(`parts.weekdays.height`).
  static const double weekdaysHeight = 28;

  /// 칸 사이 가로·세로 간격(`parts.grid.rowGap`·`columnGap`).
  static const double gridGap = 2;

  /// 격자 열 수(`parts.grid.columns`).
  static const int columns = 7;

  /// 범례 견본 한 변(`parts.legend.swatch.size`).
  static const double legendSwatchSize = 10;

  /// 이 거리(px)보다 많이 끌면 느리게 밀어도 달이 넘어갑니다.
  static const double swipeDistance = 48;

  /// 이 속도(px/s)보다 빠르게 밀면 짧게 밀어도 달이 넘어갑니다.
  static const double swipeVelocity = 300;

  /// 이전 달 버튼.
  static const Key prevKey = ValueKey('calendar-month-prev');

  /// 다음 달 버튼.
  static const Key nextKey = ValueKey('calendar-month-next');

  /// 요일 머리 줄.
  static const Key weekdaysKey = ValueKey('calendar-month-weekdays');

  /// 주 6줄 격자(스미는 부분).
  static const Key gridKey = ValueKey('calendar-month-grid');

  /// Semantics `grid`(Flutter role `table`) 노드.
  static const Key tableKey = ValueKey('calendar-month-table');

  /// loading 길흉 채우기 자리.
  static const Key fillBoneKey = ValueKey('calendar-month-fill-bone');

  /// loading 도장 자리.
  static const Key sealBoneKey = ValueKey('calendar-month-seal-bone');

  /// 범례 견본.
  static const Key legendSwatchKey = ValueKey('calendar-month-legend-swatch');

  /// [date] 칸을 감싼 자리의 키.
  static Key cellKey(CalendarDate date) =>
      ValueKey('calendar-month-cell-${date.toIso()}');

  /// 보이는 달.
  final CalendarMonth month;

  /// 달 제목("2026년 10월"). 격자의 스크린리더 라벨로도 씁니다.
  final String title;

  /// 요일 머리 글자(일~토).
  final List<String> weekdayLabels;

  /// 날짜마다 칸 값.
  final DayCellData Function(CalendarDate date) cellOf;

  /// 칸 값을 받는 중인지.
  final bool loading;

  /// 오늘(윤곽 도장).
  final CalendarDate today;

  /// 선택된 날. 없으면 null.
  final CalendarDate? selected;

  /// 날짜를 눌렀을 때.
  final ValueChanged<CalendarDate> onSelect;

  /// 이전·다음·밀기로 달을 넘길 때. 범위 안의 달만 넘깁니다.
  final ValueChanged<CalendarMonth> onMonthChange;

  /// 범례. null이면 그리지 않습니다.
  final List<CalendarLegendEntry>? legend;

  /// 범례의 IA 슬롯 id.
  final String? legendIdentifier;

  /// skeleton이 보이기 전 대기. 이보다 빨리 끝나면 skeleton은 나오지 않습니다.
  final Duration skeletonDelay;

  /// false면 skeleton이 숨쉬지 않습니다(golden).
  final bool skeletonAnimated;

  @override
  State<CalendarMonthView> createState() => _CalendarMonthViewState();
}

class _CalendarMonthViewState extends State<CalendarMonthView> {
  Timer? _skeletonTimer;
  bool _skeletonVisible = false;
  double _dragDx = 0;

  @override
  void initState() {
    super.initState();
    if (widget.loading) _startSkeleton();
  }

  @override
  void didUpdateWidget(CalendarMonthView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.loading && !oldWidget.loading) {
      _startSkeleton();
    } else if (!widget.loading) {
      _skeletonTimer?.cancel();
      _skeletonVisible = false;
    }
  }

  @override
  void dispose() {
    _skeletonTimer?.cancel();
    super.dispose();
  }

  void _startSkeleton() {
    _skeletonTimer?.cancel();
    if (widget.skeletonDelay == Duration.zero) {
      _skeletonVisible = true;
      return;
    }
    _skeletonVisible = false;
    _skeletonTimer = Timer(widget.skeletonDelay, () {
      if (mounted && widget.loading) setState(() => _skeletonVisible = true);
    });
  }

  CalendarMonth? get _previous {
    final previous = widget.month.previous();
    return previous.isSupported ? previous : null;
  }

  CalendarMonth? get _next {
    final next = widget.month.next();
    return next.isSupported ? next : null;
  }

  void _go(CalendarMonth? target) {
    if (target != null) widget.onMonthChange(target);
  }

  void _onDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity < -CalendarMonthView.swipeVelocity ||
        _dragDx < -CalendarMonthView.swipeDistance) {
      _go(_next);
    } else if (velocity > CalendarMonthView.swipeVelocity ||
        _dragDx > CalendarMonthView.swipeDistance) {
      _go(_previous);
    }
    _dragDx = 0;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final previous = _previous;
    final next = _next;
    final legend = widget.legend;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(context, l10n, previous, next),
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragStart: (_) => _dragDx = 0,
          onHorizontalDragUpdate: (details) => _dragDx += details.delta.dx,
          onHorizontalDragEnd: _onDragEnd,
          child: Semantics(
            key: CalendarMonthView.tableKey,
            container: true,
            role: SemanticsRole.table,
            label: widget.title,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MediaQuery.withClampedTextScaling(
                  maxScaleFactor: DayCell.textScaleMax,
                  child: _weekdays(context),
                ),
                SeepOnChange(changeKey: widget.month, child: _grid()),
              ],
            ),
          ),
        ),
        if (legend != null) _legend(context, legend),
      ],
    );
  }

  Widget _header(
    BuildContext context,
    AppLocalizations l10n,
    CalendarMonth? previous,
    CalendarMonth? next,
  ) {
    final tokens = context.tokens;
    return Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              widget.title,
              style: tokens.typography.subtitle.copyWith(
                color: tokens.colors.textPrimary,
              ),
            ),
          ),
        ),
        _MonthStepButton(
          key: CalendarMonthView.prevKey,
          icon: _caretLeft,
          semanticLabel: l10n.calendarPrevMonth,
          onPressed: previous == null ? null : () => _go(previous),
        ),
        _MonthStepButton(
          key: CalendarMonthView.nextKey,
          icon: _caretRight,
          semanticLabel: l10n.calendarNextMonth,
          onPressed: next == null ? null : () => _go(next),
        ),
      ],
    );
  }

  Widget _weekdays(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final labels = widget.weekdayLabels;
    return Semantics(
      container: true,
      role: SemanticsRole.row,
      child: ConstrainedBox(
        key: CalendarMonthView.weekdaysKey,
        constraints: const BoxConstraints(
          minHeight: CalendarMonthView.weekdaysHeight,
        ),
        child: _row([
          for (final (index, label) in labels.indexed)
            Semantics(
              container: true,
              role: SemanticsRole.columnHeader,
              child: Center(
                child: Text(
                  label,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  style: tokens.typography.captionMd.copyWith(
                    // 요일 색은 머리에만 둡니다(날짜 숫자는 무색).
                    color: switch (index) {
                      0 => colors.calendarWeekdaySun,
                      6 => colors.calendarWeekdaySat,
                      _ => colors.textSecondary,
                    },
                  ),
                ),
              ),
            ),
        ], crossAxisAlignment: CrossAxisAlignment.center),
      ),
    );
  }

  Widget _grid() {
    final days = widget.month.gridDays;
    final weeks = days.length ~/ CalendarMonthView.columns;
    return Column(
      key: CalendarMonthView.gridKey,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: CalendarMonthView.gridGap,
      children: [
        for (var week = 0; week < weeks; week++)
          Semantics(
            container: true,
            role: SemanticsRole.row,
            child: DayCellGridRow(
              child: _row([
                for (final date
                    in days
                        .skip(week * CalendarMonthView.columns)
                        .take(CalendarMonthView.columns))
                  _cell(date),
              ]),
            ),
          ),
      ],
    );
  }

  /// 7칸을 [CalendarMonthView.gridGap] 간격으로 같은 너비에 나눠 놓습니다.
  Widget _row(
    List<Widget> cells, {
    CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.start,
  }) => Row(
    crossAxisAlignment: crossAxisAlignment,
    spacing: CalendarMonthView.gridGap,
    children: [for (final cell in cells) Expanded(child: cell)],
  );

  Widget _cell(CalendarDate date) {
    final month = widget.month;
    final outside = date.year != month.year || date.month != month.month;
    final dayCell = DayCell(
      data: widget.cellOf(date),
      isToday: date == widget.today,
      isSelected: date == widget.selected,
      outsideMonth: outside,
      onTap: () => widget.onSelect(date),
    );
    final skeleton = widget.loading && _skeletonVisible && !outside;
    return KeyedSubtree(
      key: CalendarMonthView.cellKey(date),
      child: skeleton ? _withSkeleton(dayCell) : dayCell,
    );
  }

  /// 칸 아래에 길흉 채우기 자리(칸 전체)와 도장 자리(숫자 상자 가운데 26px)를 깝니다.
  Widget _withSkeleton(Widget dayCell) {
    const sealSize = SealSize.cell;
    final sealTop =
        DayCell.numberBoxTop + (DayCell.numberBoxSize - sealSize.logical) / 2;
    return Stack(
      children: [
        Positioned.fill(
          child: SkeletonBone(
            key: CalendarMonthView.fillBoneKey,
            height: double.infinity,
            borderRadius: Radii.sm,
            animated: widget.skeletonAnimated,
          ),
        ),
        Positioned(
          top: sealTop,
          left: 0,
          right: 0,
          child: Center(
            child: SizedBox.square(
              key: CalendarMonthView.sealBoneKey,
              dimension: sealSize.logical,
              child: SkeletonBone(
                height: sealSize.logical,
                borderRadius: Radii.xs,
                index: 1,
                animated: widget.skeletonAnimated,
              ),
            ),
          ),
        ),
        dayCell,
      ],
    );
  }

  Widget _legend(BuildContext context, List<CalendarLegendEntry> legend) {
    final tokens = context.tokens;
    final identifier = widget.legendIdentifier;
    final style = tokens.typography.captionMd.copyWith(
      color: tokens.colors.textSecondary,
    );
    return Padding(
      padding: const EdgeInsets.only(top: Space.s12),
      child: Semantics(
        identifier: identifier,
        child: Wrap(
          key: identifier == null ? null : ValueKey<String>(identifier),
          spacing: Space.s12,
          runSpacing: Space.s4,
          children: [
            for (final entry in legend)
              Row(
                mainAxisSize: MainAxisSize.min,
                spacing: Space.s4,
                children: [
                  DecoratedBox(
                    key: CalendarMonthView.legendSwatchKey,
                    decoration: BoxDecoration(
                      color: entry.swatch,
                      borderRadius: const BorderRadius.all(
                        Radius.circular(Radii.xs),
                      ),
                    ),
                    child: const SizedBox.square(
                      dimension: CalendarMonthView.legendSwatchSize,
                    ),
                  ),
                  Text(entry.label, style: style),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// 이전·다음 달 버튼: 44px 터치 영역, Light 아이콘, 눌림은 `press.ink`.
///
/// [onPressed]가 null이면 아이콘을 `disabled.fg`로 흐리게 하고 누를 수 없습니다.
class _MonthStepButton extends StatefulWidget {
  const new({
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
    super.key,
  });

  final AppGlyph icon;
  final String semanticLabel;
  final VoidCallback? onPressed;

  @override
  State<_MonthStepButton> createState() => _MonthStepButtonState();
}

class _MonthStepButtonState extends State<_MonthStepButton>
    with TickerProviderStateMixin {
  late final AnimationController _press = AnimationController(
    vsync: this,
    duration: InteractionPattern.pressInk.duration,
  );
  late final AnimationController _release = AnimationController(
    vsync: this,
    duration: pressInkReleaseDuration,
  )..addStatusListener(_onReleased);

  Alignment _origin = Alignment.center;

  void _onReleased(AnimationStatus status) {
    if (status == AnimationStatus.completed) _press.value = 0;
  }

  @override
  void dispose() {
    _press.dispose();
    _release.dispose();
    super.dispose();
  }

  void _down(TapDownDetails details) {
    const target = CalendarMonthView.headerTarget;
    _origin = Alignment(
      details.localPosition.dx / target * 2 - 1,
      details.localPosition.dy / target * 2 - 1,
    );
    _release.value = 0;
    _press.forward(from: 0);
  }

  void _up() => _release.forward(from: 0);

  @override
  Widget build(BuildContext context) {
    final colors = context.tokens.colors;
    final onPressed = widget.onPressed;
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticLabel,
      onTap: onPressed,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: enabled ? _down : null,
          onTapUp: enabled
              ? (_) {
                  _up();
                  onPressed();
                }
              : null,
          onTapCancel: enabled ? _up : null,
          child: SizedBox.square(
            dimension: CalendarMonthView.headerTarget,
            child: animate(
              InteractionPattern.pressInk,
              t: _press,
              prefs: MotionPrefs.of(context),
              options: PatternOptions(
                origin: _origin,
                release: _release,
                inkColor: colors.textPrimary,
                borderRadius: BorderRadius.circular(
                  CalendarMonthView.headerTarget / 2,
                ),
              ),
              child: Center(
                child: AppIcon(
                  widget.icon,
                  color: enabled ? colors.textPrimary : colors.disabledFg,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
