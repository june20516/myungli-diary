import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:myungli_diary/app/router/app_router.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/gen/model/slot_text.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:myungli_diary/core/clock/clock.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/error_messages.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/action/share_button.dart';
import 'package:myungli_diary/design/components/calendar/event_row.dart';
import 'package:myungli_diary/design/components/feedback/notice_banner.dart';
import 'package:myungli_diary/design/components/feedback/screen_state_view.dart';
import 'package:myungli_diary/design/components/feedback/seep_on_change.dart';
import 'package:myungli_diary/design/components/feedback/seep_presence.dart';
import 'package:myungli_diary/design/components/feedback/toast.dart';
import 'package:myungli_diary/design/components/frame/app_bar.dart';
import 'package:myungli_diary/design/components/sentence/depth_link.dart';
import 'package:myungli_diary/design/components/sentence/reaction_button.dart';
import 'package:myungli_diary/design/components/sentence/sentence_block.dart';
import 'package:myungli_diary/design/components/today/day_character.dart';
import 'package:myungli_diary/design/components/today/day_reading_skeleton.dart';
import 'package:myungli_diary/design/components/today/guide_question_card.dart';
import 'package:myungli_diary/design/components/today/lucky_card.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';
import 'package:myungli_diary/features/calendar/application/day_sheets.dart';
import 'package:myungli_diary/features/depth/application/depth_sheets.dart';
import 'package:myungli_diary/features/depth/application/evidence_unlock_controller.dart';
import 'package:myungli_diary/features/depth/application/term_origin.dart';
import 'package:myungli_diary/features/diary/application/diary_providers.dart';
import 'package:myungli_diary/features/diary/application/diary_summary_rows.dart';
import 'package:myungli_diary/features/diary/model/diary_write_entry.dart';
import 'package:myungli_diary/features/glossary/application/glossary_providers.dart';
import 'package:myungli_diary/features/schedule/application/schedule_providers.dart';
import 'package:myungli_diary/features/schedule/model/today_schedule_summary.dart';
import 'package:myungli_diary/features/today/application/daily_controller.dart';
import 'package:myungli_diary/features/today/application/reaction_controller.dart';
import 'package:myungli_diary/features/today/application/today_content.dart';
import 'package:myungli_diary/features/today/application/today_presentation.dart';

/// IA `today`가 직접 처리하는 상태.
const Set<String> todayHandledStates = {
  'loading',
  'error',
  'offline',
  'time-unknown',
};

/// IA `today`의 출구 대상.
const Set<String> todayExits = {
  ScreenIds.daySheet,
  ScreenIds.diaryEdit,
  ScreenIds.diaryView,
  ScreenIds.explainSheet,
  ScreenIds.evidenceSheet,
  ScreenIds.sharePreview,
};

/// 오늘(탭 루트): 날의 성격, 총운, 행운 칩, 가이드 질문과 오늘 쓴 일기 줄을 보여 주고 깊이
/// 시트와 일기로 잇습니다. 가이드 질문 카드는 언제나 새 일기 쓰기이고, 오늘 일기를 다 채웠으면
/// 누를 수 없습니다(D83 ②).
///
/// 값은 [todayContentProvider] 한 곳에서 받고, 표시 값 변환은 `today_presentation.dart`가
/// 합니다. 처음 불러올 때는 카드 자리 skeleton, 캐시 → server 응답이 다르면 내용이 스밉니다.
/// 총운 첫 문장의 반응 버튼은 낙관적으로 바뀌고 실패하면 되돌리며 오류 toast를 보입니다.
/// 행운 칩 줄 아래에 오늘 일정 한 줄이 있고 누르면 오늘 `day-sheet`가 열립니다(A35).
/// 배너(계획 7)는 아직 없습니다.
class TodayScreen extends ConsumerWidget {
  /// today 화면을 만듭니다.
  const new({super.key});

