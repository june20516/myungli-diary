import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:myungli_diary/app/router/app_router.dart';
import 'package:myungli_diary/app/router/screen_breadcrumbs.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/gen/model/calendar.dart';
import 'package:myungli_diary/core/api/gen/model/calendar_day.dart';
import 'package:myungli_diary/core/api/gen/model/luck_level.dart';
import 'package:myungli_diary/core/api/gen/model/schedule.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:myungli_diary/core/clock/clock.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/core/platform/crash_reporter.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';
import 'package:myungli_diary/design/components/calendar/calendar_month.dart';
import 'package:myungli_diary/design/components/calendar/day_cell.dart';
import 'package:myungli_diary/design/components/feedback/error_state.dart';
import 'package:myungli_diary/design/components/feedback/notice_banner.dart';
import 'package:myungli_diary/design/components/frame/app_bar.dart';
import 'package:myungli_diary/design/elements/app_icon.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';
import 'package:myungli_diary/features/calendar/application/calendar_providers.dart';
import 'package:myungli_diary/features/calendar/application/day_sheets.dart';
import 'package:myungli_diary/features/calendar/model/calendar_month_view.dart';
import 'package:myungli_diary/features/diary/application/diary_providers.dart';
import 'package:myungli_diary/features/glossary/application/glossary_providers.dart';
import 'package:myungli_diary/features/glossary/model/glossary_names.dart';
import 'package:myungli_diary/features/schedule/application/schedule_providers.dart';
import 'package:myungli_diary/features/schedule/model/schedule_range.dart';
import 'package:phosphor_glyphs/phosphor_glyphs.dart';

/// IA `calendar`가 직접 처리하는 상태.
const Set<String> calendarHandledStates = {'loading', 'error', 'offline'};

/// IA `calendar`의 출구 대상: 날짜 누름 → `day-sheet`, 일정 추가 → `event-edit`.
const Set<String> calendarExits = {ScreenIds.daySheet, ScreenIds.eventEdit};

const AppGlyph _plus = AppGlyph(
  light: PhosphorIconsLight.plus,
  regular: PhosphorIconsRegular.plus,
);

/// 달력(탭 루트): 한 달 격자에 길흉·음력·절기·일기 도장·일정 점을 보이고, 날짜를 누르면
/// 그날 시트를 엽니다.
///
/// * 처음에는 오늘이 든 달을 보이고 오늘을 고릅니다. 사용자가 달을 넘기거나 날을 고르기
///   전까지는 "오늘"을 따라가므로, 화면을 연 채 자정을 넘기면 선택과 달도 함께 옮겨 갑니다.
/// * 달 길흉은 달마다 따로 받고([calendarMonthProvider]), 보이는 달의 앞뒤 달을 미리
///   받습니다([calendarPrefetchProvider]). 늦게 온 다른 달 응답은 보이는 달을 바꾸지 않습니다.
/// * 받는 중에는 격자의 길흉·도장 자리만 skeleton이고(`loading`), 받지 못하면 격자 위에
///   오류와 다시 시도를 보입니다(`error`). 작은 화면에서도 먼저 보이고, 아래 격자의 달
///   넘김은 그대로 쓸 수 있습니다. 지원 범위 밖(422 `date.out_of_range`)이면 다시 시도
///   없이 범위 안내입니다(A44).
/// * 값을 들고 다시 받는 중(잠금 해제 뒤 등)에는 값을 그대로 보여 skeleton이 깜빡이지
///   않습니다. 보이는 달의 요청이 연결 오류로 실패하면 받아 둔 달 위에 오프라인 배너를
///   보입니다(`offline`). 받은 적 없는 달은 오프라인 오류입니다.
/// * 일정·일기는 지원 날짜로 자른 격자 범위로 묻습니다(1900-02·2099-12 격자의 범위 밖
///   날짜를 보내지 않음, D41). 달력은 1900-02부터 넘깁니다(A44). 일정 범위는 오류여도
///   붙들려 남으므로, 화면에 들어올 때(다른 탭에서 돌아올 때 포함)·달을 넘길 때·다시 시도할
///   때 오류로 남은 범위를 다시 받습니다(연결이 돌아오면 배너가 걷힘).
class CalendarScreen extends ConsumerStatefulWidget {
  /// calendar 화면을 만듭니다.
  const new({super.key});

