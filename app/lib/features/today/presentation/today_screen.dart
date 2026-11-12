import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:myungli_diary/app/router/app_router.dart';
import 'package:myungli_diary/app/router/diary_entry_data.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/gen/model/slot_text.dart';
import 'package:myungli_diary/core/api/gen/model/ten_god_group.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:myungli_diary/core/clock/clock.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/error_messages.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/action/share_button.dart';
import 'package:myungli_diary/design/components/calendar/event_row.dart';
import 'package:myungli_diary/design/components/diary/diary_row.dart';
import 'package:myungli_diary/design/components/feedback/notice_banner.dart';
import 'package:myungli_diary/design/components/feedback/screen_state_view.dart';
import 'package:myungli_diary/design/components/feedback/seep_on_change.dart';
import 'package:myungli_diary/design/components/feedback/seep_presence.dart';
import 'package:myungli_diary/design/components/feedback/skeleton.dart';
import 'package:myungli_diary/design/components/feedback/toast.dart';
import 'package:myungli_diary/design/components/frame/app_bar.dart';
import 'package:myungli_diary/design/components/frame/section_card.dart';
import 'package:myungli_diary/design/components/frame/section_header.dart';
import 'package:myungli_diary/design/components/sentence/day_kind_hanja_tag.dart';
import 'package:myungli_diary/design/components/sentence/depth_link.dart';
import 'package:myungli_diary/design/components/sentence/hanja_glyphs.dart';
import 'package:myungli_diary/design/components/sentence/hanja_tag.dart';
import 'package:myungli_diary/design/components/sentence/reaction_button.dart';
import 'package:myungli_diary/design/components/sentence/sentence_block.dart';
import 'package:myungli_diary/design/components/today/date_header.dart';
import 'package:myungli_diary/design/components/today/guide_question_card.dart';
import 'package:myungli_diary/design/components/today/lucky_card.dart';
import 'package:myungli_diary/design/elements/list_divider.dart';
import 'package:myungli_diary/design/interaction/stick_to_end_on_grow.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';
import 'package:myungli_diary/features/calendar/application/day_sheets.dart';
import 'package:myungli_diary/features/depth/application/depth_sheets.dart';
import 'package:myungli_diary/features/depth/application/evidence_unlock_controller.dart';
import 'package:myungli_diary/features/depth/application/explain_content.dart';
import 'package:myungli_diary/features/depth/application/term_origin.dart';
import 'package:myungli_diary/features/diary/application/diary_providers.dart';
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
  ScreenIds.tagSheet,
  ScreenIds.sharePreview,
};

/// 오늘(탭 루트, IA v5 `today`, D108): 날짜 머리 아래 총운, 사주 기운, 행운, 일정(있는 날만),
/// 오늘의 질문 섹션을 두고 깊이 시트와 일기로 잇습니다(today.md "today 화면 배치").
///
/// 값은 [todayContentProvider] 한 곳에서 받고, 표시 값 변환은 `today_presentation.dart`가
/// 합니다. 처음 불러올 때는 섹션 배치대로 놓은 skeleton, 캐시 → server 응답이 다르면 내용이
/// 스밉니다. 총운 섹션 제목 줄 오른쪽 좋아요는 낙관적으로 바뀌고 실패하면 되돌리며 오류 toast를
/// 보입니다. 오늘의 질문 카드는 언제나 새 일기 쓰기이고, 오늘 일기를 다 채웠으면 누를 수
/// 없습니다(D83 ②). 배너(계획 7)는 아직 없습니다.
class TodayScreen extends ConsumerWidget {
  /// today 화면을 만듭니다.
  const new({super.key});

  /// 불러오는 중 skeleton을 찾는 테스트용 키.
  static const Key skeletonKey = ValueKey('today.skeleton');

  /// 사주 기운 섹션 카드를 찾는 테스트용 키.
  static const Key featuredCardKey = ValueKey('today.featured.card');

  /// 총운 카드의 헤드라인과 보조 문장 사이 선을 찾는 테스트용 키.
  static const Key fortuneDividerKey = ValueKey('today.fortune.divider');

