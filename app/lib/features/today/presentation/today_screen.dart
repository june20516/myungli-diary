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
import 'package:myungli_diary/features/depth/application/depth_sheets.dart';
import 'package:myungli_diary/features/diary/application/diary_providers.dart';
import 'package:myungli_diary/features/glossary/application/glossary_providers.dart';
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

/// IA `today`의 출구 대상. `day-sheet`(오늘 일정 한 줄)는 계획 4가 더합니다.
const Set<String> todayExits = {
  ScreenIds.diaryEdit,
  ScreenIds.diaryView,
  ScreenIds.explainSheet,
  ScreenIds.evidenceSheet,
  ScreenIds.sharePreview,
};

/// 오늘(탭 루트): 날의 성격, 총운, 행운 칩, 가이드 질문을 보여 주고 깊이 시트와 일기로 잇습니다.
///
/// 값은 [todayContentProvider] 한 곳에서 받고, 표시 값 변환은 `today_presentation.dart`가
/// 합니다. 처음 불러올 때는 카드 자리 skeleton, 캐시 → server 응답이 다르면 내용이 스밉니다.
/// 총운 첫 문장의 반응 버튼은 낙관적으로 바뀌고 실패하면 되돌리며 오류 toast를 보입니다.
/// 오늘 일정 줄·배너(계획 4·7)는 아직 없습니다.
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
                  title: l10n.tabToday,
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

  /// 일기 화면으로 갔다가 돌아오면 오늘 일기 여부를 다시 묻습니다(쓰고 왔으면 도장이 찍힘).
  Future<void> _openDiary(BuildContext context, WidgetRef ref) async {
    final target = content.diaryWritten
        ? ScreenIds.diaryView
        : ScreenIds.diaryEdit;
    await context.push<void>(pathOf(target));
    if (context.mounted) {
      ref.invalidate(todayDiaryExistsProvider);
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
    final character = dayCharacterOf(daily, l10n);
    final timeUnknown = timeUnknownNoticeOf(daily);
    final head = daily.fortune.head;
    final tag = daily.fortune.tag;
    final items = luckyItemsOf(
      daily,
      content.names,
      l10n,
      ref.watch(profileTimezoneProvider),
    );
    void openExplain(String termId, String sourceSlotId) =>
        sheets.openExplain(context, termId: termId, sourceSlotId: sourceSlotId);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return SeepOnChange(
      changeKey: dailySignature(daily),
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
                  ),
                ),
              ),
            ),
            const SizedBox(height: Space.s16),
            SentenceBlock(
              variant: SentenceBlockVariant.card,
              text: head.text,
              slotId: SlotIds.todayFortuneHead,
              onTerm: (termId) => openExplain(termId, head.slot),
              trailing: DepthLink(
                variant: DepthLinkVariant.inlineEnd,
                label: l10n.depthLinkEvidence,
                onTap: () => sheets.openEvidence(context, slotId: head.slot),
              ),
            ),
            if (head.reactable)
              ReactionButton(
                on: headLiked,
                semanticsLabel: headLiked
                    ? l10n.todayReactionLabelSelected
                    : l10n.todayReactionLabel,
                onChanged: (_) =>
                    unawaited(_toggleReaction(context, ref, head, date)),
              ),
            if (tag != null) ...[
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
            LuckyCardRow(items: items, slotIds: todayLuckySlotIds),
            const SizedBox(height: Space.s24 - LuckyCardRow.hitInset),
            GuideQuestionCard(
              state: content.diaryWritten
                  ? GuideQuestionState.after
                  : GuideQuestionState.before,
              eyebrow: l10n.todayGuideEyebrow,
              question: daily.guide.text,
              actionLabel: content.diaryWritten
                  ? l10n.todayGuideCtaWritten
                  : l10n.todayGuideCta,
              onAction: () => _openDiary(context, ref),
              questionSlotId: SlotIds.todayGuideQuestion,
              actionSlotId: SlotIds.todayGuideCta,
            ),
          ],
        ),
      ),
    );
  }
}
