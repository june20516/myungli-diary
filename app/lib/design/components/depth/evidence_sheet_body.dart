import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:myungli_diary/core/api/gen/model/rendered_text.dart';
import 'package:myungli_diary/core/api/rendered_text_plain.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/depth/evidence_lock_panel.dart';
import 'package:myungli_diary/design/components/feedback/live_announcement.dart';
import 'package:myungli_diary/design/components/feedback/seep_presence.dart';
import 'package:myungli_diary/design/components/feedback/skeleton.dart';
import 'package:myungli_diary/design/components/sentence/depth_link.dart';
import 'package:myungli_diary/design/components/sentence/sentence_block.dart';
import 'package:myungli_diary/design/elements/lock_veil.dart';
import 'package:myungli_diary/design/interaction/haptics.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

/// 근거 시트의 내용(`depth-link.evidenceSheet`). 시트 틀(`sheet` `full`) 안에 놓습니다.
///
/// 제목 → 대상(그 문장을 정한 태그 줄과 대상 문장) → 원국표 → 판정 근거 → 원전 → 내 사주에서는
/// 순서이고, 제목, 대상, 원국표는 늘 보입니다(잠기지 않음). 구역 제목 위는 `space.24`입니다.
/// 표 칸 용어에서 연 시트([showJudgment]가 false)는 내 사주에서는 구역 하나입니다.
/// 세 구역([showPersonal]이 false면 두 구역)은 [state]가 [DepthLinkState.unlocked]이면
/// 본문, 아니면 같은 자리에 `lock.veil`로 그립니다. 구역 제목은 잠겨도 또렷합니다.
/// 잠겼을 때는 시트 아래에 [EvidenceLockPanel]이 고정됩니다.
///
/// 판정 근거·원전 구역은 근거마다 문단 하나씩([basis]·[source]의 순서)이고 문단 사이는
/// `space.12`입니다(A42). 원전은 인용마다 `bg.base` 상자입니다. 잠긴 구역의 본문은 server가
/// 보내지 않고, 잠겼을 때는 넘어온 문장이 있어도 그리지 않습니다(D60). 열렸는데 문장이 없는
/// 구역(원고가 없어 server가 생략)은 제목도 자리도 그리지 않습니다(A22 남은 규칙, `depth-link`
/// 규칙 2.3.0). 잠겼을 때의 `lock.veil`은 본문을 내려받지 않은 상태라 그대로 그립니다. 이 내용
/// 높이는 부모가 정해 준 높이 안에서 스스로 스크롤합니다.
///
/// 잠긴 구역은 `lock.veil` G1입니다: server가 준 앞부분([basisLead], [sourceLead])이 있으면
/// 또렷하게 두고 뒤는 흐린 자리값이며, 줄 수는 판정 근거 3, 원전 2, 내 사주에서는 3입니다
/// ([LockVeilLines]). "내 사주에서는" 구역은 앞부분이 오지 않아 자리값만입니다.
///
/// [loading]이면 구역 제목 아래 본문 자리가 skeleton입니다(권한이 생겨 응답을 다시 받는 중,
/// IA `loading`). 안내 영역은 [state]대로 남습니다.
///
/// 잠김이 풀리는 순간(`locked`·`lockedNoAd`·`unlocking` → `unlocked`)에는 안내 영역이
/// `disappear.seep`으로 사라지고 본문이 구역 단위로 한 번 `appear.seep`으로 나타나며(문단이
/// 여럿이어도 문단마다 따로 나타나지 않음) light 햅틱과 "열렸다"는 알림이 한 번 옵니다. 그
/// 사이 skeleton 단계([loading])를 언제 켤지와 확인 시간 초과 toast는 화면 쪽 흐름의
/// 몫입니다. 처음부터 권한이 있으면 움직임도 햅틱도 알림도 없습니다.
class EvidenceSheetBody extends StatefulWidget {
  /// 근거 시트 내용을 만듭니다.
  const new({
    required this.state,
    required this.title,
    this.titleSlotId,
    this.targetTags = const [],
    this.target,
    this.pillars,
    this.basis = const [],
    this.source = const [],
    this.personal,
    this.basisLead,
    this.sourceLead,
    this.showPersonal = false,
    this.showJudgment = true,
    this.personalEmpty,
    this.onWatchAd,
    this.onPass,
    this.loading = false,
    this.animated = true,
    super.key,
  });

