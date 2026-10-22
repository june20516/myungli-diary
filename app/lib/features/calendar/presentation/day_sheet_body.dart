import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:myungli_diary/app/router/app_router.dart';
import 'package:myungli_diary/app/router/diary_entry_data.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/gen/model/calendar_day.dart';
import 'package:myungli_diary/core/api/gen/model/schedule.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:myungli_diary/core/clock/clock.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/day_kind_names.dart';
import 'package:myungli_diary/core/l10n/error_messages.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/action/primary_button.dart';
import 'package:myungli_diary/design/components/calendar/event_row.dart';
import 'package:myungli_diary/design/components/diary/diary_row.dart';
import 'package:myungli_diary/design/components/feedback/screen_state_view.dart';
import 'package:myungli_diary/design/components/frame/sheet.dart';
import 'package:myungli_diary/design/components/sentence/sentence_block.dart';
import 'package:myungli_diary/design/components/today/day_character.dart';
import 'package:myungli_diary/design/components/today/day_reading_skeleton.dart';
import 'package:myungli_diary/design/elements/skeleton_bone.dart';
import 'package:myungli_diary/design/text/line_height.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';
import 'package:myungli_diary/features/calendar/application/calendar_providers.dart';
import 'package:myungli_diary/features/depth/application/depth_sheets.dart';
import 'package:myungli_diary/features/diary/application/diary_providers.dart';
import 'package:myungli_diary/features/diary/model/diary_write_entry.dart';
import 'package:myungli_diary/features/schedule/application/schedule_providers.dart';

/// 그날 시트(`day-sheet`) 본문: 날의 성격 한 줄, 그날 일정, 그날 일기 줄과 쓰기 입구.
///
/// * 날의 성격은 달 길흉의 그 날([calendarDayProvider])입니다(getDaily를 부르지 않음).
///   기다리는 동안 skeleton(`loading`), 받지 못하면 오류 화면과 다시 시도(`error`)입니다.
///   지원 범위 밖 달이면 다시 시도 없는 범위 안내입니다(A44).
/// * 일정은 [schedulesOnDateProvider]의 하루 일정(하루 종일 먼저, 시각순)입니다. 없으면
///   빈 문장과 일정 추가(`empty`), 받지 못하면 빈 문장 대신 조용한 오류 한 줄과 다시 시도,
///   일정 추가를 둡니다(없다고 말하지 않게).
/// * 일기 입구는 오늘·지난 날만이고(D49) 그날 쓴 일기 줄과 새 일기 쓰기입니다(A69). 미래 날은
///   묻지도 그리지도 않습니다.
/// * 이유 문장의 용어는 칩이고(V28) 풀이 시트를 위로 쌓습니다. day-sheet의 깊이는
///   `surface`·`explain`까지라 그 풀이 시트에는 근거 보기가 없습니다. 시트에는 광고 배너가
///   없습니다(D53).
class DaySheetBody extends ConsumerWidget {
  /// [date]의 그날 시트 본문을 만듭니다.
  const new({required this.date, super.key});

