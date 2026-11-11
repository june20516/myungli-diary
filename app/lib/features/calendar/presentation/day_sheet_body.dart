import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:myungli_diary/app/router/app_router.dart';
import 'package:myungli_diary/app/router/diary_entry_data.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/gen/model/calendar_day.dart';
import 'package:myungli_diary/core/api/gen/model/day_kind.dart';
import 'package:myungli_diary/core/api/gen/model/schedule.dart';
import 'package:myungli_diary/core/api/gen/model/score_item.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:myungli_diary/core/clock/clock.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/day_kind_names.dart';
import 'package:myungli_diary/core/l10n/error_messages.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/action/primary_button.dart';
import 'package:myungli_diary/design/components/calendar/event_row.dart';
import 'package:myungli_diary/design/components/calendar/fortune_verdict.dart';
import 'package:myungli_diary/design/components/diary/diary_row.dart';
import 'package:myungli_diary/design/components/feedback/screen_state_view.dart';
import 'package:myungli_diary/design/components/frame/section_header.dart';
import 'package:myungli_diary/design/components/frame/sheet.dart';
import 'package:myungli_diary/design/components/sentence/day_kind_hanja_tag.dart';
import 'package:myungli_diary/design/components/sentence/hanja_glyphs.dart';
import 'package:myungli_diary/design/components/sentence/hanja_tag.dart';
import 'package:myungli_diary/design/components/today/date_header.dart';
import 'package:myungli_diary/design/elements/app_icon.dart';
import 'package:myungli_diary/design/elements/skeleton_bone.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';
import 'package:myungli_diary/features/calendar/application/calendar_providers.dart';
import 'package:myungli_diary/features/calendar/model/score_item_meta.dart';
import 'package:myungli_diary/features/depth/application/depth_sheets.dart';
import 'package:myungli_diary/features/depth/application/explain_content.dart';
import 'package:myungli_diary/features/diary/application/diary_providers.dart';
import 'package:myungli_diary/features/diary/model/diary_write_entry.dart';
import 'package:myungli_diary/features/glossary/application/dictionary_gaps.dart';
import 'package:myungli_diary/features/glossary/application/glossary_providers.dart';
import 'package:myungli_diary/features/glossary/model/glossary_names.dart';
import 'package:myungli_diary/features/schedule/application/schedule_providers.dart';
import 'package:phosphor_glyphs/phosphor_glyphs.dart';

/// 섹션 머리 오른쪽 일정 추가(+) 그림.
const AppGlyph _plus = AppGlyph(
  light: PhosphorIconsLight.plus,
  regular: PhosphorIconsRegular.plus,
);

/// 그날 시트(`day-sheet`) 본문(V85, V86): 위에서부터 날짜 머리(오른쪽 끝에 날의 성격, V109),
/// 길흉판정, 일정, 일기입니다. 섹션 사이는 [SectionHeader.sectionGap], 제목과 내용 사이는
/// [SectionHeader.contentGap]입니다.
///
/// * 날의 성격은 달 길흉의 그 날([calendarDayProvider])입니다(getDaily를 부르지 않음).
///   기다리는 동안 skeleton(`loading`), 받지 못하면 오류 화면과 다시 시도(`error`)입니다.
///   지원 범위 밖 달이면 다시 시도 없는 범위 안내입니다(A44). 이유 문장은 두지 않습니다.
/// * 길흉판정 내역은 처음에 접혀 있고 카드를 누르면 펼칩니다(V108).
/// * 날의 성격 태그와 길흉판정 내역 태그는 누르면 그 용어의 뜻 시트(`explain-sheet`)입니다.
///   day-sheet의 깊이는 `surface`·`explain`까지라 그 풀이 시트에는 근거 보기가 없습니다.
/// * 일정은 [schedulesOnDateProvider]의 하루 일정(하루 종일 먼저, 시각순, 메모 한 줄)이고
///   추가는 섹션 머리 +입니다. 없으면 빈 문장만, 받지 못하면 조용한 오류 한 줄과 다시 시도입니다.
/// * 일기 섹션은 오늘·지난 날만이고(D49) 쓴 일기가 없어도 제목이 보입니다. 0편이면 제목 아래
///   쓰기 버튼만입니다(A69). 미래 날은 묻지도 그리지도 않습니다. 시트에는 광고 배너가 없습니다(D53).
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
      skeleton: _DaySheetSkeleton(date: date),
      dataWithNotice: (day, notice) =>
          _DaySheetContent(date: date, day: day, notice: notice),
    );
  }
}

