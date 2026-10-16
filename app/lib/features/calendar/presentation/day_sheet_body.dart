import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:myungli_diary/app/router/app_router.dart';
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
import 'package:myungli_diary/design/components/feedback/screen_state_view.dart';
import 'package:myungli_diary/design/components/frame/sheet.dart';
import 'package:myungli_diary/design/components/sentence/depth_link.dart';
import 'package:myungli_diary/design/components/sentence/sentence_block.dart';
import 'package:myungli_diary/design/components/today/day_character.dart';
import 'package:myungli_diary/design/components/today/day_reading_skeleton.dart';
import 'package:myungli_diary/design/elements/skeleton_bone.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';
import 'package:myungli_diary/features/calendar/application/calendar_providers.dart';
import 'package:myungli_diary/features/depth/application/depth_sheets.dart';
import 'package:myungli_diary/features/diary/application/diary_providers.dart';
import 'package:myungli_diary/features/schedule/application/schedule_providers.dart';

/// 그날 시트(`day-sheet`) 본문: 날의 성격 한 줄, 그날 일정, 일기 입구.
///
/// * 날의 성격은 달 길흉의 그 날([calendarDayProvider])입니다(getDaily를 부르지 않음).
///   기다리는 동안 skeleton(`loading`), 받지 못하면 오류 화면과 다시 시도(`error`)입니다.
///   지원 범위 밖 달이면 다시 시도 없는 범위 안내입니다(A44).
/// * 일정은 [schedulesOnDateProvider]의 하루 일정(하루 종일 먼저, 시각순)입니다. 없으면
///   빈 문장과 일정 추가(`empty`), 받지 못하면 빈 문장 대신 조용한 오류 한 줄과 다시 시도,
///   일정 추가를 둡니다(없다고 말하지 않게).
/// * 일기 입구는 오늘·지난 날만이고(D49) 일기가 있으면 보기, 없으면 쓰기입니다. 미래 날은
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
    // 다시 받는 중에는 들고 있던 목록을 그대로 보입니다(깜빡이지 않게). 로그아웃은 범위를 빈
    // 목록으로 덮은 뒤 다시 받으므로 이전 계정 일정이 남지 않습니다.
    if (schedules.isLoading && !schedules.hasValue) {
      return const _ScheduleSkeleton();
    }
    final list = schedules.value;
    if (list == null) {
      return _ScheduleError(
        error: schedules.error,
        // 값 없이 실패한 격자는 고르지 않으므로, 실패는 그 날 하루 범위입니다.
        onRetry: () =>
            ref.invalidate(schedulesInRangeProvider((from: date, to: date))),
        addButton: addButton,
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

/// 일정을 받지 못했을 때: 오류 종류에 맞는 조용한 한 줄, 다시 시도, 일정 추가.
///
/// 시트 전체의 `error`(날의 성격을 못 받음)와 달리 목록 자리만의 표시입니다. 모양은 임시이고
/// design 확인 대기입니다(#218).
class _ScheduleError extends StatelessWidget {
  const new({
    required this.error,
    required this.onRetry,
    required this.addButton,
  });

  static const Key messageKey = ValueKey('day-sheet.event.error');

  final Object? error;
  final VoidCallback onRetry;
  final Widget addButton;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = context.tokens;
    final cause = error;
    final appError = cause is AppError
        ? cause
        : UnexpectedError(cause ?? 'unknown');
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: Space.s4,
      children: [
        Text(
          errorMessage(l10n, appError),
          key: messageKey,
          textAlign: TextAlign.center,
          style: tokens.typography.captionLg.copyWith(
            color: tokens.colors.textSecondary,
          ),
        ),
        PrimaryButton(
          label: l10n.actionRetry,
          onPressed: onRetry,
          variant: PrimaryButtonVariant.quiet,
        ),
        addButton,
      ],
    );
  }
}

/// 일기 입구(오늘·지난 날). 일기 여부를 묻는 동안은 링크 한 줄 자리를 skeleton으로 잡아 두어,
/// 답이 와도 시트 높이가 바뀌지 않게 합니다.
class _DiaryEntry extends ConsumerWidget {
  const new({required this.date});

  final CalendarDate date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final written = ref.watch(diaryExistsOnProvider(date)).value;
    if (written == null) {
      return const _LinkSkeleton();
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
    await _push(context, datedPathOf(target, date));
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

/// [style] 글줄 하나의 높이(기기 글자 크기 반영)와 그 안의 뼈 높이(글자 몸통, 0.6).
({double line, double bone}) _lineMetrics(
  BuildContext context,
  TextStyle style,
) {
  final fontSize = MediaQuery.textScalerOf(context).scale(style.fontSize ?? 16);
  final line = fontSize * (style.height ?? 1.5);
  return (line: line, bone: line * 0.6);
}

/// 일기 링크(`depth-link` `navigate`) 한 줄 자리. 위 여백과 글줄 높이가 링크와 같습니다.
class _LinkSkeleton extends StatelessWidget {
  const new();

  static const Key skeletonKey = ValueKey('day-sheet.diary.skeleton');

  /// 링크 글자 폭의 어림(줄 너비 대비).
  static const double _widthFactor = 0.3;

  @override
  Widget build(BuildContext context) {
    final metrics = _lineMetrics(context, context.tokens.typography.labelLg);
    return Padding(
      key: skeletonKey,
      padding: const EdgeInsets.only(top: Space.s12),
      child: SizedBox(
        height: metrics.line,
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: FractionallySizedBox(
            widthFactor: _widthFactor,
            child: SkeletonBone(height: metrics.bone, borderRadius: Radii.xs),
          ),
        ),
      ),
    );
  }
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