  /// 그 날(양력).
  final CalendarDate date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final day = ref.watch(calendarDayProvider(date));
    return ScreenStateView<CalendarDay>(
      value: day,
      // 범위 밖 달(1900-01-31이 든 1900-01 등)은 다시 받아도 같은 답이라 범위 안내만 둡니다(A44).
      onRetry: isCalendarOutOfRange(day.error)
          ? null
          : () {
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
                .openExplain(context, termId: termId),
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
    void add() => _push(context, datedPathOf(ScreenIds.eventEdit, date));
    final addButton = PrimaryButton(
      label: l10n.daySheetEventAdd,
      onPressed: add,
      variant: PrimaryButtonVariant.quiet,
      identifier: SlotIds.daySheetEventAdd,
    );
    // 다시 받는 중에는 들고 있던 목록을 그대로 보입니다(깜빡이지 않게). 로그아웃 뒤 다시 받는
    // 동안은 하루 목록이 값 없는 loading이라 이전 계정 일정도, 잠깐의 "일정 없음"도 없습니다.
    if (schedules.isLoading && !schedules.hasValue) {
      return const _ScheduleSkeleton();
    }
    final list = schedules.value;
    if (list == null) {
      final cause = schedules.error;
      return EventRowListFailed(
        message: errorMessage(
          l10n,
          cause is AppError ? cause : UnexpectedError(cause ?? 'unknown'),
        ),
        retryLabel: l10n.actionRetry,
        // 값 없이 실패한 격자는 고르지 않으므로, 실패는 그 날 하루 범위입니다.
        onRetry: () =>
            ref.invalidate(schedulesInRangeProvider((from: date, to: date))),
        addLabel: l10n.daySheetEventAdd,
        onAdd: add,
        addIdentifier: SlotIds.daySheetEventAdd,
      );
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

/// 일기 입구(오늘·지난 날, D49): 그날 쓴 일기가 있으면 머리(편수, 동작 아님)와 작성 순
/// `diary-row` `entries`, 그 아래 새 일기 쓰기 `primary-button` `filled`(V37)입니다(A69).
///
/// 쓰기 버튼은 그날 편수로 처음 쓰기·한 편 더 쓰기·다 채움(누를 수 없음)입니다(D83 ②). 그날
/// 일기를 받는 동안은 입구 자리에 skeleton이고, 받지 못하면 0편으로 그려 쓰기를 막지 않습니다.
class _DiaryEntry extends ConsumerWidget {
  const new({required this.date});

  static const Key entryKey = ValueKey('day-sheet.diary.entry');

  final CalendarDate date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final diaries = ref.watch(diariesOnProvider(date)).value;
    if (diaries == null) {
      return const _EntrySkeleton();
    }
    final entry = diaryWriteEntryOf(diaries.length);
    return Column(
      key: entryKey,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 머리(편수, 동작 아님)와 작성 순 줄. 0편이면 아무것도 그리지 않습니다.
        DiaryEntries(
          surface: DiaryEntriesSurface.plain,
          head: diaries.isEmpty ? null : l10n.daySheetDiaryOpen(diaries.length),
          headIdentifier: SlotIds.daySheetDiaryOpen,
          entries: diaryEntriesDataOf(context, diaries),
        ),
        Padding(
          padding: const EdgeInsets.only(top: Space.s12),
          child: PrimaryButton(
            label: switch (entry) {
              DiaryWriteEntry.first => l10n.daySheetDiaryWriteCta,
              DiaryWriteEntry.more => l10n.daySheetDiaryWriteCtaWritten,
              DiaryWriteEntry.full => l10n.daySheetDiaryWriteCtaFull,
            },
            // 그날 일기를 다 채웠으면 누를 수 없습니다(D83 ②).
            onPressed: entry == DiaryWriteEntry.full
                ? null
                : () => unawaited(_writeDiary(context, ref)),
            identifier: SlotIds.daySheetDiaryWriteCta,
          ),
        ),
      ],
    );
  }

  /// 그날 새 일기를 쓰러 갑니다(A67). 돌아오면 그날 일기 목록과 달력 도장을 다시 묻습니다.
  Future<void> _writeDiary(BuildContext context, WidgetRef ref) async {
    await _push(context, datedPathOf(ScreenIds.diaryEdit, date));
    if (!context.mounted) {
      return;
    }
    // 저장하면 쓰기 화면이 이미 다시 묻게 합니다. 저장 없이 돌아온 경우(취소·초안만 남김)나
    // 그 사이 다른 기기에서 바뀐 경우를 위해 돌아올 때 한 번 더 묻습니다.
    ref
      ..invalidate(diariesOnProvider(date))
      ..invalidate(diaryDatesProvider);
  }
}

/// [location]으로 화면을 쌓습니다. 시트는 그 아래에 남아, 돌아오면 그대로 보입니다.
Future<void> _push(BuildContext context, String location, {Object? extra}) =>
    context.push<void>(location, extra: extra);

/// [style] 글줄 하나의 높이(기기 글자 크기 반영)와 그 안의 뼈 높이(글자 몸통, 0.6).
({double line, double bone}) _lineMetrics(
  BuildContext context,
  TextStyle style,
) {
  final line = lineHeightOf(style, MediaQuery.textScalerOf(context));
  return (line: line, bone: line * 0.6);
}

/// 일기 입구를 받는 동안의 자리: 쓰기 버튼(`primary-button` `filled`) 크기의 뼈. 0편(가장 흔한
/// 답)일 때 시트 높이가 그대로입니다.
class _EntrySkeleton extends StatelessWidget {
  const new();

  static const Key skeletonKey = ValueKey('day-sheet.diary.skeleton');

  @override
  Widget build(BuildContext context) => Padding(
    key: skeletonKey,
    padding: const EdgeInsets.only(top: Space.s12),
    child: SkeletonBone(
      height: PrimaryButtonVariant.filled.height,
      borderRadius: Radii.md,
    ),
  );
}

/// 일정 두 줄(`event-row` `list` 최소 높이) 자리.
class _ScheduleSkeleton extends StatelessWidget {
  const new({this.firstIndex = 0});

  /// 첫 뼈의 숨쉬기 순서. 시트 skeleton 안에서는 앞 뼈들 다음 순서입니다.
  final int firstIndex;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: Space.s8,
      children: [
        for (var i = 0; i < 2; i++)
          SkeletonBone(
            height: EventRow.minHeight,
            borderRadius: Radii.xs,
            index: firstIndex + i,
          ),
      ],
    );
  }
}

/// 날의 성격 배지·이유 두 줄·일정 두 줄 자리의 skeleton. 크기는 실제 요소(배지·문장 글줄·
/// 일정 줄)에서 가져옵니다.
class _DaySheetSkeleton extends StatelessWidget {
  const new();

  /// 이유 문장 마지막 줄의 너비 비율.
  static const double _lastLineFactor = 0.6;

  @override
  Widget build(BuildContext context) {
    final metrics = _lineMetrics(
      context,
      context.tokens.typography.sentenceBody,
    );
    final gap = metrics.line - metrics.bone;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SkeletonBone(
          width: DayReadingSkeleton.badgeWidth,
          height: DayCharacterBadge.minHeight,
          borderRadius: Radii.full,
        ),
        const SizedBox(height: Space.s12),
        SkeletonBone(height: metrics.bone, borderRadius: Radii.xs, index: 1),
        SizedBox(height: gap),
        FractionallySizedBox(
          widthFactor: _lastLineFactor,
          child: SkeletonBone(
            height: metrics.bone,
            borderRadius: Radii.xs,
            index: 2,
          ),
        ),
        SizedBox(height: Space.s24 - gap),
        const _ScheduleSkeleton(firstIndex: 3),
      ],
    );
  }
}