  /// 앱 바의 일정 추가 동작.
  static const Key eventAddKey = ValueKey('calendar.event-add');

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  /// 사용자가 넘긴 달. null이면 오늘이 든 달입니다.
  CalendarMonth? _month;

  /// 사용자가 고른 날. null이면 오늘입니다.
  CalendarDate? _picked;

  /// [month] 격자의 일정 범위. 지원 날짜 밖은 자릅니다(D41).
  static ScheduleRange _rangeOf(CalendarMonth month) =>
      (from: month.supportedGridStart, to: month.supportedGridEnd);

  /// 탭 복귀 듣기를 끝냅니다.
  late final void Function() _stopEntries;

  @override
  void initState() {
    super.initState();
    // 이전에 연결 오류로 남은 범위가 있으면 화면에 들어올 때 다시 받습니다. 첫 build 전에
    // provider를 바꾸지 않도록 프레임 뒤에 합니다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refetchFailedSchedules(_visibleMonth);
    });
    // 탭 셸은 화면 상태를 들고 있으므로, 다른 탭·화면에서 돌아오는 것도 진입으로 봅니다.
    _stopEntries = listenScreenEntered(
      ref.read(routerProvider),
      ScreenIds.calendar,
      () {
        if (mounted) _refetchFailedSchedules(_visibleMonth);
      },
    );
  }

  @override
  void dispose() {
    _stopEntries();
    super.dispose();
  }

  CalendarMonth get _visibleMonth =>
      _month ?? CalendarMonth.of(ref.read(todayProvider));

  /// [month] 격자의 일정 범위가 오류로 남아 있으면 다시 받게 합니다.
  ///
  /// 여러 날 범위는 오류여도 붙들려(keepAlive) 있어서, 그대로 두면 연결이 돌아와도 오류와
  /// 오프라인 배너가 남고 점이 없습니다.
  void _refetchFailedSchedules(CalendarMonth month) {
    final provider = schedulesInRangeProvider(_rangeOf(month));
    if (!ref.exists(provider)) {
      return;
    }
    final schedules = ref.read(provider);
    if (schedules.hasError && !schedules.isLoading) {
      ref.invalidate(provider);
    }
  }

  /// 날을 고르면 그 날이 든 달도 고정합니다. 오늘을 따라가는 달에 남겨 두면 달 경계 자정에
  /// 고른 날이 보이지 않는 달로 넘어갑니다.
  void _select(CalendarDate date) {
    setState(() {
      _picked = date;
      _month ??= CalendarMonth.of(ref.read(todayProvider));
    });
    unawaited(ref.read(daySheetsProvider).open(context, date));
  }

  void _changeMonth(CalendarMonth month) {
    _refetchFailedSchedules(month);
    setState(() => _month = month);
  }

  /// 달 오류의 다시 시도: 달과 함께, 같은 연결 오류로 비었을 일정·일기도 다시 받습니다.
  void _retry(CalendarMonth month) {
    ref
      ..invalidate(calendarMonthProvider(month))
      ..invalidate(diaryDatesProvider(month));
    _refetchFailedSchedules(month);
  }

  /// 고른 날(없으면 오늘)의 새 일정 화면으로 갑니다.
  void _addEvent(CalendarDate selected) {
    unawaited(context.push<void>(datedPathOf(ScreenIds.eventEdit, selected)));
  }

  /// 예상하지 못한 달 오류(분류되지 않은 오류)는 사용자 눈에 일반 오류뿐이라 요약을 남깁니다.
  void _reportUnexpected(
    AsyncValue<Calendar>? previous,
    AsyncValue<Calendar> next,
  ) {
    final error = next.error;
    if (error == null ||
        error is AppError ||
        identical(error, previous?.error)) {
      return;
    }
    ref
        .read(crashReporterProvider)
        .record(
          CrashSummary.from(UnexpectedError(error)),
          next.stackTrace ?? StackTrace.current,
        );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final today = ref.watch(todayProvider);
    final month = _month ?? CalendarMonth.of(today);
    final selected = _picked ?? today;

    final monthProvider = calendarMonthProvider(month);
    final calendar = ref.watch(monthProvider);
    ref
      ..listen(monthProvider, _reportUnexpected)
      // 구독하는 동안 앞뒤 달을 받아 둡니다.
      ..watch(calendarPrefetchProvider(month));
    final schedules = ref.watch(schedulesInRangeProvider(_rangeOf(month)));
    final diaryDates =
        ref.watch(diaryDatesProvider(month)).value ?? const <CalendarDate>{};
    final names = ref.watch(glossaryProvider).value;

    // 값이 있으면 다시 받는 중이어도 값을 그대로 보입니다(skeleton 깜빡임 없음).
    final loading = !calendar.hasValue && calendar.isLoading;
    final failure = calendar.hasValue || loading ? null : calendar.error;
    // 값이 있는 달의 다시 받기가 연결 오류가 아닌 오류(5xx 등)로 실패하면 옛 값을 그대로
    // 보이고 따로 알리지 않습니다. 값은 여전히 그 달의 길흉이고, 고칠 수 있는 동작이 없기
    // 때문입니다(ScreenStateView의 기본 동작과 같음).
    final offline =
        calendar.hasValue &&
        (calendar.error is OfflineError || schedules.error is OfflineError);

    final cells = _CellBuilder(
      l10n: l10n,
      locale: Localizations.localeOf(context).toString(),
      names: names,
      today: today,
      days: calendar.value?.days ?? const [],
      diaryDates: diaryDates,
      // 다시 받는 동안에는 들고 있던 값을 그대로 씁니다(로그아웃 뒤는 버린 빈 목록이라 점 없음).
      schedules: schedules.value ?? const [],
    );

    return Semantics(
      identifier: ScreenIds.calendar,
      child: Scaffold(
        key: const ValueKey(ScreenIds.calendar),
        body: SafeArea(
          // 아래는 탭 틀 뒤로 내용이 흐르도록 스크롤 여백으로 비웁니다.
          bottom: false,
          child: Column(
            children: [
              MyungliAppBar.tabRoot(
                title: l10n.calendarBarTitle,
                titleIdentifier: SlotIds.calendarBarTitle,
                actions: [
                  AppBarAction(
                    key: CalendarScreen.eventAddKey,
                    icon: _plus,
                    semanticLabel: l10n.daySheetEventAdd,
                    onPressed: () => _addEvent(selected),
                  ),
                ],
              ),
              Expanded(
                child: _CalendarBody(
                  month: month,
                  today: today,
                  selected: selected,
                  loading: loading,
                  failure: failure,
                  offline: offline,
                  cellOf: cells.cellOf,
                  onSelect: _select,
                  onMonthChange: _changeMonth,
                  onRetry: () => _retry(month),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 달 격자와 그 위아래(오프라인 배너, 오류). 컴포넌트를 배치만 합니다.
class _CalendarBody extends StatelessWidget {
  const new({
    required this.month,
    required this.today,
    required this.selected,
    required this.loading,
    required this.failure,
    required this.offline,
    required this.cellOf,
    required this.onSelect,
    required this.onMonthChange,
    required this.onRetry,
  });

  final CalendarMonth month;
  final CalendarDate today;
  final CalendarDate selected;
  final bool loading;

  /// 값 없이 실패한 오류. null이면 오류가 아닙니다.
  final Object? failure;
  final bool offline;
  final DayCellData Function(CalendarDate date) cellOf;
  final ValueChanged<CalendarDate> onSelect;
  final ValueChanged<CalendarMonth> onMonthChange;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.tokens.colors;
    final locale = Localizations.localeOf(context).toString();
    final failure = this.failure;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        Space.s20,
        Space.s8,
        Space.s20,
        bottomInset + Space.s32,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          NoticeBanner(
            variant: NoticeBannerVariant.offline,
            message: l10n.noticeOffline,
            present: offline,
          ),
          // 오류는 격자 위에 둬 작은 화면에서도 스크롤 없이 보이게 합니다.
          if (failure != null) ...[
            ErrorState(
              error: failure is AppError ? failure : UnexpectedError(failure),
              // 범위 밖 달은 다시 받아도 같은 답이라 다시 시도를 두지 않습니다(A44).
              onRetry: isCalendarOutOfRange(failure) ? null : onRetry,
            ),
            const SizedBox(height: Space.s24),
          ],
          CalendarMonthView(
            month: month,
            title: calendarMonthTitle(locale, month),
            weekdayLabels: calendarWeekdayLabels(locale),
            cellOf: cellOf,
            loading: loading,
            today: today,
            selected: selected,
            onSelect: onSelect,
            onMonthChange: onMonthChange,
            // 오류일 때는 칠한 칸이 없으므로 범례를 두지 않습니다.
            legend: failure == null
                ? [
                    (
                      swatch: colors.calendarGoodBg,
                      label: l10n.calendarLegendBodyGood,
                    ),
                    (
                      swatch: colors.calendarCautionBg,
                      label: l10n.calendarLegendBodyCaution,
                    ),
                  ]
                : null,
            legendIdentifier: SlotIds.calendarLegendBody,
          ),
        ],
      ),
    );
  }
}

/// 격자 날짜마다 칸 값([DayCellData])을 만듭니다.
///
/// 이 달의 길흉 응답이 있는 날은 [dayCellDataOf]로 음력·절기·길흉 낱말을 채우고, 없는 날
/// (받는 중, 오류, 격자의 앞뒤 달 날짜)은 날짜·일기·일정·오늘만 담습니다.
final class _CellBuilder {
  new({
    required this.l10n,
    required this.locale,
    required this.names,
    required this.today,
    required List<CalendarDay> days,
    required this.diaryDates,
    required List<Schedule> schedules,
  }) : _days = {for (final day in days) day.date: day},
       _eventCounts = _countByDate(schedules);

  final AppLocalizations l10n;
  final String locale;
  final GlossaryNames? names;
  final CalendarDate today;
  final Set<CalendarDate> diaryDates;

  /// ISO 날짜 → 그날 길흉.
  final Map<String, CalendarDay> _days;

  /// ISO 날짜 → 그날 일정 수.
  final Map<String, int> _eventCounts;

  static Map<String, int> _countByDate(List<Schedule> schedules) {
    final counts = <String, int>{};
    for (final schedule in schedules) {
      counts.update(schedule.date, (count) => count + 1, ifAbsent: () => 1);
    }
    return counts;
  }

  DayCellData cellOf(CalendarDate date) {
    final iso = date.toIso();
    final diaryWritten = diaryDates.contains(date);
    final eventCount = _eventCounts[iso] ?? 0;
    final isToday = date == today;
    final day = _days[iso];
    if (day == null) {
      return DayCellData(
        date: date,
        semanticLabel: _plainLabel(
          date,
          diaryWritten: diaryWritten,
          eventCount: eventCount,
          isToday: isToday,
        ),
        diaryWritten: diaryWritten,
        eventCount: eventCount,
      );
    }
    final view = dayCellDataOf(
      day,
      l10n: l10n,
      locale: locale,
      names: names,
      diaryWritten: diaryWritten,
      eventCount: eventCount,
      isToday: isToday,
    );
    return DayCellData(
      date: date,
      semanticLabel: view.semanticLabel,
      luck: switch (view.luck) {
        LuckLevel.good => DayLuck.good,
        LuckLevel.neutral => DayLuck.neutral,
        LuckLevel.caution => DayLuck.caution,
      },
      lunarText: view.lunarText,
      lunarBold: view.lunarBold,
      diaryWritten: diaryWritten,
      eventCount: eventCount,
    );
  }

  /// 길흉 응답이 없는 날의 라벨: 날짜 요일, 일기 있음, 일정 N개, 오늘(있는 것만).
  String _plainLabel(
    CalendarDate date, {
    required bool diaryWritten,
    required int eventCount,
    required bool isToday,
  }) => [
    DateFormat.MMMMEEEEd(locale)
        .format(DateTime(date.year, date.month, date.day)),
    if (diaryWritten) l10n.dayCellDiaryWritten,
    if (eventCount > 0) l10n.dayCellEventCount(eventCount),
    if (isToday) l10n.dayCellToday,
  ].join(l10n.a11yListSeparator);
}