/// 그 날의 날짜와 요일 글자(`day-sheet.date.solar`).
String _solarTextOf(AppLocalizations l10n, CalendarDate date) =>
    l10n.daySheetDateSolar(
      DateFormat.MMMMEEEEd(l10n.localeName)
          .format(DateTime(date.year, date.month, date.day)),
    );

/// 날의 성격을 받은 뒤의 본문.
class _DaySheetContent extends ConsumerWidget {
  const new({required this.date, required this.day, required this.notice});

  final CalendarDate date;
  final CalendarDay day;
  final Widget notice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final today = ref.watch(todayProvider);
    // 일기 입구는 오늘·지난 날만입니다(D49).
    final diaryAllowed = date.compareTo(today) <= 0;
    final lunar = day.lunar;
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          notice,
          SheetHeading(
            child: DateHeader(
              solar: _solarTextOf(l10n, date),
              lunar: lunar.isLeapMonth
                  ? l10n.daySheetDateLunarLeap(lunar.month, lunar.day)
                  : l10n.daySheetDateLunar(lunar.month, lunar.day),
              trailing: _DayKindTag(dayKind: day.dayKind),
            ),
          ),
          const SizedBox(height: SectionHeader.sectionGap),
          _VerdictSection(day: day),
          const SizedBox(height: SectionHeader.sectionGap),
          _ScheduleSection(date: date),
          if (diaryAllowed) ...[
            const SizedBox(height: SectionHeader.sectionGap),
            _DiarySection(date: date),
          ],
        ],
      ),
    );
  }
}

/// 날의 성격 `hanja-tag` `emphasis`(`day-sheet.character.label`). 날짜 머리 오른쪽 끝에
/// 놓이고(`date-header` `trailing`, V109) 누르면 뜻 시트입니다.
class _DayKindTag extends ConsumerWidget {
  const new({required this.dayKind});

  final DayKind dayKind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    HanjaTag tag({VoidCallback? onTap}) => dayKindHanjaTag(
      kind: dayKind,
      label: dayKindName(l10n, dayKind),
      variant: HanjaTagVariant.emphasis,
      onTap: onTap,
    );
    return Semantics(
      identifier: SlotIds.daySheetCharacterLabel,
      container: true,
      child: KeyedSubtree(
        key: const ValueKey(SlotIds.daySheetCharacterLabel),
        child: tag(
          onTap: () => unawaited(
            ref
                .read(depthSheetsProvider)
                .openExplain(
                  context,
                  ExplainTerm('day_kind.${dayKind.value}'),
                  head: tag(),
                ),
          ),
        ),
      ),
    );
  }
}

/// 길흉판정 섹션: 제목과 `fortune-verdict`(위치 막대와 내역). 내역 태그를 누르면 그 용어 뜻 시트.
///
/// 태그 이름은 용어 사전 이름, 뜻은 사전 `score_item` 이름이며 이름과 같으면 뜻을 생략합니다.
/// 사전을 받기 전에는 카드 뼈, 사전을 받지 못하면 막대와 이름만 그립니다.
class _VerdictSection extends ConsumerWidget {
  const new({required this.day});