  /// 구역 본문 자리 skeleton을 찾는 테스트용 키. 구역마다 하나씩 있습니다.
  static const Key sectionSkeletonKey = ValueKey(
    'evidence-sheet.section.skeleton',
  );

  /// 열람 상태.
  final DepthLinkState state;

  /// 시트 제목(`type.title`).
  final String title;

  /// 시트 제목의 IA 슬롯 id(`evidence-sheet.sheet.title`). 있으면 Key와 Semantics
  /// `identifier`로 붙입니다.
  final String? titleSlotId;

  /// 대상 태그 줄 위 간격(`evidenceSheet.target.marginTop`).
  static const double targetGap = Space.s12;

  /// 태그 줄과 대상 문장 사이(`evidenceSheet.target.sentence.marginTop`).
  static const double targetSentenceGap = Space.s8;

  /// 태그 사이(`evidenceSheet.target.tags.gap`).
  static const double targetTagGap = Space.s8;

  /// 대상 문장 줄 수 상한(`evidenceSheet.target.sentence.maxLines`).
  static const int targetMaxLines = 3;

  /// 구역 제목 위 간격(`evidenceSheet.sectionTitle.marginTop`).
  static const double sectionGap = Space.s24;

  /// 대상 태그 줄을 찾는 테스트용 키.
  static const Key targetTagsKey = ValueKey('evidence-sheet.target.tags');

  /// 그 문장을 정한 태그(누를 수 없는 `hanja-tag`). 비면 태그 줄이 없습니다.
  final List<Widget> targetTags;

  /// 대상 문장(`evidence-sheet.target.body`, `type.caption.lg` `text.secondary`,
  /// 일반 글자, 세 줄 말줄임). 없거나 비면 문장 줄이 없습니다.
  final RenderedText? target;

  /// 잠긴 판정 근거의 앞부분(`evidencePreview.basis`). 열렸을 때는 쓰지 않습니다.
  final RenderedText? basisLead;

  /// 잠긴 원전의 앞부분(`evidencePreview.source`). 열렸을 때는 쓰지 않습니다.
  final RenderedText? sourceLead;

  /// 원국표(`saju-pillars`). 표 데이터라 잠기지 않습니다.
  final Widget? pillars;

  /// 판정 근거 본문(`evidence-sheet.basis.body`), 근거마다 한 문단. 잠기면 비어 있습니다.
  final List<RenderedText> basis;

  /// 원전 인용(`evidence-sheet.source.quote`), 근거마다 한 문단. 잠기면 비어 있습니다.
  final List<RenderedText> source;

  /// 내 사주 해석(`evidence-sheet.personal.body`). 잠기면 없습니다.
  final RenderedText? personal;

  /// "내 사주에서는" 구역을 둘지. 사주 표·만세력·대운 표의 용어에서 열었을 때만 true입니다.
  final bool showPersonal;

  /// 판정 근거·원전 구역을 둘지. 표 칸 용어에서 연 시트는 그 칸에 판정 근거가 없으므로 false이고,
  /// 잠겨도 열린 뒤 없을 구역을 약속하지 않습니다(A58).
  final bool showJudgment;

  /// 열렸는데 [personal]이 없을 때(원고 없음) "내 사주에서는" 구역 제목 아래 보일 안내. 없으면
  /// 그 구역을 그리지 않습니다(A22 남은 규칙).
  final String? personalEmpty;

  /// 광고 보고 열기(`locked`).
  final VoidCallback? onWatchAd;

  /// 광고 제거권 링크.
  final VoidCallback? onPass;

  /// true면 구역 본문 자리가 skeleton입니다(응답을 다시 받는 중).
  final bool loading;

  /// false면 처리 중 점이 숨 쉬지 않습니다(golden).
  final bool animated;

  @override
  State<EvidenceSheetBody> createState() => _EvidenceSheetBodyState();
}

class _EvidenceSheetBodyState extends State<EvidenceSheetBody> {
  /// 잠김이 풀리는 것을 본 뒤에는 열림 알림과 나타남을 그립니다.
  bool _justUnlocked = false;

  /// 안내 영역이 사라지는 동안에도 잠겨 있던 모습을 그리려고 마지막 잠김 상태를 기억합니다.
  late DepthLinkState _panelState = widget.state == DepthLinkState.unlocked
      ? DepthLinkState.locked
      : widget.state;

