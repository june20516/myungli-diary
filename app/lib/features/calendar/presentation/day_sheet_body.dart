import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:myungli_diary/app/router/app_router.dart';
import 'package:myungli_diary/core/api/gen/model/calendar_day.dart';
import 'package:myungli_diary/core/api/gen/model/schedule.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:myungli_diary/core/clock/clock.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/day_kind_names.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/action/primary_button.dart';
import 'package:myungli_diary/design/components/calendar/event_row.dart';
import 'package:myungli_diary/design/components/feedback/screen_state_view.dart';
import 'package:myungli_diary/design/components/feedback/skeleton.dart';
import 'package:myungli_diary/design/components/frame/sheet.dart';
import 'package:myungli_diary/design/components/sentence/depth_link.dart';
import 'package:myungli_diary/design/components/sentence/sentence_block.dart';
import 'package:myungli_diary/design/components/today/day_character.dart';
import 'package:myungli_diary/design/elements/skeleton_bone.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';
import 'package:myungli_diary/features/calendar/application/calendar_providers.dart';
import 'package:myungli_diary/features/depth/application/depth_sheets.dart';
import 'package:myungli_diary/features/diary/application/diary_providers.dart';
import 'package:myungli_diary/features/schedule/application/schedule_providers.dart';

/// 그날 시트(`day-sheet`) 본문: 날의 성격 한 줄, 그날 일정, 일기 입구.
///
/// * 날의 성격은 달 길흉의 그 날([calendarDayProvider])입니다(getDaily를 부르지 않음).
///   기다리는 동안 skeleton(`loading`), 받지 못하면 오류 화면과 다시 시도(`error`)입니다.
/// * 일정은 [schedulesOnDateProvider]의 하루 일정(하루 종일 먼저, 시각순)입니다. 없으면
///   빈 문장과 일정 추가(`empty`), 받지 못하면 빈 문장 없이 일정 추가만 둡니다(없다고 말하지
///   않게).
/// * 일기 입구는 오늘·지난 날만이고(D49) 일기가 있으면 보기, 없으면 쓰기입니다. 미래 날은
///   묻지도 그리지도 않습니다.
/// * 이유 문장의 용어는 칩이고(V28) 풀이 시트를 위로 쌓습니다. 시트에는 광고 배너가
///   없습니다(D53).
class DaySheetBody extends ConsumerWidget {
  /// [date]의 그날 시트 본문을 만듭니다.
  const new({required this.date, super.key});

  /// 그 날(양력).
  final CalendarDate date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ScreenStateView<CalendarDay>(
      value: ref.watch(calendarDayProvider(date)),
      onRetry: () {
        ref
          ..invalidate(calendarMonthProvider(CalendarMonth.of(date)))
          ..invalidate(calendarDayProvider(date));
      },
      skeleton: const _DaySheetSkeleton(),
      dataWithNotice: (day, notice) =>
          _DaySheetContent(date: date, day: day, notice: notice),
    );
  }
}

/// 날의 성격을 받은 뒤의 본문.
class _DaySheetContent extends ConsumerWidget {
  const new({required this.date, required this.day, required this.notice});

  final CalendarDate date;
  final CalendarDay day;
  final Widget notice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final reason = day.characterReason;
    final today = ref.watch(todayProvider);
    // 일기 입구는 오늘·지난 날만입니다(D49).
    final diaryAllowed = date.compareTo(today) <= 0;
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          notice,
          SheetHeading(
            child: Semantics(
              identifier: SlotIds.daySheetCharacterLabel,
              container: true,
              child: KeyedSubtree(
                key: const ValueKey(SlotIds.daySheetCharacterLabel),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: DayCharacter(
                    variant: dayCharacterVariantOf(day.dayKind),
                    label: dayKindName(l10n, day.dayKind),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: Space.s12),
          SentenceBlock(
            variant: SentenceBlockVariant.body,
            text: reason.text,
            slotId: SlotIds.daySheetCharacterReason,
            onTerm: (termId) => ref
                .read(depthSheetsProvider)
                .openExplain(
                  context,
                  termId: termId,
                  sourceSlotId: reason.slot,
                ),
          ),
          const SizedBox(height: Space.s24),
          _ScheduleSection(date: date),
          if (diaryAllowed) _DiaryEntry(date: date),
        ],
      ),
    );
  }
}

/// 그날 일정 목록 자리.
class _ScheduleSection extends ConsumerWidget {
  const new({required this.date});