  final CalendarDay day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final glossary = ref.watch(glossaryProvider);
    final names = glossary.value;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: l10n.daySheetVerdictTitle,
          titleIdentifier: SlotIds.daySheetVerdictTitle,
        ),
        const SizedBox(height: SectionHeader.contentGap),
        if (names == null && glossary.isLoading)
          FortuneVerdict.skeleton()
        else
          FortuneVerdict(
            score: day.score,
            // 사전을 받지 못하면(오류) 내역은 이름을 알 수 없어 빠지고 막대와 이름만 남습니다.
            // 사전 로드 실패는 이 화면이 따로 보고하지 않습니다(glossaryProvider의 오류 상태로
            // 남고, 저장소는 캐시 쓰기 실패만 보고함). 막대 판정은 사전과 무관해 그대로 보입니다.
            items: names == null ? null : day.scoreItems,
            nameOf: (id) => _tagNameOf(names, id),
            meaningOf: (id) => _meaningOf(names, id),
            onItemTap: (item) => _openItem(context, ref, names, item),
            onUnrenderable: (ids) => reportDictionaryGaps(ref.read, [
              for (final id in ids) _gapTermIdOf(names, id),
            ]),
          ),
      ],
    );
  }

  /// 줄이 빠진 원인 용어 id: 매핑된 용어의 사전 이름이 없으면 그 용어 id(`day_kind.*`,
  /// `relation.*`)이고, 아니면 `score_item.<id>`입니다. 한자 글자표
  /// (`HanjaGlyphs.forScoreItem`) 판단은 `FortuneVerdict`가 하므로, 이름이 있는데 줄이
  /// 빠졌다면 글자표에 id가 없는 경우입니다.
  static String _gapTermIdOf(GlossaryNames? names, String id) {
    final termId = ScoreItemMeta.termIdOf(id);
    if (termId != null && names?.nameOf(termId) == null) return termId;
    return '${ScoreItemMeta.glossaryCategory}.$id';
  }

  /// 내역 태그 이름: 매핑된 용어의 사전 이름. 모르면 null(그 줄은 그리지 않음).
  static String? _tagNameOf(GlossaryNames? names, String id) {
    final termId = ScoreItemMeta.termIdOf(id);
    return termId == null ? null : names?.nameOf(termId);
  }

  /// 짧은 뜻: `score_item` 범주 값 이름. 태그 이름과 같으면 null(뜻 생략).
  static String? _meaningOf(GlossaryNames? names, String id) {
    final meaning = names?.valueName(ScoreItemMeta.glossaryCategory, id);
    return meaning == _tagNameOf(names, id) ? null : meaning;
  }

  void _openItem(
    BuildContext context,
    WidgetRef ref,
    GlossaryNames? names,
    ScoreItem item,
  ) {
    final termId = ScoreItemMeta.termIdOf(item.id);
    final glyph = HanjaGlyphs.forScoreItem(item.id);
    final name = _tagNameOf(names, item.id);
    if (termId == null || glyph == null || name == null) return;
    unawaited(
      ref
          .read(depthSheetsProvider)
          .openExplain(
            context,
            ExplainTerm(termId),
            head: HanjaTag(glyph: glyph, label: name),
          ),
    );
  }
}

/// 일정 섹션: 제목과 오른쪽 +(`day-sheet.event.add`), 아래 목록 자리.
class _ScheduleSection extends ConsumerWidget {
  const new({required this.date});

  final CalendarDate date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final schedules = ref.watch(schedulesOnDateProvider(date));
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: l10n.todayEventTitle,
          titleIdentifier: SlotIds.daySheetEventTitle,
          trailing: SectionHeaderAction(
            icon: _plus,
            semanticLabel: l10n.daySheetEventAdd,
            identifier: SlotIds.daySheetEventAdd,
            onTap: () => _push(context, datedPathOf(ScreenIds.eventEdit, date)),
          ),
        ),
        const SizedBox(height: SectionHeader.contentGap),
        _list(context, ref, l10n, schedules),
      ],
    );
  }

  Widget _list(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    AsyncValue<List<Schedule>> schedules,
  ) {
    // 다시 받는 중에는 들고 있던 목록을 그대로 보입니다(깜빡이지 않게). 로그아웃 뒤 다시 받는
    // 동안은 하루 목록이 값 없는 loading이라 이전 계정 일정도, 잠깐의 "일정 없음"도 없습니다.
    if (schedules.isLoading && !schedules.hasValue) {
      return EventRow.skeleton(variant: EventRowVariant.list);
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
      );
    }
    if (list.isEmpty) {
      return EventRowListEmpty(
        message: l10n.daySheetEventEmpty,
        messageIdentifier: SlotIds.daySheetEventEmpty,
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
            memo: schedule.memo,
            showDivider: index < list.length - 1,
            onTap: () =>
                _push(context, pathOf(ScreenIds.eventEdit), extra: schedule),
          ),
      ],
    );
  }
}

/// 일기 섹션(오늘·지난 날, D49): 제목(`day-sheet.diary.open`, 쓴 일기가 없어도 보임), 작성 순
/// `diary-row` `entries`, 그 아래 새 일기 쓰기 `primary-button` `filled`(V37)입니다(A69).
///
/// 0편이면 제목 아래 쓰기 버튼만 둡니다. 쓰기 버튼은 그날 편수로 처음 쓰기, 한 편 더 쓰기, 다
/// 채움(누를 수 없음)입니다(D83 ②). 그날 일기를 받는 동안은 쓰기 버튼 자리에 skeleton이고,
/// 받지 못하면 0편으로 그려 쓰기를 막지 않습니다.
class _DiarySection extends ConsumerWidget {
  const new({required this.date});

  static const Key entryKey = ValueKey('day-sheet.diary.entry');

