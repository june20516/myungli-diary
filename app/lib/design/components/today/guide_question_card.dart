import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:myungli_diary/core/api/gen/model/rendered_text.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/action/primary_button.dart';
import 'package:myungli_diary/design/components/component_spec.dart';
import 'package:myungli_diary/design/components/feedback/live_announcement.dart';
import 'package:myungli_diary/design/components/sentence/sentence_block.dart';
import 'package:myungli_diary/design/elements/seal.dart';
import 'package:myungli_diary/design/interaction/motion_prefs.dart';
import 'package:myungli_diary/design/interaction/patterns.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

/// 가이드 질문 카드의 상태(`guide-question-card` `states`).
enum GuideQuestionState {
  /// 그날 일기를 아직 쓰지 않음. 주 버튼(filled)으로 쓰기로 들어갑니다.
  before,

  /// 그날 일기를 씀. 질문 글자가 옅어지고 버튼은 quiet, 그 글자 뒤에 옅은 도장이 놓입니다.
  after,
}

/// 가이드 질문과 쓰기 입구(`guide-question-card`).
///
/// 데이터 조회 없는 순수 컴포넌트입니다. 상태와 문구·동작을 모두 밖에서 받아, 오늘 화면과
/// 계획 4 `day-sheet`·계획 5 `diary-edit`이 같은 카드를 씁니다. 버튼 글자(쓰기/쓴 일기 보기)는
/// 상태에 맞춰 호출하는 쪽이 [actionLabel]로 줍니다.
///
/// [state]가 `before`에서 `after`로 바뀌는 순간(일기를 쓰고 돌아왔을 때)에만 도장이
/// `seal.stamp`로 찍히고, 상태 알림("오늘 일기를 썼어요", `todayGuideWritten`)을 스크린리더에 한 번 보냅니다.
/// 처음부터 `after`로 그릴 때는 움직임도 알림도 없이 도장이 이미 찍혀 있습니다. 동작 줄이기는
/// 패턴의 대체 규칙(투명도만)을 따릅니다. 눌림(`press.ink`)은 [PrimaryButton]이 입힙니다.
///
/// 명세 a11y `role: group`에 해당하는 Flutter 역할이 없어(`SemanticsRole`에 group 없음)
/// 라벨 "질문"을 가진 container 노드로 둡니다.
class GuideQuestionCard extends StatefulWidget {
  /// 카드를 만듭니다.
  ///
  /// [question]은 server가 렌더한 질문 조각, [questionSlotId]·[actionSlotId]는 IA 슬롯 id
  /// (`today.guide.question`·`today.guide.cta` 등)이며 있으면 Semantics
  /// `identifier`로 붙습니다.
  const new({
    required this.state,
    required this.eyebrow,
    required this.question,
    required this.actionLabel,
    required this.onAction,
    this.questionSlotId,
    this.actionSlotId,
    super.key,
  });

  /// 명세 대조용 요약.
  static const ComponentSpec spec = ComponentSpec('guide-question-card', {}, {
    'before',
    'after',
  });

  /// 도장 층(버튼 글자 뒤)을 찾는 테스트용 키.
  static const Key sealLayerKey = ValueKey('guide-question-card-seal');

  /// 상태.
  final GuideQuestionState state;

  /// 질문 위 작은 머리글("오늘의 질문").
  final String eyebrow;

  /// 질문 문장(server가 렌더한 조각).
  final RenderedText question;

  /// 버튼 글자.
  final String actionLabel;

  /// 버튼을 눌렀을 때.
  final VoidCallback onAction;

  /// 질문이 채우는 IA 슬롯 id.
  final String? questionSlotId;

  /// 버튼이 채우는 IA 슬롯 id.
  final String? actionSlotId;

  /// 버튼을 찾는 테스트용 키(상태가 바뀌어도 같은 버튼 State를 쓰는지 확인).
  static const Key buttonKey = ValueKey('guide-question-card-button');

  @override
  State<GuideQuestionCard> createState() => _GuideQuestionCardState();
}