  /// 보조 문장 위 사주 기운 태그 자리의 키 값(`ValueKey<String>`).
  static const String bodyTagKeyValue = 'today.fortune.body.tag';

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
                    skeleton: const _TodaySkeleton(key: skeletonKey),
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

/// 날짜 머리의 양력과 요일 글자(`today.date.solar`). 기기 날짜라 불러오는 중에도 그립니다.
String _solarTextOf(BuildContext context, CalendarDate date) =>
    AppLocalizations.of(context)
        .todayDateSolar(shareDateText(date, Localizations.localeOf(context)));

/// 행운 카드 안쪽 여백. 칩 줄이 위아래에 판정 여유([LuckyCardRow.hitInset])를 품으므로
/// 보이는 여백이 `space.16`이 되게 그만큼 뺍니다.
const EdgeInsets _luckyCardPadding = EdgeInsets.symmetric(
  horizontal: Space.s16,
  vertical: Space.s16 - LuckyCardRow.hitInset,
);

/// 한자 태그 줄 사이(`space.8`, today 화면 배치 3번, 4번).
const double _tagGap = Space.s8;

/// 불러오는 중: 상단 바와 섹션 제목은 그대로, 날짜 머리는 음력과 일진 줄만 뼈, 카드마다 그
/// 컴포넌트의 뼈를 배치대로 둡니다(today 화면 배치 "불러오는 중", V66). 큰 글자에서 화면보다
/// 길어도 넘치지 않게 잘라 둡니다. 일정 섹션은 있는 날만이라 뼈를 두지 않습니다.
class _TodaySkeleton extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(Space.s20, Space.s8, Space.s20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DateHeader.skeleton(
            solar: _solarTextOf(context, ref.watch(todayProvider)),
          ),
          const SizedBox(height: SectionHeader.sectionGap),
          SectionHeader(title: l10n.todayFortuneTitle),
          const SizedBox(height: SectionHeader.contentGap),
          SkeletonCard(
            padding: const EdgeInsets.all(Space.s16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: _tagGap,
                  children: [
                    HanjaTag.skeleton(index: 1),
                    HanjaTag.skeleton(index: 2),
                  ],
                ),
                const SizedBox(height: Space.s12),
                SentenceBlock.skeleton(
                  variant: SentenceBlockVariant.card,
                  index: 3,
                ),
              ],
            ),
          ),
          const SizedBox(height: SectionHeader.sectionGap),
          SectionHeader(title: l10n.todayFeaturedTitle),
          const SizedBox(height: SectionHeader.contentGap),
          SkeletonCard(
            padding: const EdgeInsets.all(Space.s16),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: HanjaTag.skeleton(index: 5),
            ),
          ),
          const SizedBox(height: SectionHeader.sectionGap),
          SectionHeader(title: l10n.todayLuckyTitle),
          const SizedBox(height: SectionHeader.contentGap),
          SkeletonCard(
            padding: _luckyCardPadding,
            child: LuckyCardRow.skeleton(index: 6),
          ),
          const SizedBox(height: SectionHeader.sectionGap),
          SectionHeader(title: l10n.todayGuideTitle),
          const SizedBox(height: SectionHeader.contentGap),
          GuideQuestionCard.skeleton(index: 9),
        ],
      ),
    );
  }
}

/// 오늘 내용. 컴포넌트를 배치만 하고 값은 `today_presentation.dart`에서 받습니다.
///
/// 사주 기운 시트가 열린 동안 누른 대표 태그를 `selected`로 두려고 그 순번을 들고 있습니다.
class _TodayBody extends ConsumerStatefulWidget {
  const new({
    required this.content,
    required this.offlineNotice,
    required this.sheets,
  });

  final TodayContent content;

  /// `ScreenStateView`가 준 오프라인 배너(내용 첫 줄).
  final Widget offlineNotice;
  final DepthSheets sheets;

  @override
  ConsumerState<_TodayBody> createState() => _TodayBodyState();
}

class _TodayBodyState extends ConsumerState<_TodayBody> {
  /// 사주 기운 시트가 열려 있는 대표 태그 순번. 닫혀 있으면 null입니다.
  int? _openTagRank;

  DepthSheets get _sheets => widget.sheets;

  /// 오늘 새 일기를 쓰러 갑니다(A67·A69). 돌아오면 오늘 일기 목록과 달력 도장을 다시 묻습니다
  /// (쓰고 왔으면 줄이 늘고 도장이 찍힘).
  Future<void> _writeDiary() async {
    final date = widget.content.view.date;
    await context.push<void>(datedPathOf(ScreenIds.diaryEdit, date));
    if (mounted) {
      // 저장하면 쓰기 화면이 이미 다시 묻게 합니다. 저장 없이 돌아온 경우(취소·초안만 남김)나
      // 그 사이 다른 기기에서 바뀐 경우를 위해 돌아올 때 한 번 더 묻습니다.
      ref
        ..invalidate(diariesOnProvider(date))
        ..invalidate(diaryDatesProvider);
    }
  }

