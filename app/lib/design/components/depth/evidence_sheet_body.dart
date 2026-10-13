import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:myungli_diary/core/api/gen/model/rendered_text.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/depth/evidence_lock_panel.dart';
import 'package:myungli_diary/design/components/feedback/live_announcement.dart';
import 'package:myungli_diary/design/components/feedback/seep_presence.dart';
import 'package:myungli_diary/design/components/sentence/depth_link.dart';
import 'package:myungli_diary/design/components/sentence/sentence_block.dart';
import 'package:myungli_diary/design/elements/lock_veil.dart';
import 'package:myungli_diary/design/interaction/haptics.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

/// 근거 시트의 내용(`depth-link.evidenceSheet`). 시트 틀(`sheet` `full`) 안에 놓습니다.
///
/// 제목 → 원국표 → 판정 근거 → 원전 → 내 사주에서는 순서이고, 제목과 원국표는 늘 보입니다.
/// 세 구역([showPersonal]이 false면 두 구역)은 [state]가 [DepthLinkState.unlocked]이면
/// 본문, 아니면 같은 자리에 `lock.veil`로 그립니다. 구역 제목은 잠겨도 또렷합니다.
/// 잠겼을 때는 시트 아래에 [EvidenceLockPanel]이 고정됩니다.
///
/// 잠긴 구역의 본문은 server가 보내지 않으므로 [basis]·[source]·[personal]은 `null`이어도
/// 됩니다. 이 내용 높이는 부모가 정해 준 높이 안에서 스스로 스크롤합니다.
///
/// 잠김이 풀리는 순간(`locked`·`lockedNoAd`·`unlocking` → `unlocked`)에는 안내 영역이
/// `disappear.seep`으로 사라지고 본문이 `appear.seep`으로 나타나며 light 햅틱과 "열렸다"는
/// 알림이 한 번 옵니다. 그 사이의 skeleton 단계와 확인 시간 초과 toast는 화면 쪽 흐름의
/// 몫입니다. 처음부터 권한이 있으면 움직임도 햅틱도 알림도 없습니다.
class EvidenceSheetBody extends StatefulWidget {
  /// 근거 시트 내용을 만듭니다.
  const new({
    required this.state,
    required this.title,
    this.pillars,
    this.basis,
    this.source,
    this.personal,
    this.showPersonal = false,
    this.onWatchAd,
    this.onPass,
    this.animated = true,
    super.key,
  });

  /// 열람 상태.
  final DepthLinkState state;

  /// 시트 제목(`type.title`).
  final String title;

  /// 원국표(`saju-pillars`). 표 데이터라 잠기지 않습니다.
  final Widget? pillars;

  /// 판정 근거 본문(`evidence-sheet.basis.body`). 잠기면 없습니다.
  final RenderedText? basis;

  /// 원전 인용(`evidence-sheet.source.quote`). 잠기면 없습니다.
  final RenderedText? source;

  /// 내 사주 해석(`evidence-sheet.personal.body`). 잠기면 없습니다.
  final RenderedText? personal;

  /// "내 사주에서는" 구역을 둘지. 사주 표·만세력·대운 표의 용어에서 열었을 때만 true입니다.
  final bool showPersonal;

  /// 광고 보고 열기(`locked`).
  final VoidCallback? onWatchAd;

  /// 광고 제거권 링크.
  final VoidCallback? onPass;

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
          // 레이아웃 높이는 0이지만 알림 노드는 1x1 영역을 가져 TalkBack이 놓치지 않습니다.
          SizedBox(
            height: 0,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  width: 1,
                  height: 1,
                  child: LiveAnnouncement(
                    identifier: SlotIds.evidenceSheetA11yUnlocked,
                    label: l10n.evidenceSheetA11yUnlocked,
                    role: SemanticsRole.status,
                    child: const SizedBox.shrink(),
                  ),
                ),
              ],
            ),
          ),
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.title,
                  style: tokens.typography.title.copyWith(
                    color: tokens.colors.textPrimary,
                  ),
                ),
                if (pillars != null)
                  Padding(
                    padding: const EdgeInsets.only(top: Space.s12),
                    child: pillars,
                  ),
                _section(
                  context,
                  title: l10n.evidenceSheetSectionBasis,
                  text: widget.basis,
                  titleSlotId: SlotIds.evidenceSheetSectionBasis,
                  slotId: SlotIds.evidenceSheetBasisBody,
                ),
                _section(
                  context,
                  title: l10n.evidenceSheetSectionSource,
                  text: widget.source,
                  titleSlotId: SlotIds.evidenceSheetSectionSource,
                  slotId: SlotIds.evidenceSheetSourceQuote,
                  quote: true,
                ),
                if (widget.showPersonal)
                  _section(
                    context,
                    title: l10n.evidenceSheetSectionPersonal,
                    text: widget.personal,
                    titleSlotId: SlotIds.evidenceSheetSectionPersonal,
                    slotId: SlotIds.evidenceSheetPersonalBody,
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

  /// 구역 하나: 제목(늘 또렷함) + 본문. 잠기면 같은 자리에 `lock.veil`.
  Widget _section(
    BuildContext context, {
    required String title,
    required RenderedText? text,
    required String titleSlotId,
    required String slotId,
    bool quote = false,
  }) {
    final l10n = AppLocalizations.of(context);
    final tokens = context.tokens;
    final Widget content;
    assert(
      !_unlocked || text != null,
      '권한이 있는데($slotId) 본문이 없습니다. server가 잠기지 않은 구역 본문을 보내야 합니다.',
    );
    if (!_unlocked || text == null) {
      content = LockVeil(
        title: title,
        semanticLabel: '$title, ${l10n.evidenceSheetA11yLocked}',
        titleSlotId: titleSlotId,
        bodySlotId: slotId,
        a11ySlotId: SlotIds.evidenceSheetA11yLocked,
      );
    } else {
      final block = SentenceBlock(
        variant: SentenceBlockVariant.body,
        text: text,
        slotId: slotId,
      );
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          KeyedSubtree(
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
          ),
          const SizedBox(height: Space.s8),
          if (quote)
            DecoratedBox(
              decoration: BoxDecoration(
                color: tokens.colors.bgBase,
                borderRadius: BorderRadius.circular(Radii.md),
              ),
              child: Padding(
                padding: const EdgeInsets.all(Space.s12),
                child: block,
              ),
            )
          else
            block,
        ],
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: Space.s20),
      child: _justUnlocked
          ? SeepPresence(present: true, child: content)
          : content,
    );
  }
}