  /// 실패한 쪽만 다시 받습니다. 오늘 응답은 캐시를 건너뛰고 다시 받습니다.
  void _retry(WidgetRef ref) {
    if (ref.read(glossaryProvider).hasError) {
      ref.invalidate(glossaryProvider);
    }
    final daily = ref.read(dailyControllerProvider);
    if (daily.hasError || daily.value?.date != ref.read(todayProvider)) {
      unawaited(ref.read(dailyControllerProvider.notifier).reload());
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tokens = context.tokens;
    final content = ref.watch(todayContentProvider);
    final sheets = ref.watch(depthSheetsProvider);
    return Semantics(
      identifier: ScreenIds.today,
      child: Scaffold(
        key: const ValueKey(ScreenIds.today),
        body: DecoratedBox(
          decoration: BoxDecoration(gradient: tokens.gradients.today),
          child: SafeArea(
            // 아래는 탭 틀 뒤로 내용이 흐르도록 스크롤 여백으로 비웁니다.
            bottom: false,
            child: Column(
              children: [
                MyungliAppBar.tabRoot(
                  title: l10n.todayBarTitle,
                  titleIdentifier: SlotIds.todayBarTitle,
                  actions: [
                    // 공유할 내용이 생기면 스며 나타납니다(동작 줄이기면 투명도만).
                    SeepPresence(
                      key: const ValueKey('today.share'),
                      present: content.hasValue,
                      child: ShareButton(
                        variant: ShareButtonVariant.icon,
                        label: l10n.shareLabel,
                        onPressed: () => sheets.openSharePreview(context),
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: ScreenStateView<TodayContent>(
                    value: content,
                    onRetry: () => _retry(ref),
                    // 카드 자리 skeleton. 큰 글자에서 화면보다 길어도 넘치지 않게 잘라 둡니다.
                    skeleton: const SingleChildScrollView(
                      physics: NeverScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        Space.s20,
                        Space.s8,
                        Space.s20,
                        0,
                      ),
                      child: DayReadingSkeleton(),
                    ),
                    onStaleError: (error) =>
                        showMyungliToast(context, errorMessage(l10n, error)),
                    // 연결 실패로 그날 캐시를 보이는 중이면 오프라인 배너를 보입니다.
                    isStale: (value) => value.view.stale,
                    dataWithNotice: (value, notice) => _TodayBody(
                      content: value,
                      offlineNotice: notice,
                      sheets: sheets,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 오늘 내용. 컴포넌트를 배치만 하고 값은 `today_presentation.dart`에서 받습니다.
class _TodayBody extends ConsumerWidget {
  const new({
    required this.content,
    required this.offlineNotice,
    required this.sheets,
  });

  final TodayContent content;

  /// `ScreenStateView`가 준 오프라인 배너(내용 첫 줄).
  final Widget offlineNotice;
  final DepthSheets sheets;

  /// 오늘 새 일기를 쓰러 갑니다(A67·A69). 돌아오면 오늘 일기 목록과 달력 도장을 다시 묻습니다
  /// (쓰고 왔으면 줄이 늘고 도장이 찍힘).
  Future<void> _writeDiary(BuildContext context, WidgetRef ref) async {
    final date = content.view.date;
    await context.push<void>(datedPathOf(ScreenIds.diaryEdit, date));
    if (context.mounted) {
      // 저장하면 쓰기 화면이 이미 다시 묻게 합니다. 저장 없이 돌아온 경우(취소·초안만 남김)나
      // 그 사이 다른 기기에서 바뀐 경우를 위해 돌아올 때 한 번 더 묻습니다.
      ref
        ..invalidate(diariesOnProvider(date))
        ..invalidate(diaryDatesProvider);
    }
  }

  /// [text]의 반응을 뒤집습니다. 실패하면 컨트롤러가 되돌리므로 오류만 알립니다.
  Future<void> _toggleReaction(
    BuildContext context,
    WidgetRef ref,
    SlotText text,
    CalendarDate date,
  ) async {
    final l10n = AppLocalizations.of(context);
    try {
      await ref
          .read(reactionControllerProvider.notifier)
          .toggle(text, date: date);
    } on AppError catch (error) {
      if (context.mounted) {
        showMyungliToast(context, errorMessage(l10n, error));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final daily = content.view.daily;
    final date = content.view.date;
    final headLiked = ReactionController.isLiked(
      ref.watch(reactionControllerProvider),
      date,
      daily.fortune.head,
    );
    final display = todayDisplayOf(
      daily,
      content.names,
      l10n,
      ref.watch(profileTimezoneProvider),
    );
    final character = display.character;
    final timeUnknown = display.timeUnknown;
    final head = display.head;
    final tag = display.tag;
    final diaries = content.diaries;
    final entry = diaryWriteEntryOf(diaries.length);
    final diaryRow = ref.watch(diarySummaryRowProvider);
    // 오늘 화면의 용어는 오늘 응답의 슬롯에서 왔으므로 오늘 응답을 출처로 넘깁니다.
    void openExplain(String termId, String slotId) => sheets.openExplain(
      context,
      termId: termId,
      origin: TermOrigin(slotId: slotId, subject: const DailyEvidenceSubject()),
    );
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return SeepOnChange(
      changeKey: display,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          Space.s20,
          Space.s8,
          Space.s20,
          bottomInset + Space.s32,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            offlineNotice,
            if (timeUnknown != null)
              NoticeBanner(
                key: const ValueKey('today.time-unknown'),
                variant: NoticeBannerVariant.timeUnknown,
                message: timeUnknown,
              ),
            Semantics(
              identifier: SlotIds.todayCharacterLabel,
              container: true,
              child: KeyedSubtree(
                key: const ValueKey(SlotIds.todayCharacterLabel),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: DayCharacter(
                    variant: character.variant,
                    label: character.label,
                    reason: character.reason,
                    reasonSlotId: SlotIds.todayCharacterReason,
                    reasonTrailing: DepthLink(
                      variant: DepthLinkVariant.inlineEnd,
                      label: l10n.depthLinkEvidence,
                      slotId: SlotIds.todayEvidenceLink,
                      onTap: () => sheets.openEvidence(
                        context,
                        slotId: display.characterReasonSlot,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (!head.isBlank) const SizedBox(height: Space.s16),
            if (!head.isBlank)
              SentenceBlock(
                variant: SentenceBlockVariant.card,
                text: head.text,
                slotId: SlotIds.todayFortuneHead,
                onTerm: (termId) => openExplain(termId, head.slot),
                trailing: DepthLink(
                  variant: DepthLinkVariant.inlineEnd,
                  label: l10n.depthLinkEvidence,
                  slotId: SlotIds.todayEvidenceLink,
                  onTap: () => sheets.openEvidence(context, slotId: head.slot),
                ),
              ),
            if (!head.isBlank && display.headReactable)
              ReactionButton(
                on: headLiked,
                semanticsLabel: headLiked
                    ? l10n.todayReactionLabelSelected
                    : l10n.todayReactionLabel,
                onChanged: (_) => unawaited(
                  _toggleReaction(context, ref, daily.fortune.head, date),
                ),
              ),
            if (tag != null && !tag.isBlank) ...[
              const SizedBox(height: Space.s12),
              SentenceBlock(
                variant: SentenceBlockVariant.card,
                text: tag.text,
                slotId: SlotIds.todayFortuneBody,
                onTerm: (termId) => openExplain(termId, tag.slot),
              ),
            ],
            // 칩 줄은 위아래에 판정 여유(hitInset)를 품으므로 보이는 간격이 24가 되게 뺍니다.
            const SizedBox(height: Space.s24 - LuckyCardRow.hitInset),
            LuckyCardRow(
              // 대표 태그 칩이 맨 앞, 그 뒤에 행운 4종입니다.
              items: [...display.tags, ...display.lucky],
              slotIds: todayLuckySlotIds,
            ),
            const SizedBox(height: Space.s24 - LuckyCardRow.hitInset),
            const _TodayEventSummary(),
            GuideQuestionCard(
              state: diaries.isEmpty
                  ? GuideQuestionState.before
                  : GuideQuestionState.after,
              eyebrow: l10n.todayGuideEyebrow,
              question: display.guide,
              actionLabel: switch (entry) {
                DiaryWriteEntry.first => l10n.todayGuideCta,
                DiaryWriteEntry.more => l10n.todayGuideCtaWritten,
                DiaryWriteEntry.full => l10n.todayGuideCtaFull,
              },
              // 그날 일기를 다 채웠으면 누를 수 없습니다(D83 ②).
              onAction: entry == DiaryWriteEntry.full
                  ? null
                  : () => unawaited(_writeDiary(context, ref)),
              questionSlotId: SlotIds.todayGuideQuestion,
              actionSlotId: SlotIds.todayGuideCta,
            ),
            // 오늘 쓴 일기 줄(작성 순). 누르면 그 일기의 diary-view입니다.
            if (diaries.isNotEmpty) ...[
              const SizedBox(height: Space.s12),
              for (final (index, summary) in diaries.indexed)
                diaryRow(
                  summary,
                  isLast: index == diaries.length - 1,
                  // IA 출구에 tag-diary가 없어 대표 태그 칩은 표시만 합니다.
                  tagLinked: false,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 오늘 일정 한 줄(`today.event.summary`, A35)과 그 아래 간격.
///
/// 요약은 `todayScheduleSummaryProvider`에서 받고, 분이 바뀌면 "다음"이 다시 골라집니다.
/// 일정이 없거나 불러오지 못하면(요약 null) 줄도 간격도 그리지 않아 오늘의 다른 상태에
/// 영향이 없습니다. 화면을 연 뒤 도착한 줄은 스며 나타나고(열 때 이미 있으면 바로),
/// 사라질 때는 마지막 요약을 보이며 스며 사라집니다. 누르면 오늘 `day-sheet`를 엽니다.
class _TodayEventSummary extends ConsumerStatefulWidget {
  const new();

  @override
  ConsumerState<_TodayEventSummary> createState() => _TodayEventSummaryState();
}

class _TodayEventSummaryState extends ConsumerState<_TodayEventSummary> {
  /// 사라지는 동안 보일 마지막 요약.
  TodayScheduleSummary? _shown;

  static EventRowStatus _statusOf(TodayScheduleStatus status) =>
      switch (status) {
        TodayScheduleStatus.next => EventRowStatus.next,
        TodayScheduleStatus.inProgress => EventRowStatus.inProgress,
      };

  void _openDaySheet() => unawaited(
    ref.read(daySheetsProvider).open(context, ref.read(todayProvider)),
  );

  Widget _row(AppLocalizations l10n, TodayScheduleSummary summary) =>
      switch (summary) {
        TodayScheduleHighlight(
          :final status,
          :final time,
          :final title,
          :final moreCount,
        ) =>
          EventRow.summary(
            status: _statusOf(status),
            time: time,
            title: title,
            moreCount: moreCount,
            onTap: _openDaySheet,
            identifier: SlotIds.todayEventSummary,
          ),
        TodayScheduleAllPast(:final count) => EventRow.summary(
          status: null,
          title: '',
          allPastSentence: l10n.todayEventSummaryAllPast(count),
          onTap: _openDaySheet,
          identifier: SlotIds.todayEventSummary,
        ),
      };

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(todayScheduleSummaryProvider);
    if (summary != null) _shown = summary;
    final shown = _shown;
    return SeepPresence(
      key: const ValueKey(SlotIds.todayEventSummary),
      present: summary != null,
      // 화면을 열 때 이미 받아 둔 요약은 그대로 보이고, 연 뒤에 도착한 줄만 스밉니다.
      animateInitial: false,
      onGone: () {
        if (mounted) setState(() => _shown = null);
      },
      child: shown == null
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.only(bottom: Space.s12),
              child: _row(AppLocalizations.of(context), shown),
            ),
    );
  }
}