  /// [text]의 반응을 뒤집습니다. 실패하면 컨트롤러가 되돌리므로 오류만 알립니다.
  Future<void> _toggleReaction(SlotText text, CalendarDate date) async {
    final l10n = AppLocalizations.of(context);
    try {
      await ref
          .read(reactionControllerProvider.notifier)
          .toggle(text, date: date);
    } on AppError catch (error) {
      if (mounted) {
        showMyungliToast(context, errorMessage(l10n, error));
      }
    }
  }

  /// [rank] 대표 태그의 사주 기운 시트를 열고, 닫힐 때까지 그 태그를 `selected`로 둡니다.
  Future<void> _openTag(int rank) async {
    setState(() => _openTagRank = rank);
    try {
      await _sheets.openTag(
        context,
        daily: widget.content.view.daily,
        rank: rank,
      );
    } finally {
      if (mounted) setState(() => _openTagRank = null);
    }
  }

  /// 오늘 응답 슬롯 [slotId] 문장 속 용어 [termId]의 풀이 시트를 엽니다(출처는 오늘 응답).
  void _openTermInSentence(String termId, String slotId) => unawaited(
    _sheets.openExplain(
      context,
      ExplainTerm(
        termId,
        origin: TermOrigin(
          slotId: slotId,
          subject: const DailyEvidenceSubject(),
        ),
      ),
    ),
  );

  /// 총운 결정 태그(날의 성격, 십성 묶음)의 뜻 시트를 엽니다. 머리는 누른 태그 모양이고
  /// 누를 수 없습니다.
  void _openTermTag(String termId, HanjaTag head) =>
      unawaited(_sheets.openExplain(context, ExplainTerm(termId), head: head));