  final CalendarDate date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final diaries = ref.watch(diariesOnProvider(date)).value;
    final title = SectionHeader(
      title: l10n.daySheetDiaryOpen,
      titleIdentifier: SlotIds.daySheetDiaryOpen,
    );
    if (diaries == null) {
      return Column(
        key: entryKey,
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [title, const _EntrySkeleton()],
      );
    }
    final entry = diaryWriteEntryOf(diaries.length);
    final dateText = DateFormat.MMMMd(l10n.localeName)
        .format(DateTime(date.year, date.month, date.day));
    return Column(
      key: entryKey,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        title,
        const SizedBox(height: SectionHeader.contentGap),
        // 0편이면 아무것도 그리지 않습니다.
        if (diaries.isNotEmpty) ...[
          DiaryEntries(
            surface: DiaryEntriesSurface.plain,
            entries: diaryEntriesDataOf(context, diaries),
          ),
          const SizedBox(height: SectionHeader.contentGap),
        ],
        PrimaryButton(
          label: switch (entry) {
            DiaryWriteEntry.first => l10n.daySheetDiaryWriteCta(dateText),
            DiaryWriteEntry.more => l10n.daySheetDiaryWriteCtaWritten(dateText),
            DiaryWriteEntry.full => l10n.daySheetDiaryWriteCtaFull,
          },
          // 그날 일기를 다 채웠으면 누를 수 없습니다(D83 ②).
          onPressed: entry == DiaryWriteEntry.full
              ? null
              : () => unawaited(_writeDiary(context, ref)),
          identifier: SlotIds.daySheetDiaryWriteCta,
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

/// 일기를 받는 동안의 쓰기 버튼 자리: `primary-button` `filled` 크기의 뼈. 0편(가장 흔한 답)일
/// 때 시트 높이가 그대로입니다.
class _EntrySkeleton extends StatelessWidget {
  const new();

  static const Key skeletonKey = ValueKey('day-sheet.diary.skeleton');

  @override
  Widget build(BuildContext context) => Padding(
    key: skeletonKey,
    padding: const EdgeInsets.only(top: SectionHeader.contentGap),
    child: SkeletonBone(
      height: PrimaryButtonVariant.filled.height,
      borderRadius: Radii.md,
    ),
  );
}

/// 그날 시트 skeleton 부분을 찾는 테스트용 키.
abstract final class DaySheetSkeletonKeys {
  /// 날짜 머리 뼈(날짜 글자와 음력 글줄 뼈).
  static const Key date = ValueKey('day-sheet.skeleton.date');

  /// 길흉판정 카드 뼈.
  static const Key verdict = ValueKey('day-sheet.skeleton.verdict');

  /// 일정 줄 뼈.
  static const Key schedule = ValueKey('day-sheet.skeleton.schedule');
}

/// 그날 시트 skeleton(V66): 날짜와 요일은 바로, 음력 줄, 날의 성격 알약(날짜 머리 오른쪽),
/// `fortune-verdict`, 일정 줄, 일기 줄은 각자 뼈이고 섹션 제목은 그대로입니다. 배치는 본문과
/// 같습니다.
class _DaySheetSkeleton extends ConsumerWidget {
  const new({required this.date});

  final CalendarDate date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final diaryAllowed = date.compareTo(ref.watch(todayProvider)) <= 0;
    // 큰 글자에서 뼈가 시트 높이를 넘어도 본문과 같이 시트 안에서 스크롤합니다.
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetHeading(
            child: KeyedSubtree(
              key: DaySheetSkeletonKeys.date,
              child: DateHeader.skeleton(
                solar: _solarTextOf(l10n, date),
                trailing: HanjaTag.skeleton(index: 2),
              ),
            ),
          ),
          const SizedBox(height: SectionHeader.sectionGap),
          SectionHeader(title: l10n.daySheetVerdictTitle),
          const SizedBox(height: SectionHeader.contentGap),
          KeyedSubtree(
            key: DaySheetSkeletonKeys.verdict,
            child: FortuneVerdict.skeleton(index: 3),
          ),
          const SizedBox(height: SectionHeader.sectionGap),
          SectionHeader(title: l10n.todayEventTitle),
          const SizedBox(height: SectionHeader.contentGap),
          KeyedSubtree(
            key: DaySheetSkeletonKeys.schedule,
            child: EventRow.skeleton(variant: EventRowVariant.list, index: 6),
          ),
          if (diaryAllowed) ...[
            const SizedBox(height: SectionHeader.sectionGap),
            SectionHeader(title: l10n.daySheetDiaryOpen),
            const _EntrySkeleton(),
          ],
        ],
      ),
    );
  }
}