class _GuideQuestionCardState extends State<GuideQuestionCard>
    with TickerProviderStateMixin {
  // 처음부터 after면 이미 찍힌 상태(1)로 시작해 움직이지 않습니다.
  late final AnimationController _stamp;
  late final AnimationController _erase;

  // 도장 층을 트리에 둘지. after이거나, before로 돌아오며 지워지는 동안 true입니다.
  late bool _sealShown;

  // 지우는 중인지(true면 erase, 아니면 stamp 값을 그립니다).
  bool _erasing = false;

  // before에서 after로 바뀐 카드만 상태 알림을 보냅니다. 처음부터 after면 보내지 않습니다.
  bool _announce = false;

  @override
  void initState() {
    super.initState();
    final after = widget.state == GuideQuestionState.after;
    _sealShown = after;
    _stamp = AnimationController(
      vsync: this,
      duration: InteractionPattern.sealStamp.duration,
      value: after ? 1 : 0,
    );
    _erase = AnimationController(
      vsync: this,
      duration: InteractionPattern.sealErase.duration,
    )..addStatusListener(_onEraseStatus);
  }

  void _onEraseStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;
    setState(() {
      _sealShown = false;
      _erasing = false;
    });
  }

  @override
  void didUpdateWidget(GuideQuestionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state == oldWidget.state) return;
    if (widget.state == GuideQuestionState.after) {
      _announce = true;
      _sealShown = true;
      _erasing = false;
      _erase.stop();
      _stamp.forward(from: 0);
    } else {
      _announce = false;
      _erasing = true;
      _stamp.stop();
      _erase.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _stamp.dispose();
    _erase.dispose();
    super.dispose();
  }

  Widget _sealLayer(BuildContext context, AppLocalizations l10n) {
    const seal = Seal(size: SealSize.card, variant: SealVariant.soft);
    final prefs = MotionPrefs.of(context);
    final shown = _erasing
        ? animate(
            InteractionPattern.sealErase,
            t: _erase,
            prefs: prefs,
            child: seal,
          )
        : animate(
            InteractionPattern.sealStamp,
            t: _stamp,
            prefs: prefs,
            child: seal,
          );
    final written = l10n.todayGuideWritten;
    // 도장은 장식이라 눈에 보이게만 두고, `todayGuideWritten`만 상태로 읽습니다.
    // 지워지는 동안(before)에는 상태를 읽지 않습니다.
    final announced = _erasing
        ? ExcludeSemantics(child: shown)
        : _announce
        ? Semantics(
            container: true,
            child: LiveAnnouncement(
              label: written,
              role: SemanticsRole.status,
              child: shown,
            ),
          )
        : Semantics(
            container: true,
            role: SemanticsRole.status,
            label: written,
            child: ExcludeSemantics(child: shown),
          );
    return KeyedSubtree(
      key: GuideQuestionCard.sealLayerKey,
      child: IgnorePointer(child: announced),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final l10n = AppLocalizations.of(context);
    final after = widget.state == GuideQuestionState.after;
    final question = SentenceBlock(
      variant: SentenceBlockVariant.card,
      text: widget.question,
      slotId: widget.questionSlotId,
      color: after ? colors.textSecondary : null,
    );
    final button = PrimaryButton(
      key: GuideQuestionCard.buttonKey,
      label: widget.actionLabel,
      onPressed: widget.onAction,
      variant: after ? PrimaryButtonVariant.quiet : PrimaryButtonVariant.filled,
      labelColor: after ? colors.sealOnSoft : null,
      identifier: widget.actionSlotId,
    );
    // 버튼은 상태와 관계없이 같은 자리(Stack의 키 붙은 자식)에 두어 눌림·포커스를 지키고,
    // 도장 층만 넣고 뺍니다.
    final action = Stack(
      alignment: Alignment.center,
      children: [if (_sealShown) _sealLayer(context, l10n), button],
    );
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: l10n.todayGuideLabel,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.bgSheet,
          borderRadius: const BorderRadius.all(Radius.circular(Radii.lg)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(Space.s20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.eyebrow,
                style: tokens.typography.captionMd.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: Space.s8),
              question,
              const SizedBox(height: Space.s16),
              action,
            ],
          ),
        ),
      ),
    );
  }
}
