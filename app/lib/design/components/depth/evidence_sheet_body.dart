import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:myungli_diary/core/api/gen/model/rendered_text.dart';
import 'package:myungli_diary/core/api/gen/model/segment.dart';
import 'package:myungli_diary/core/api/rendered_text_plain.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/depth/evidence_lock_panel.dart';
import 'package:myungli_diary/design/components/feedback/live_announcement.dart';
import 'package:myungli_diary/design/components/feedback/seep_presence.dart';
import 'package:myungli_diary/design/components/feedback/skeleton.dart';
import 'package:myungli_diary/design/components/sentence/depth_link.dart';
import 'package:myungli_diary/design/components/sentence/rendered_text_view.dart';
import 'package:myungli_diary/design/components/sentence/sentence_block.dart';
import 'package:myungli_diary/design/elements/app_icon.dart';
import 'package:myungli_diary/design/elements/lock_veil.dart';
import 'package:myungli_diary/design/elements/unlock_mark.dart';
import 'package:myungli_diary/design/interaction/haptics.dart';
import 'package:myungli_diary/design/interaction/patterns.dart';
import 'package:myungli_diary/design/interaction/unlock_glint.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';
import 'package:phosphor_glyphs/phosphor_glyphs.dart';

/// 근거 시트의 내용(`depth-link.evidenceSheet`). 시트 틀(`sheet` `full`) 안에 놓습니다.
///
/// 제목 → 대상(그 문장을 정한 태그 줄과 대상 문장) → 원국표 → 판정 근거 → 원전 → 내 사주에서는
/// 순서이고, 제목, 대상, 원국표는 늘 보입니다(잠기지 않음). 구역 제목 위는 `space.24`입니다.
/// 표 칸 용어에서 연 시트([showJudgment]가 false)는 내 사주에서는 구역 하나입니다.
/// 세 구역([showPersonal]이 false면 두 구역)은 [state]가 [DepthLinkState.unlocked]이면
/// 본문, 아니면 같은 자리에 `lock.veil`로 그립니다. 구역 제목은 잠겨도 또렷합니다.
/// 잠겼을 때는 시트 아래에 [EvidenceLockPanel]이 고정됩니다.
///
/// 판정 근거 구역은 근거마다 문단 하나씩([basis]의 순서)이고 문단 사이는 `space.12`입니다(A42).
/// 원전 구역은 근거마다 상자 없이 뜻, 들여쓴 원문, 출처 줄 묶음이고 묶음 사이는 `space.16`입니다
/// (V113, D118 ③, [source]). 잠긴 구역의 본문은 server가
/// 보내지 않고, 잠겼을 때는 넘어온 문장이 있어도 그리지 않습니다(D60). 열렸는데 문장이 없는
/// 구역(원고가 없어 server가 생략)은 제목도 자리도 그리지 않습니다(A22 남은 규칙, `depth-link`
/// 규칙 2.3.0). 잠겼을 때의 `lock.veil`은 본문을 내려받지 않은 상태라 그대로 그립니다. 이 내용
/// 높이는 부모가 정해 준 높이 안에서 스스로 스크롤합니다.
///
/// 잠긴 구역은 `lock.veil` G1입니다: server가 준 앞부분([basisLead], [sourceLead])이 있으면
/// 또렷하게 두고 뒤는 흐린 자리값이며, 줄 수는 판정 근거 3, 원전 2, 내 사주에서는 3입니다
/// ([LockVeilLines]). 원전은 원전이 여럿이어도 veil 하나이고 앞부분은 첫 원전의 뜻 줄만 씁니다
/// (원문과 출처 줄은 그리지 않음, V113). "내 사주에서는" 구역은 앞부분이 오지 않아 자리값만입니다.
///
/// 열린 표시(D118, V112): `unlocked`이고 받는 중이 아니면 제목 줄 오른쪽에 열림 꼬리표
/// ([unlockTag], 넘치면 제목 아래)를 두고, 구역 제목과 본문에 `unlock.glint`가 한 박자로
/// 지나갑니다([UnlockGlintScope]). 시트 제목, 꼬리표, 대상, 원국표, 빈 해석 안내는 반짝이지
/// 않습니다. 동작 줄이기면 반짝임 대신 `unlock.mark`(구역 제목 그라데이션 글자와 구역 왼쪽 밖
/// 세로선)입니다.
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
    this.unlockTag,
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

  /// 판정 근거 문단 사이(`evidenceSheet.basis.repeat.gap`, A42).
  static const double basisGap = Space.s12;

  /// 원전 묶음 사이(`evidenceSheet.source.repeat.gap`, V113).
  static const double sourceGap = Space.s16;

  /// 원문과 출처 줄의 들여쓰기(`source.quote.paddingStart`, `source.cite.paddingStart`).
  static const double sourceIndent = Space.s8;

  /// 원전 줄 사이(`source.quote.marginTop`, `source.cite.marginTop`).
  static const double sourceLineGap = Space.s4;

  /// 열림 꼬리표 높이(`unlockTag.height`, px).
  static const double unlockTagHeight = 24;

  /// 열림 꼬리표 좌우 안쪽(`unlockTag.paddingStart`, `paddingEnd`).
  static const double unlockTagPadding = Space.s8;

  /// 제목과 열림 꼬리표 사이, 넘쳤을 때 제목 아래(`unlockTag.gapFromTitle`).
  static const double unlockTagGap = Space.s8;

  /// 열림 꼬리표 시계와 글자 사이(`unlockTag.icon.gap`).
  static const double unlockTagIconGap = Space.s4;

  /// 열림 꼬리표 그라데이션 테두리 굵기(`unlockTag.border.width`, px).
  static const double unlockTagBorderWidth = 1;

  /// 열림 꼬리표 시계 글리프(`unlockTag.icon`, `clock`).
  static const AppGlyph unlockTagGlyph = AppGlyph(
    light: PhosphorIconsLight.clock,
    regular: PhosphorIconsRegular.clock,
  );

  /// 원전 뜻 줄을 찾는 테스트용 키. 원전마다 하나씩 있습니다.
  static const Key sourceMeaningKey = ValueKey('evidence-sheet.source.meaning');

  /// 원전 원문 줄을 찾는 테스트용 키.
  static const Key sourceQuoteKey = ValueKey(
    'evidence-sheet.source.quote-line',
  );

  /// 원전 출처 줄을 찾는 테스트용 키.
  static const Key sourceCiteKey = ValueKey('evidence-sheet.source.cite');

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

  /// 원전(`evidence-sheet.source.quote`), 원전 키(`sourceRef`)마다 하나(같은 원전은 부르는 쪽이
  /// 처음 한 번만 넘김, #924). 문장은 줄바꿈으로 뜻, 원문, 출처를
  /// 나눈 원고입니다(`evidence.source` structure). 잠기면 비어 있습니다.
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

  /// 열림 꼬리표 문구(`evidence-sheet.unlock.until`). 열린 이유와 끝 시각으로 부르는 쪽이
  /// 고릅니다. `unlocked`이고 받는 중이 아닐 때만 그리고, 없으면 꼬리표가 없습니다.
  final String? unlockTag;

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

  /// 열린 표시(꼬리표, 반짝임)를 그릴지. 응답을 다시 받는 중에는 그리지 않습니다.
  bool get _showsUnlocked => _unlocked && !widget.loading;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
          // unlock.mark 세로선은 구역 왼쪽 밖(시트 안쪽 여백 안)에 그리므로, 스크롤 영역은 위아래만
          // 자릅니다.
          child: ClipRect(
            clipper: const _HorizontalBleed(Space.s24),
            // 박자는 잠겨 있어도 두어(대상이 없으면 돌지 않음) 열릴 때 스크롤 자리가 그대로입니다.
            child: UnlockGlintScope(
              // 열리는 순간이면 내용이 appear.seep으로 다 나타난 뒤 첫 반짝임입니다.
              firstDelay: _justUnlocked
                  ? InteractionPattern.appearSeep.duration
                  : Duration.zero,
              child: Builder(builder: _scrollContent),
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

  /// 스크롤하는 내용: 제목 줄 → 대상 → 원국표 → 구역들. [context]는 반짝임 박자 아래입니다.
  Widget _scrollContent(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final pillars = widget.pillars;
    return SingleChildScrollView(
      clipBehavior: Clip.none,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _titleLine(context),
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
    );
  }

  /// 시트 제목. 열렸으면 같은 줄 오른쪽 끝에 열림 꼬리표를 두고(제목 첫 줄 세로 가운데),
  /// 한 줄에 들어가지 않으면 제목 아래 [EvidenceSheetBody.unlockTagGap]에 왼쪽 맞춤으로
  /// 내립니다. 스크린리더는 제목 다음에 꼬리표를 읽습니다.
  Widget _titleLine(BuildContext context) {
    final tokens = context.tokens;
    final titleSlotId = widget.titleSlotId;
    final title = Semantics(
      identifier: titleSlotId,
      child: Text(
        widget.title,
        key: titleSlotId == null ? null : ValueKey<String>(titleSlotId),
        style: tokens.typography.title.copyWith(
          color: tokens.colors.textPrimary,
        ),
      ),
    );
    final tag = widget.unlockTag;
    if (!_showsUnlocked || tag == null) {
      return title;
    }
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: EvidenceSheetBody.unlockTagGap,
      runSpacing: EvidenceSheetBody.unlockTagGap,
      children: [
        title,
        _UnlockTag(label: tag),
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
      // 빈 해석 안내는 반짝이지 않고 구역 제목만 대상입니다.
      content = _markSection(
        context,
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _glintTitle(
              context,
              _sectionTitle(context, title: title, titleSlotId: titleSlotId),
            ),
            const SizedBox(height: Space.s8),
            Text(
              emptyText,
              style: tokens.typography.bodyUi.copyWith(
                color: tokens.colors.textSecondary,
              ),
            ),
          ],
        ),
      );
    } else if (_unlocked && texts.isEmpty) {
      return const SizedBox.shrink();
    } else if (!_unlocked) {
      content = LockVeil(
        sectionTitle: title,
        stateLabel: l10n.evidenceSheetA11yLocked,
        lines: lockedLines,
        lead: quote ? _firstLine(lead) : _clearLead(lead),
        fontFallback: quote ? _quoteFontFallback(context) : const [],
        titleSlotId: titleSlotId,
        bodySlotId: slotId,
        a11ySlotId: SlotIds.evidenceSheetA11yLocked,
      );
    } else {
      content = _markSection(
        context,
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _glintTitle(
              context,
              _sectionTitle(context, title: title, titleSlotId: titleSlotId),
            ),
            const SizedBox(height: Space.s8),
            for (final (index, text) in texts.indexed)
              Padding(
                // 판정 근거 문단 사이는 space.12(A42), 원전 묶음 사이는 space.16(V113)입니다.
                padding: EdgeInsets.only(
                  top: index == 0
                      ? 0
                      : quote
                      ? EvidenceSheetBody.sourceGap
                      : EvidenceSheetBody.basisGap,
                ),
                child: _glintBody(
                  context,
                  quote
                      ? _sourceItem(context, text, slotId: slotId)
                      : SentenceBlock(
                          variant: SentenceBlockVariant.body,
                          text: text,
                          slotId: slotId,
                        ),
                ),
              ),
          ],
        ),
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

  /// 원전(열린 줄과 잠긴 앞부분)의 대체 글꼴(`source.fontFallback`). 한자는 문장 글꼴에
  /// 글리프가 없어 `font.family.hanja`로만 그립니다(한글은 그대로).
  List<String> _quoteFontFallback(BuildContext context) {
    final hanjaFamily = context.tokens.typography.hanjaPillar.fontFamily;
    return hanjaFamily == null ? const [] : [hanjaFamily];
  }

  /// 잠긴 구역의 또렷한 앞부분. 비었으면 자리값만입니다.
  static RenderedText? _clearLead(RenderedText? lead) =>
      lead == null || isBlankText(lead) ? null : lead;

  /// 잠긴 원전의 앞부분: 첫 원전 뜻 줄만 씁니다(원문과 출처 줄은 그리지 않음, V113).
  static RenderedText? _firstLine(RenderedText? lead) =>
      lead == null ? null : _clearLead(linesOf(lead).first);

  /// 원전 하나(V113): 뜻(`type.sentence.body` 본문색) → 원문(`type.body.ui`
  /// `text.secondary`) → 출처(`type.caption.md` `text.secondary`).
  ///
  /// 원문과 출처는 [EvidenceSheetBody.sourceIndent] 들여쓰고 줄 위
  /// [EvidenceSheetBody.sourceLineGap]입니다. 줄은 원고의 줄바꿈 순서(뜻, 원문, 출처)이고
  /// 비어 있는 줄은 그리지 않습니다. 셋째 줄 뒤에 줄이 더 오면 출처에 이어 붙입니다. 한자는
  /// 세 줄 모두 `font.family.hanja`로 그립니다.
  Widget _sourceItem(
    BuildContext context,
    RenderedText text, {
    required String slotId,
  }) {
    final tokens = context.tokens;
    final fallback = _quoteFontFallback(context);
    final lines = linesOf(text);
    final rest = lines.skip(2).toList();
    final meaning = _clearLead(lines.first);
    final quote = lines.length > 1 ? _clearLead(lines[1]) : null;
    final cite = _clearLead(
      RenderedText(
        segments: [
          for (final (index, line) in rest.indexed) ...[
            if (index > 0) Segment(text: '\n'),
            ...line.segments,
          ],
        ],
      ),
    );
    TextStyle styleOf(TextStyle base, Color color) => base.copyWith(
      color: color,
      fontFamilyFallback: [...fallback, ...?base.fontFamilyFallback],
    );
    final children = <Widget>[
      if (meaning != null)
        KeyedSubtree(
          key: EvidenceSheetBody.sourceMeaningKey,
          child: SentenceBlock(
            variant: SentenceBlockVariant.body,
            text: meaning,
            fontFallback: fallback,
          ),
        ),
      if (quote != null)
        _sourceLine(
          key: EvidenceSheetBody.sourceQuoteKey,
          first: meaning == null,
          child: RenderedTextView(
            text: quote,
            style: styleOf(
              tokens.typography.bodyUi,
              tokens.colors.textSecondary,
            ),
          ),
        ),
      if (cite != null)
        _sourceLine(
          key: EvidenceSheetBody.sourceCiteKey,
          first: meaning == null && quote == null,
          child: RenderedTextView(
            text: cite,
            style: styleOf(
              tokens.typography.captionMd,
              tokens.colors.textSecondary,
            ),
          ),
        ),
    ];
    return KeyedSubtree(
      key: ValueKey(slotId),
      child: Semantics(
        identifier: slotId,
        container: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }

  /// 원전의 원문, 출처 줄: 들여쓰고 앞 줄과 [EvidenceSheetBody.sourceLineGap]를 띄웁니다.
  /// 묶음의 첫 줄([first])이면 위를 띄우지 않습니다.
  Widget _sourceLine({
    required Key key,
    required bool first,
    required Widget child,
  }) => Padding(
    key: key,
    padding: EdgeInsetsDirectional.only(
      start: EvidenceSheetBody.sourceIndent,
      top: first ? 0 : EvidenceSheetBody.sourceLineGap,
    ),
    child: child,
  );

  /// 반짝임 대상 구역 제목. 동작 줄이기면 그라데이션 글자(`unlock.mark` `title`)입니다.
  Widget _glintTitle(BuildContext context, Widget title) {
    if (!_showsUnlocked) return title;
    return UnlockGlintScope.replacedOf(context)
        ? UnlockMarkTitle(child: title)
        : UnlockGlint(child: title);
  }

  /// 반짝임 대상 본문. 동작 줄이기면 그대로입니다(세로선은 구역이 그림).
  Widget _glintBody(BuildContext context, Widget body) {
    if (!_showsUnlocked || UnlockGlintScope.replacedOf(context)) return body;
    return UnlockGlint(child: body);
  }

  /// 동작 줄이기면 구역(제목과 본문) 왼쪽 밖에 `unlock.mark` 세로선을 둡니다.
  Widget _markSection(BuildContext context, Widget section) {
    if (!_showsUnlocked || !UnlockGlintScope.replacedOf(context)) {
      return section;
    }
    return UnlockMarkRule(child: section);
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

/// 열림 꼬리표(`evidenceSheet.unlockTag`, V112): 높이 24 알약, `bg.sheet` 바탕에 1px
/// `gradient.unlocked` 테두리, 앞에 장식 시계(`clock` Regular, 옆 글자 크기,
/// `text.secondary`)와 `space.4`, 글자 `type.caption.md` `text.secondary` 한 줄.
/// 누를 수 없고 반짝이지 않습니다. 스크린리더는 글자만 읽습니다.
class _UnlockTag extends StatelessWidget {
  const new({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final style = tokens.typography.captionMd.copyWith(
      color: tokens.colors.textSecondary,
    );
    const pill = BorderRadius.all(Radius.circular(Radii.full));
    const border = EvidenceSheetBody.unlockTagBorderWidth;
    return KeyedSubtree(
      key: const ValueKey(SlotIds.evidenceSheetUnlockUntil),
      child: Semantics(
        identifier: SlotIds.evidenceSheetUnlockUntil,
        // 바깥 그라데이션이 안쪽 바탕 둘레로 1px 테두리가 됩니다.
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: tokens.gradients.unlocked,
            borderRadius: pill,
          ),
          child: Padding(
            padding: const EdgeInsets.all(border),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: tokens.colors.bgSheet,
                borderRadius: pill,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: EvidenceSheetBody.unlockTagHeight - border * 2,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: EvidenceSheetBody.unlockTagPadding,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: EvidenceSheetBody.unlockTagIconGap,
                    children: [
                      ExcludeSemantics(
                        child: AppIcon(
                          EvidenceSheetBody.unlockTagGlyph,
                          size: AppIconSize.adjacentText(style.fontSize ?? 13),
                          weight: AppIconWeight.regular,
                          color: tokens.colors.textSecondary,
                          scalesWithText: true,
                        ),
                      ),
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: style,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 위아래는 제 크기에서 자르고 좌우는 [bleed]만큼 넓혀 자릅니다(`unlock.mark` 세로선 자리).
class _HorizontalBleed extends CustomClipper<Rect> {
  const new(this.bleed);

  final double bleed;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTRB(-bleed, 0, size.width + bleed, size.height);

  @override
  bool shouldReclip(_HorizontalBleed oldClipper) => bleed != oldClipper.bleed;
}