  /// 대표 태그 [tag]의 `hanja-tag`(누르면 사주 기운 시트, 열린 동안 `selected`).
  Widget _featuredTag(FeaturedTagContent tag) => HanjaTag(
    glyph: tag.glyph,
    label: tag.label,
    variant: _openTagRank == tag.rank
        ? HanjaTagVariant.selected
        : HanjaTagVariant.normal,
    onTap: () => unawaited(_openTag(tag.rank)),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final content = widget.content;
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
    final diaries = content.diaries;
    final entry = diaryWriteEntryOf(diaries.length);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final showReaction = !display.head.isBlank && display.headReactable;
    return SeepOnChange(
      changeKey: display,
      // 끝에 닿은 채 하단 배너가 늦게 자라도 끝에 붙어 있습니다(#936).
      child: StickToEndOnGrow(
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
              widget.offlineNotice,
              Semantics(
                identifier: SlotIds.todayDateSolar,
                container: true,
                child: DateHeader(
                  solar: _solarTextOf(context, date),
                  lunar: display.lunarText,
                  iljin: display.iljinText,
                ),
              ),
              if (display.timeUnknown) ...[
                const SizedBox(height: Space.s16),
                // 배너는 아래에 `space.16`을 품으므로 섹션 사이 간격에서 그만큼 뺍니다.
                NoticeBanner(
                  key: const ValueKey('today.time-unknown'),
                  variant: NoticeBannerVariant.timeUnknown,
                  message: l10n.sajuChartTimeUnknownNotice,
                ),
                const SizedBox(height: SectionHeader.sectionGap - Space.s16),
              ] else
                const SizedBox(height: SectionHeader.sectionGap),
              SectionHeader(
                title: l10n.todayFortuneTitle,
                titleIdentifier: SlotIds.todayFortuneTitle,
                trailing: showReaction
                    ? SectionHeaderActionWidget(
                        ReactionButton(
                          on: headLiked,
                          semanticsLabel: headLiked
                              ? l10n.todayReactionLabelSelected
                              : l10n.todayReactionLabel,
                          onChanged: (_) => unawaited(
                            _toggleReaction(daily.fortune.head, date),
                          ),
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: SectionHeader.contentGap),
              SectionCard(child: _fortuneCard(l10n, display)),
              // 태그가 왔지만 하나도 그릴 수 없는 날은 D112가 아니라 섹션째 두지 않습니다
              // (빈 안내는 server 대표 태그가 실제로 빈 날만).
              if (display.featuredEmpty || display.featured.isNotEmpty) ...[
                const SizedBox(height: SectionHeader.sectionGap),
                SectionHeader(
                  title: l10n.todayFeaturedTitle,
                  titleIdentifier: SlotIds.todayFeaturedTitle,
                ),
                const SizedBox(height: SectionHeader.contentGap),
                SectionCard(
                  key: TodayScreen.featuredCardKey,
                  child: _featuredSection(l10n, display),
                ),
              ],
              const SizedBox(height: SectionHeader.sectionGap),
              SectionHeader(
                title: l10n.todayLuckyTitle,
                titleIdentifier: SlotIds.todayLuckyTitle,
              ),
              const SizedBox(height: SectionHeader.contentGap),
              SectionCard(
                padding: _luckyCardPadding,
                child: LuckyCardRow(
                  items: display.lucky,
                  onOpen: (item) => _sheets.openExplain(
                    context,
                    ExplainLucky(title: item.name, body: item.explain),
                  ),
                ),
              ),
              const _TodayEventSection(),
              const SizedBox(height: SectionHeader.sectionGap),
              SectionHeader(
                title: l10n.todayGuideTitle,
                titleIdentifier: SlotIds.todayGuideTitle,
              ),
              const SizedBox(height: SectionHeader.contentGap),
              GuideQuestionCard(
                state: switch (entry) {
                  DiaryWriteEntry.first => GuideQuestionState.before,
                  DiaryWriteEntry.more => GuideQuestionState.after,
                  DiaryWriteEntry.full => GuideQuestionState.full,
                },
                question: display.guide,
                actionLabel: switch (entry) {
                  DiaryWriteEntry.first => l10n.todayGuideCta,
                  DiaryWriteEntry.more => l10n.todayGuideCtaWritten,
                  DiaryWriteEntry.full => l10n.todayGuideCtaFull,
                },
                // full이면 카드가 버튼을 막습니다(D83 ②, 눌러도 아무 일 없음).
                onAction: () => unawaited(_writeDiary()),
                questionSlotId: SlotIds.todayGuideQuestion,
                actionSlotId: SlotIds.todayGuideCta,
              ),
              // 오늘 쓴 일기 줄(작성 순). 누르면 그 일기의 diary-view이고, 0편이면 그리지 않습니다.
              DiaryEntries(
                surface: DiaryEntriesSurface.card,
                entries: diaryEntriesDataOf(context, diaries),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 총운 카드: 결정 태그 줄 → 헤드라인 → 선 → 1순위 태그 → 보조 문장(today 화면 배치 3번).
  ///
  /// 보조 문장이 없으면(대표 태그가 없는 날, D112) 선, 태그, 보조 문장을 모두 그리지 않습니다.
  Widget _fortuneCard(AppLocalizations l10n, TodayDisplay display) {
    final head = display.head;
    final body = display.body;
    final bodyTag = display.bodyTag;
    // 같은 태그를 화면(누를 수 있음)과 뜻 시트 머리(누를 수 없음)에 함께 씁니다.
    HanjaTag dayKindTag({
      VoidCallback? onTap,
      HanjaTagVariant variant = HanjaTagVariant.emphasis,
    }) => dayKindHanjaTag(
      kind: display.dayKind,
      label: display.dayKindLabel,
      variant: variant,
      onTap: onTap,
    );
    final group = display.tenGodGroup;
    final groupLabel = display.tenGodGroupLabel;
    HanjaTag groupTag(TenGodGroup group, String label, {VoidCallback? onTap}) =>
        HanjaTag(
          glyph: HanjaGlyphs.forTenGodGroup(group),
          label: label,
          onTap: onTap,
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: _tagGap,
          runSpacing: _tagGap,
          children: [
            _slotTag(
              SlotIds.todayCharacterLabel,
              dayKindTag(
                onTap: () => _openTermTag(
                  'day_kind.${display.dayKind.value}',
                  dayKindTag(),
                ),
              ),
            ),
            if (group != null && groupLabel != null)
              _slotTag(
                SlotIds.todayTenGodLabel,
                groupTag(
                  group,
                  groupLabel,
                  onTap: () => _openTermTag(
                    'ten_god_group.${group.value}',
                    groupTag(group, groupLabel),
                  ),
                ),
              ),
          ],
        ),
        if (!head.isBlank) ...[
          const SizedBox(height: Space.s12),
          SentenceBlock(
            variant: SentenceBlockVariant.card,
            text: head.text,
            slotId: SlotIds.todayFortuneHead,
            onTerm: (termId) => _openTermInSentence(termId, head.slot),
            trailing: DepthLink.evidence(
              subject: l10n.todayFortuneTitle,
              placement: DepthLinkPlacement.inlineEnd,
              // 근거 시트 위 대상: 헤드라인을 정한 날의 성격과 십성 묶음(누를 수 없는 default).
              onTap: () => _sheets.openEvidence(
                context,
                head.slot,
                headTags: [
                  dayKindTag(variant: HanjaTagVariant.normal),
                  if (group != null && groupLabel != null)
                    groupTag(group, groupLabel),
                ],
                target: head.text,
              ),
            ),
          ),
        ],
        if (body != null && !body.isBlank) ...[
          const SizedBox(height: Space.s16),
          // 카드 안쪽 여백이 이미 `space.16` 들임이므로 선은 내용 폭 그대로입니다.
          const ListDivider(
            key: TodayScreen.fortuneDividerKey,
            indentStart: 0,
            indentEnd: 0,
          ),
          const SizedBox(height: Space.s16),
          if (bodyTag != null) ...[
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: KeyedSubtree(
                key: const ValueKey(TodayScreen.bodyTagKeyValue),
                child: _featuredTag(bodyTag),
              ),
            ),
            const SizedBox(height: Space.s8),
          ],
          SentenceBlock(
            variant: SentenceBlockVariant.body,
            text: body.text,
            slotId: SlotIds.todayFortuneBody,
            onTerm: (termId) => _openTermInSentence(termId, body.slot),
            trailing: DepthLink.evidence(
              // 보조 문장은 1순위 사주 기운에서 나온 문장이라 그 이름을 항목 이름으로 읽습니다.
              // 1순위를 그릴 수 없는 날(사전이나 글자표 빈칸, D112 아님)은 선과 보조 문장을
              // 그대로 두고 태그 자리만 비우며, 항목 이름은 총운입니다.
              subject: bodyTag?.label ?? l10n.todayFortuneTitle,
              placement: DepthLinkPlacement.inlineEnd,
              // 근거 시트 위 대상: 보조 문장을 정한 대표 태그 1순위(누를 수 없음).
              onTap: () => _sheets.openEvidence(
                context,
                body.slot,
                headTags: [
                  if (bodyTag != null)
                    HanjaTag(glyph: bodyTag.glyph, label: bodyTag.label),
                ],
                target: body.text,
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// 사주 기운 카드: 대표 태그 줄, server 대표 태그가 빈 날은 안내 한 줄(today 화면 배치
  /// 4번, D112 ②, V95).
  Widget _featuredSection(AppLocalizations l10n, TodayDisplay display) {
    if (display.featuredEmpty) {
      final tokens = context.tokens;
      return Semantics(
        identifier: SlotIds.todayFeaturedEmpty,
        container: true,
        child: Text(
          l10n.todayFeaturedEmpty,
          style: tokens.typography.bodyUi.copyWith(
            color: tokens.colors.textSecondary,
          ),
        ),
      );
    }
    return Wrap(
      spacing: _tagGap,
      runSpacing: _tagGap,
      children: [for (final tag in display.featured) _featuredTag(tag)],
    );
  }

  /// IA 슬롯 [slotId] 자리의 태그(테스트 키와 Semantics identifier).
  static Widget _slotTag(String slotId, Widget tag) => KeyedSubtree(
    key: ValueKey(slotId),
    child: Semantics(identifier: slotId, container: true, child: tag),
  );
}

/// 오늘 일정 섹션: 앞 섹션과 간격, 제목(`today.event.title`, A114), 일정 한 줄
/// (`today.event.summary`, A35) 카드.
///
/// 요약은 `todayScheduleSummaryProvider`에서 받고, 분이 바뀌면 "다음"이 다시
/// 골라집니다. 일정이 없거나 불러오지 못하면(요약 null) 섹션째(간격, 제목, 카드)
/// 그리지 않습니다(IA "일정이 있는 날만 섹션째"). 화면을 연 뒤 도착한 섹션은 스며
/// 나타나고(열 때 이미 있으면 바로), 사라질 때는 마지막 요약을 보이며 스며
/// 사라집니다. 누르면 오늘 `day-sheet`를 엽니다.
class _TodayEventSection extends ConsumerStatefulWidget {
  const new();

  @override
  ConsumerState<_TodayEventSection> createState() => _TodayEventSectionState();
}

class _TodayEventSectionState extends ConsumerState<_TodayEventSection> {
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
    final l10n = AppLocalizations.of(context);
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
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: SectionHeader.sectionGap),
                SectionHeader(
                  title: l10n.todayEventTitle,
                  titleIdentifier: SlotIds.todayEventTitle,
                ),
                const SizedBox(height: SectionHeader.contentGap),
                SectionCard(child: _row(l10n, shown)),
              ],
            ),
    );
  }
}