  @override
  void didUpdateWidget(EvidenceSheetBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    final wasLocked = oldWidget.state != DepthLinkState.unlocked;
    final isUnlocked = widget.state == DepthLinkState.unlocked;
    if (!isUnlocked) _panelState = widget.state;
    if (wasLocked && isUnlocked) {
      _justUnlocked = true;
      unawaited(Haptics.light());
    } else if (!isUnlocked) {
      _justUnlocked = false;
    }
  }

  bool get _unlocked => widget.state == DepthLinkState.unlocked;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = context.tokens;
    final pillars = widget.pillars;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 열림 알림은 스크롤해도 뷰포트 밖으로 밀려나지 않게 스크롤 영역 밖 위쪽에 둡니다.
        if (_justUnlocked)
          SilentAnnouncement(
            identifier: SlotIds.evidenceSheetA11yUnlocked,
            label: l10n.evidenceSheetA11yUnlocked,
            role: SemanticsRole.status,
          ),
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  identifier: widget.titleSlotId,
                  child: Text(
                    widget.title,
                    key: widget.titleSlotId == null
                        ? null
                        : ValueKey<String>(widget.titleSlotId!),
                    style: tokens.typography.title.copyWith(
                      color: tokens.colors.textPrimary,
                    ),
                  ),
                ),
                ..._target(context),
                if (pillars != null)
                  Padding(
                    padding: const EdgeInsets.only(top: Space.s12),
                    child: pillars,
                  ),
                if (widget.showJudgment) ...[
                  _section(
                    context,
                    title: l10n.evidenceSheetSectionBasis,
                    texts: widget.basis,
                    titleSlotId: SlotIds.evidenceSheetSectionBasis,
                    slotId: SlotIds.evidenceSheetBasisBody,
                    lockedLines: LockVeilLines.basis,
                    lead: widget.basisLead,
                  ),
                  _section(
                    context,
                    title: l10n.evidenceSheetSectionSource,
                    texts: widget.source,
                    titleSlotId: SlotIds.evidenceSheetSectionSource,
                    slotId: SlotIds.evidenceSheetSourceQuote,
                    lockedLines: LockVeilLines.source,
                    lead: widget.sourceLead,
                    quote: true,
                  ),
                ],
                if (widget.showPersonal)
                  _section(
                    context,
                    title: l10n.evidenceSheetSectionPersonal,
                    texts: [?widget.personal],
                    titleSlotId: SlotIds.evidenceSheetSectionPersonal,
                    slotId: SlotIds.evidenceSheetPersonalBody,
                    lockedLines: LockVeilLines.personal,
                    emptyText: widget.personalEmpty,
                  ),
              ],
            ),
          ),
        ),
        // 안내 영역은 풀릴 때 disappear.seep으로 사라지고, 처음부터 풀려 있으면 없습니다.
        SeepPresence(
          present: !_unlocked,
          child: EvidenceLockPanel(
            state: _panelState,
            onWatchAd: widget.onWatchAd,
            onPass: widget.onPass,
            animated: widget.animated,
          ),
        ),
      ],
    );
  }

  /// 구역 하나: 제목(늘 또렷함) + 본문 문단들. 잠기면 같은 자리에 `lock.veil`, 받는 중이면
  /// skeleton. 열렸는데 문단이 없으면 그리지 않습니다(A22 남은 규칙).
  Widget _section(
    BuildContext context, {
    required String title,
    required List<RenderedText> texts,
    required String titleSlotId,
    required String slotId,
    required int lockedLines,
    RenderedText? lead,
    bool quote = false,
    String? emptyText,
  }) {
    final l10n = AppLocalizations.of(context);
    final tokens = context.tokens;
    final Widget content;
    if (widget.loading) {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionTitle(context, title: title, titleSlotId: titleSlotId),
          const SizedBox(height: Space.s8),
          // 구역 본문(`sentence-block` `body`) 자리의 글줄 두 줄.
          SkeletonBlock(
            key: EvidenceSheetBody.sectionSkeletonKey,
            delay: Duration.zero,
            child: SkeletonTextLines(
              lines: 2,
              style: tokens.typography.sentenceBody,
              animated: widget.animated,
            ),
          ),
        ],
      );
    } else if (_unlocked && texts.isEmpty && emptyText != null) {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionTitle(context, title: title, titleSlotId: titleSlotId),
          const SizedBox(height: Space.s8),
          Text(
            emptyText,
            style: tokens.typography.bodyUi.copyWith(
              color: tokens.colors.textSecondary,
            ),
          ),
        ],
      );
    } else if (_unlocked && texts.isEmpty) {
      return const SizedBox.shrink();
    } else if (!_unlocked) {
      content = LockVeil(
        sectionTitle: title,
        stateLabel: l10n.evidenceSheetA11yLocked,
        lines: lockedLines,
        lead: lead == null || isBlankText(lead) ? null : lead,
        titleSlotId: titleSlotId,
        bodySlotId: slotId,
        a11ySlotId: SlotIds.evidenceSheetA11yLocked,
      );
    } else {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionTitle(context, title: title, titleSlotId: titleSlotId),
          const SizedBox(height: Space.s8),
          for (final (index, text) in texts.indexed)
            Padding(
              // 근거가 여럿이면 문단 사이를 space.12로 띄웁니다(A42).
              padding: EdgeInsets.only(top: index == 0 ? 0 : Space.s12),
              child: _paragraph(text, slotId: slotId, quote: quote),
            ),
        ],
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: EvidenceSheetBody.sectionGap),
      child: _justUnlocked
          ? SeepPresence(present: true, child: content)
          : content,
    );
  }

  /// 시트 위 대상: 제목 아래 [EvidenceSheetBody.targetGap]에 태그 줄(사이
  /// [EvidenceSheetBody.targetTagGap], 넘치면 다음 줄), 그 아래
  /// [EvidenceSheetBody.targetSentenceGap]에 대상 문장. 둘 다 없으면 아무것도
  /// 두지 않습니다.
  List<Widget> _target(BuildContext context) {
    final tokens = context.tokens;
    final tags = widget.targetTags;
    final target = widget.target;
    final sentence = target == null || isBlankText(target)
        ? null
        : plainTextOf(target);
    return [
      if (tags.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: EvidenceSheetBody.targetGap),
          child: Wrap(
            key: EvidenceSheetBody.targetTagsKey,
            spacing: EvidenceSheetBody.targetTagGap,
            runSpacing: EvidenceSheetBody.targetTagGap,
            children: tags,
          ),
        ),
      if (sentence != null)
        Padding(
          padding: EdgeInsets.only(
            top: tags.isEmpty
                ? EvidenceSheetBody.targetGap
                : EvidenceSheetBody.targetSentenceGap,
          ),
          child: KeyedSubtree(
            key: const ValueKey(SlotIds.evidenceSheetTargetBody),
            child: Semantics(
              identifier: SlotIds.evidenceSheetTargetBody,
              child: Text(
                sentence,
                maxLines: EvidenceSheetBody.targetMaxLines,
                overflow: TextOverflow.ellipsis,
                style: tokens.typography.captionLg.copyWith(
                  color: tokens.colors.textSecondary,
                ),
              ),
            ),
          ),
        ),
    ];
  }

  /// 본문 한 문단. [quote]면 원전 인용 상자(`bg.base`, `radius.md`, 안쪽 `space.12`)에 담고
  /// 한자는 `font.family.hanja`(`fontFallback`)로 그립니다.
  Widget _paragraph(
    RenderedText text, {
    required String slotId,
    required bool quote,
  }) {
    final hanjaFamily = context.tokens.typography.hanjaPillar.fontFamily;
    final block = SentenceBlock(
      variant: SentenceBlockVariant.body,
      text: text,
      slotId: slotId,
      // 원전의 한자는 문장 글꼴에 글리프가 없어 한자 글꼴로만 그립니다(한글은 그대로).
      fontFallback: quote && hanjaFamily != null ? [hanjaFamily] : const [],
    );
    if (!quote) {
      return block;
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.tokens.colors.bgBase,
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      child: Padding(padding: const EdgeInsets.all(Space.s12), child: block),
    );
  }

  /// 구역 제목(`sectionTitle`). 열렸을 때와 받는 중에 씁니다(잠기면 `lock.veil`이 그립니다).
  Widget _sectionTitle(
    BuildContext context, {
    required String title,
    required String titleSlotId,
  }) {
    final tokens = context.tokens;
    return KeyedSubtree(
      key: ValueKey(titleSlotId),
      child: Semantics(
        identifier: titleSlotId,
        child: Text(
          title,
          style: tokens.typography.labelMd.copyWith(
            color: tokens.colors.textSecondary,
          ),
        ),
      ),
    );
  }
}