  final CalendarDate date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final schedules = ref.watch(schedulesOnDateProvider(date));
    void add() => _push(
      context,
      Uri(
        path: pathOf(ScreenIds.eventEdit),
        queryParameters: {'date': date.toIso()},
      ).toString(),
    );
    final addButton = PrimaryButton(
      label: l10n.daySheetEventAdd,
      onPressed: add,
      variant: PrimaryButtonVariant.quiet,
      identifier: SlotIds.daySheetEventAdd,
    );
    // 로그아웃 뒤에는 loading이면서 빈 목록을 들고 있으므로 isLoading을 값보다 먼저 봅니다.
    if (schedules.isLoading) {
      return const SkeletonBlock(lines: 2);
    }
    final list = schedules.value;
    if (list == null) {
      // 받지 못함: 일정이 없다고 말하지 않고 추가만 둡니다.
      return addButton;
    }
    if (list.isEmpty) {
      return EventRowListEmpty(
        message: l10n.daySheetEventEmpty,
        addLabel: l10n.daySheetEventAdd,
        onAdd: add,
        messageIdentifier: SlotIds.daySheetEventEmpty,
        addIdentifier: SlotIds.daySheetEventAdd,
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, schedule) in list.indexed)
          EventRow.list(
            time: schedule.allDay ? null : schedule.time,
            title: schedule.title,
            showDivider: index < list.length - 1,
            onTap: () => _openSchedule(context, schedule),
          ),
        const SizedBox(height: Space.s4),
        addButton,
      ],
    );
  }

  void _openSchedule(BuildContext context, Schedule schedule) =>
      _push(context, pathOf(ScreenIds.eventEdit), extra: schedule);
}

/// 일기 입구(오늘·지난 날). 일기 여부를 아는 동안에는 자리를 비웁니다.
class _DiaryEntry extends ConsumerWidget {
  const new({required this.date});

  final CalendarDate date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final written = ref.watch(diaryExistsOnProvider(date)).value;
    if (written == null) {
      return const SizedBox.shrink();
    }
    return DepthLink(
      variant: DepthLinkVariant.navigate,
      label: written ? l10n.daySheetDiaryOpen : l10n.daySheetDiaryWriteCta,
      slotId: written
          ? SlotIds.daySheetDiaryOpen
          : SlotIds.daySheetDiaryWriteCta,
      onTap: () => _openDiary(context, ref, written: written),
    );
  }

  /// 일기 보기·쓰기로 갑니다. 돌아오면 일기 여부와 달력 도장을 다시 묻습니다.
  Future<void> _openDiary(
    BuildContext context,
    WidgetRef ref, {
    required bool written,
  }) async {
    final target = written ? ScreenIds.diaryView : ScreenIds.diaryEdit;
    await _push(
      context,
      Uri(
        path: pathOf(target),
        queryParameters: {'date': date.toIso()},
      ).toString(),
    );
    if (!context.mounted) {
      return;
    }
    ref
      ..invalidate(diaryExistsOnProvider(date))
      ..invalidate(diaryDatesProvider);
    if (date == ref.read(todayProvider)) {
      ref.invalidate(todayDiaryExistsProvider);
    }
  }
}

/// [location]으로 화면을 쌓습니다. 시트는 그 아래에 남아, 돌아오면 그대로 보입니다.
Future<void> _push(BuildContext context, String location, {Object? extra}) =>
    context.push<void>(location, extra: extra);

/// 날의 성격 배지·이유 두 줄·일정 두 줄 자리의 skeleton.
class _DaySheetSkeleton extends StatelessWidget {
  const new();

  static const double _badgeWidth = 64;
  static const double _badgeHeight = 26;
  static const double _lineHeight = 14;
  static const double _rowHeight = 48;

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SkeletonBone(
          width: _badgeWidth,
          height: _badgeHeight,
          borderRadius: Radii.full,
        ),
        SizedBox(height: Space.s16),
        SkeletonBone(height: _lineHeight, borderRadius: Radii.xs, index: 1),
        SizedBox(height: Space.s8),
        FractionallySizedBox(
          widthFactor: 0.6,
          child: SkeletonBone(
            height: _lineHeight,
            borderRadius: Radii.xs,
            index: 2,
          ),
        ),
        SizedBox(height: Space.s24),
        SkeletonBone(height: _rowHeight, borderRadius: Radii.xs, index: 3),
        SizedBox(height: Space.s8),
        SkeletonBone(height: _rowHeight, borderRadius: Radii.xs, index: 4),
      ],
    );
  }
}
