import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsRole;
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:myungli_diary/core/api/gen/model/rendered_text.dart';
import 'package:myungli_diary/core/api/rendered_text_plain.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/component_spec.dart';
import 'package:myungli_diary/design/components/feedback/live_announcement.dart';
import 'package:myungli_diary/design/components/feedback/skeleton.dart';
import 'package:myungli_diary/design/components/sentence/hanja_tag.dart';
import 'package:myungli_diary/design/elements/app_icon.dart';
import 'package:myungli_diary/design/elements/keyboard_dismiss.dart';
import 'package:myungli_diary/design/elements/seal.dart';
import 'package:myungli_diary/design/interaction/haptics.dart';
import 'package:myungli_diary/design/interaction/motion_prefs.dart';
import 'package:myungli_diary/design/interaction/patterns.dart';
import 'package:myungli_diary/design/text/line_height.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';
import 'package:phosphor_glyphs/phosphor_glyphs.dart';

const AppGlyph _arrowsClockwise = AppGlyph(
  light: PhosphorIconsLight.arrowsClockwise,
  regular: PhosphorIconsRegular.arrowsClockwise,
);

const AppGlyph _x = AppGlyph(
  light: PhosphorIconsLight.x,
  regular: PhosphorIconsRegular.x,
);

const AppGlyph _chatTeardropDots = AppGlyph(
  light: PhosphorIconsLight.chatTeardropDots,
  regular: PhosphorIconsRegular.chatTeardropDots,
);

/// [DiaryEditor] 변형(`diary-editor` `variants`).
enum DiaryEditorVariant {
  /// 쓰기·고치기.
  edit,

  /// 보기(`diary-view`): 도장이 찍힌 채, 아래 대표 태그(`hanja-tag`).
  view,
}

/// 저장 순간 동작을 [DiaryEditor]에 시키는 손잡이. 화면이 하나 만들어 `edit`에 넘깁니다.
class DiaryEditorController {
  _DiaryEditorState? _state;

  /// 저장 순서(`motion.saveSequence`)의 종이 쪽 단계를 돌립니다: 종이 맨 아래(도장 자리)로
  /// 스크롤 → 날짜 도장 찍힘 + 햅틱 light → 대표 태그(`hanja-tag` `default`) 스밈. 끝나면
  /// 완료됩니다. 버튼 숨쉬기와 toast는 화면 몫입니다. 편집기가 화면에 없으면 바로 끝납니다.
  Future<void> playSaveSequence(List<HanjaTag> tags) =>
      _state?._playSaveSequence(tags) ?? Future<void>.value();
}

/// 일기 종이(`diary-editor`, `surface.paper`): (보기만) 날짜, 오늘의 질문(있으면), 본문.
///
/// 질문은 종이 안 맨 위의 인용형(왼쪽 3px `action.primary` 선, 안쪽 `space.12`,
/// `type.sentence.body` 크기 14 `text.secondary`)이고 본문은 그 아래 `space.16`입니다(V82,
/// V102). 쓰기에서는 날짜를 종이 위 `date-block`이 맡아 종이 안에 그리지 않고, 질문 오른쪽에
/// 질문 바꾸기와 떼기를 둘 수 있습니다. 질문을 떼면 그 자리가 권유 줄(`detached`)로 바뀝니다.
/// 본문에 초점이 있는 동안 키보드 위 내리기 버튼을 띄우고, 종이 밖을 누르면 초점을 풉니다
/// (`focused`, V83, F-013).
///
/// 종이 아래 끝에 64px 도장 자리를 쓰는 중에도 늘 비워 두어, 글이 길어도 도장이 글을 덮지
/// 않습니다. 해시태그를 쓰는 입력은 없습니다(태그는 저장할 때 엔진이 붙임). 대표 태그는 종이
/// 아래에 놓입니다.
class DiaryEditor extends StatefulWidget {
  /// 쓰기·고치기 종이. 본문은 [controller]가 쥐고, [maxLength](계약 10000자)를 넘게 칠 수
  /// 없습니다. [placeholder]는 빈 본문 안내이자 본문 칸의 스크린리더 이름입니다.
  /// [onSwapQuestion]이 있으면 질문 오른쪽에 질문 바꾸기를 둡니다(그날 후보가 둘 이상인 새
  /// 일기, A115). [onDetachQuestion]이 있으면 그 뒤에 떼기 `x`를 둡니다(D116).
  /// [questionDetached]면 질문 대신 권유 줄을 그리고 누르면 [onAttachQuestion]입니다. 질문
  /// 자리는 [question]이 있을 때만 있습니다(뗀 상태에서도 붙일 질문으로 넘김, `whenNoQuestion`).
  /// [focusNode]는 본문 초점이고, 없으면 종이가 만듭니다.
  const new edit({
    required this.date,
    required TextEditingController this.controller,
    this.question,
    this.placeholder,
    this.maxLength = defaultMaxLength,
    this.onChanged,
    this.onSwapQuestion,
    this.onDetachQuestion,
    this.onAttachQuestion,
    this.questionDetached = false,
    this.focusNode,
    this.editorController,
    this.questionSlotId,
    this.removeSlotId,
    this.attachSlotId,
    this.bodySlotId,
    super.key,
  }) : variant = DiaryEditorVariant.edit,
       body = null,
       tags = const [];

  /// 보기 종이. 도장이 찍힌 채이고 아래에 [tags]를 둡니다.
  const new view({
    required this.date,
    required String this.body,
    this.question,
    this.tags = const [],
    this.questionSlotId,
    this.bodySlotId,
    super.key,
  }) : variant = DiaryEditorVariant.view,
       controller = null,
       placeholder = null,
       maxLength = defaultMaxLength,
       onChanged = null,
       onSwapQuestion = null,
       onDetachQuestion = null,
       onAttachQuestion = null,
       questionDetached = false,
       removeSlotId = null,
       attachSlotId = null,
       focusNode = null,
       editorController = null;

  /// 명세 대조용 요약.
  static const ComponentSpec spec = ComponentSpec(
    'diary-editor',
    {'edit', 'view'},
    {'loading', 'focused', 'saving', 'saved'},
  );

  /// 뼈 `question` 줄 수(`states.loading.skeleton`, `edit`에만).
  static const int skeletonQuestionLines = 2;

  /// 뼈 `body` 줄 수(`states.loading.skeleton`).
  static const int skeletonBodyLines = 5;

  /// 불러오는 중 뼈: 종이 카드(안쪽 [Space.s16]) 안에 `edit`이면 질문 글줄 두 줄과
  /// [Space.s12], 본문 글줄 다섯 줄(`type.sentence.body`), 아래 도장 자리 높이.
  static Widget skeleton({
    required DiaryEditorVariant variant,
    int index = 0,
    bool animated = true,
  }) => Builder(
    builder: (context) {
      final typography = context.tokens.typography;
      final edit = variant == DiaryEditorVariant.edit;
      return SkeletonCard(
        padding: const EdgeInsets.all(Space.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (edit) ...[
              SkeletonTextLines(
                lines: skeletonQuestionLines,
                style: typography.captionLg,
                index: index,
                animated: animated,
              ),
              const SizedBox(height: Space.s12),
            ],
            SkeletonTextLines(
              lines: skeletonBodyLines,
              style: typography.sentenceBody,
              index: index + (edit ? skeletonQuestionLines : 0),
              animated: animated,
            ),
            const SizedBox(height: Space.s12),
            SizedBox(height: SealSize.paper.logical),
          ],
        ),
      );
    },
  );

  /// 본문 글자 수 상한(계약 `DiaryInput.body` maxLength).
  static const int defaultMaxLength = 10000;

  /// 종이 바탕을 찾는 테스트용 키.
  static const Key paperKey = ValueKey('diary-editor-paper');

  /// 질문 줄을 찾는 테스트용 키.
  static const Key questionKey = ValueKey('diary-editor-question');

  /// 도장 자리를 찾는 테스트용 키.
  static const Key sealReserveKey = ValueKey('diary-editor-seal');

  /// 인용 질문 왼쪽 선을 찾는 테스트용 키.
  static const Key quoteLineKey = ValueKey('diary-editor-quote-line');

  /// 질문 바꾸기 버튼을 찾는 테스트용 키.
  static const Key swapKey = ValueKey('diary-editor-swap');

  /// 질문 떼기 버튼을 찾는 테스트용 키.
  static const Key removeKey = ValueKey('diary-editor-remove');

  /// 질문을 뗀 자리의 권유 줄을 찾는 테스트용 키.
  static const Key detachedKey = ValueKey('diary-editor-detached');

  /// 권유 줄 말풍선 아이콘을 찾는 테스트용 키.
  static const Key detachedIconKey = ValueKey('diary-editor-detached-icon');

  /// 질문 글자 크기. 계약 `diary.json` `diary-editor.parts.question.fontSize`(문장 글꼴 14
  /// 토큰이 없어 `type.sentence.body`에 크기만 덮어씀).
  static const double questionFontSize = 14;

  /// 인용 선 굵기. 계약 `diary-editor.parts.question.quoteLine.width`.
  static const double quoteLineWidth = 3;

  /// 질문 바꾸기 터치 영역. 계약
  /// `diary-editor.variants.edit.parts.question.swap.minTarget`.
  static const double swapTarget = 44;

  /// 질문과 바꾸기(없으면 떼기) 사이. 계약 `question.swap.marginStart`(`space.8`).
  static const double questionActionsGap = Space.s8;

  /// 질문 떼기 터치 영역. 계약 `question.remove.minTarget`. 바꾸기와 터치 영역끼리 붙여 둡니다.
  static const double removeTarget = 44;

  /// 권유 줄 최소 높이(줄 전체가 버튼). 계약 `question.detached.minTarget`.
  static const double detachedMinHeight = 44;

  /// 권유 글자와 말풍선 사이. 계약 `question.detached.trailingIcon.gap`(`space.4`).
  static const double detachedIconGap = Space.s4;

  static const int _minLines = 8;

  /// 변형.
  final DiaryEditorVariant variant;

  /// 일기 날짜.
  final CalendarDate date;

  /// 오늘의 질문. null이면 줄을 그리지 않습니다.
  final RenderedText? question;

  /// `edit` 본문 controller.
  final TextEditingController? controller;

  /// `view` 본문.
  final String? body;

  /// `edit` 빈 본문 안내.
  final String? placeholder;

  /// `edit` 본문 글자 수 상한.
  final int maxLength;

  /// `edit` 본문이 바뀔 때.
  final ValueChanged<String>? onChanged;

  /// `edit` 질문 바꾸기. null이면 버튼을 두지 않습니다.
  final VoidCallback? onSwapQuestion;

  /// `edit` 질문 떼기. null이면 `x`를 두지 않습니다.
  final VoidCallback? onDetachQuestion;

  /// `edit` 권유 줄을 눌러 질문을 다시 붙일 때. null이면 권유 줄이 눌리지 않습니다.
  final VoidCallback? onAttachQuestion;

  /// `edit`에서 질문을 뗐는지(`guideStates.detached`).
  final bool questionDetached;

  /// `edit` 본문 초점. null이면 종이가 만듭니다.
  final FocusNode? focusNode;

  /// `edit` 저장 순간 손잡이.
  final DiaryEditorController? editorController;

  /// 종이 아래 대표 태그 줄을 찾는 테스트용 키.
  static const Key tagsKey = ValueKey('diary-editor-tags');

  /// 종이와 대표 태그 사이. 계약 `diary-editor.parts.tags.marginTop`.
  static const double tagsMarginTop = Space.s16;

  /// 대표 태그 사이(가로와 줄 사이). 계약 `diary-editor.parts.tags.gap`.
  static const double tagsGap = Space.s8;

  /// `view` 아래 대표 태그(`hanja-tag` `default`, 사이 `space.8`, 위 `space.16`).
  final List<HanjaTag> tags;

  /// 질문의 IA 슬롯 id(`diary-edit.guide.question`).
  final String? questionSlotId;

  /// 질문 떼기의 IA 슬롯 id(`diary-edit.guide.remove`).
  final String? removeSlotId;

  /// 권유 줄의 IA 슬롯 id(`diary-edit.guide.attach`).
  final String? attachSlotId;

  /// 본문의 IA 슬롯 id.
  final String? bodySlotId;

  @override
  State<DiaryEditor> createState() => _DiaryEditorState();
}

class _DiaryEditorState extends State<DiaryEditor>
    with TickerProviderStateMixin {
  final GlobalKey _sealKey = GlobalKey();

  late final AnimationController _stamp = AnimationController(
    vsync: this,
    duration: InteractionPattern.sealStamp.duration,
    value: _viewing ? 1 : 0,
  );

  late final AnimationController _seep = AnimationController(
    vsync: this,
    duration: InteractionPattern.appearSeep.duration,
    value: _viewing ? 1 : 0,
  );

  late bool _sealShown = _viewing;
  late List<HanjaTag> _tags = widget.tags;
  FocusNode? _ownFocus;

  FocusNode get _focus => widget.focusNode ?? (_ownFocus ??= FocusNode());

  bool get _viewing => widget.variant == DiaryEditorVariant.view;

  @override
  void initState() {
    super.initState();
    widget.editorController?._state = this;
  }

  @override
  void didUpdateWidget(DiaryEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.editorController != widget.editorController) {
      oldWidget.editorController?._state = null;
      widget.editorController?._state = this;
    }
    if (_viewing) {
      _tags = widget.tags;
    }
  }

  @override
  void dispose() {
    if (widget.editorController?._state == this) {
      widget.editorController?._state = null;
    }
    _stamp.dispose();
    _seep.dispose();
    _ownFocus?.dispose();
    super.dispose();
  }

  Future<void> _playSaveSequence(List<HanjaTag> tags) async {
    final prefs = MotionPrefs.of(context);
    final reserve = _sealKey.currentContext;
    if (reserve != null) {
      await Scrollable.ensureVisible(
        reserve,
        alignment: 1,
        duration: prefs.reduceMotion ? Duration.zero : Motion.medium,
        curve: Easing.standard,
      );
    }
    if (!mounted) return;
    setState(() {
      _sealShown = true;
      _tags = tags;
    });
    _seep.value = 0;
    unawaited(Haptics.light());
    await _stamp.forward(from: 0);
    if (!mounted) return;
    await _seep.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final prefs = MotionPrefs.of(context);
    final tags = _tags;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          key: DiaryEditor.paperKey,
          decoration: BoxDecoration(
            color: tokens.colors.bgSheet,
            borderRadius: BorderRadius.circular(Radii.lg),
          ),
          child: Padding(
            padding: const EdgeInsets.all(Space.s16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ..._heading(context),
                _body(context),
                const SizedBox(height: Space.s12),
                Align(
                  alignment: AlignmentDirectional.bottomEnd,
                  child: SizedBox.square(
                    key: DiaryEditor.sealReserveKey,
                    dimension: SealSize.paper.logical,
                    child: KeyedSubtree(
                      key: _sealKey,
                      child: _sealShown
                          ? ExcludeSemantics(
                              child: animate(
                                InteractionPattern.sealStamp,
                                t: _stamp,
                                prefs: prefs,
                                child: _seal(context),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (tags.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: DiaryEditor.tagsMarginTop),
            child: animate(
              InteractionPattern.appearSeep,
              t: _seep,
              prefs: prefs,
              child: Wrap(
                key: DiaryEditor.tagsKey,
                spacing: DiaryEditor.tagsGap,
                runSpacing: DiaryEditor.tagsGap,
                children: tags,
              ),
            ),
          ),
      ],
    );
  }

  List<Widget> _heading(BuildContext context) {
    final tokens = context.tokens;
    final question = widget.question;
    final questionText = question == null ? '' : plainTextOf(question).trim();
    return [
      // 쓰기의 날짜는 종이 위 `date-block`이 맡습니다(`edit.parts.date.visible: false`).
      if (_viewing) ...[
        Text(
          _dateLabel(context),
          style: tokens.typography.captionMd.copyWith(
            color: tokens.colors.textSecondary,
          ),
        ),
        const SizedBox(height: Space.s12),
      ],
      if (questionText.isNotEmpty) ...[
        if (_viewing)
          _quote(context, questionText)
        else
          _guide(context, questionText),
        const SizedBox(height: Space.s16),
      ],
    ];
  }

  /// 쓰기의 질문 자리(`guideStates`): 붙은 질문([_quote]와 바꾸기, 떼기) 또는 뗀 자리 권유 줄.
  ///
  /// 바뀔 때 앞 상태는 `disappear.seep`, 새 상태는 `appear.seep`으로 같은 자리에서 동시에
  /// 시작합니다. 자리 높이는 새 상태 높이로 바로 바뀌고(앞 상태는 그 높이 안에서 잘림), 본문은
  /// 움직임 없이 옮겨 갑니다. 동작 줄이기에서는 투명도만입니다(패턴 규칙). 사라지는 상태는
  /// 누를 수 없고 스크린리더에서 숨깁니다. 새 상태는 polite로 읽힙니다(질문, 권유 줄).
  Widget _guide(BuildContext context, String questionText) {
    final prefs = MotionPrefs.of(context);
    final detached = widget.questionDetached;
    final currentKey = ValueKey<bool>(detached);
    return AnimatedSwitcher(
      duration: InteractionPattern.appearSeep.duration,
      reverseDuration: InteractionPattern.disappearSeep.duration,
      transitionBuilder: (child, animation) {
        if (child.key == currentKey) {
          return animate(
            InteractionPattern.appearSeep,
            t: animation,
            prefs: prefs,
            child: child,
          );
        }
        // 나가는 상태의 animation은 1에서 0으로 거꾸로 돕니다.
        return IgnorePointer(
          child: ExcludeSemantics(
            child: animate(
              InteractionPattern.disappearSeep,
              t: ReverseAnimation(animation),
              prefs: prefs,
              child: child,
            ),
          ),
        );
      },
      // 앞 상태는 새 상태 높이 안에서 잘립니다(Stack 기본 Clip.hardEdge).
      layoutBuilder: (current, previous) => Stack(
        children: [
          for (final child in previous)
            PositionedDirectional(top: 0, start: 0, end: 0, child: child),
          ?current,
        ],
      ),
      child: KeyedSubtree(
        key: currentKey,
        child: detached
            ? _DetachedLine(
                onTap: widget.onAttachQuestion,
                identifier: widget.attachSlotId,
              )
            : _quote(context, questionText),
      ),
    );
  }

  String _dateLabel(BuildContext context) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final date = widget.date;
    return DateFormat.yMMMMEEEEd(locale)
        .format(DateTime(date.year, date.month, date.day));
  }

  /// 인용형 질문(V82, V102): 왼쪽 3px `action.primary` 선 + 안쪽 12, 글자는 sentence.body 14
  /// text.secondary.
  /// 쓰기에서 [DiaryEditor.onSwapQuestion]이 있으면 오른쪽 `space.8`에 바꾸기 아이콘, 그 바로
  /// 뒤(없으면 질문 글 뒤 `space.8`)에 [DiaryEditor.onDetachQuestion]의 떼기 `x`이고, 바뀐
  /// 질문은 `appear.seep`으로 그리고 스크린리더가 polite로 읽습니다.
  Widget _quote(BuildContext context, String text) {
    final tokens = context.tokens;
    final style = tokens.typography.sentenceBody.copyWith(
      fontSize: DiaryEditor.questionFontSize,
      color: tokens.colors.textSecondary,
    );
    final prefs = MotionPrefs.of(context);
    final onSwap = widget.onSwapQuestion;
    final onDetach = widget.onDetachQuestion;
    final textNode = Text(text, key: DiaryEditor.questionKey, style: style);
    final shown = _viewing
        ? Semantics(identifier: widget.questionSlotId, child: textNode)
        // 바꾸면 새 질문을 polite로 읽습니다(`swap.a11y.changedAnnounced`).
        : LiveAnnouncement(
            label: text,
            role: SemanticsRole.status,
            identifier: widget.questionSlotId,
            child: AnimatedSwitcher(
              duration: prefs.reduceMotion
                  ? Duration.zero
                  : InteractionPattern.appearSeep.duration,
              transitionBuilder: (child, animation) => animate(
                InteractionPattern.appearSeep,
                t: animation,
                prefs: prefs,
                child: child,
              ),
              layoutBuilder: (current, previous) =>
                  Stack(children: [...previous, ?current]),
              child: KeyedSubtree(key: ValueKey(text), child: textNode),
            ),
          );
    final quote = IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DecoratedBox(
            key: DiaryEditor.quoteLineKey,
            decoration: BoxDecoration(
              color: tokens.colors.actionPrimary,
              borderRadius: const BorderRadius.all(Radius.circular(Radii.full)),
            ),
            child: const SizedBox(width: DiaryEditor.quoteLineWidth),
          ),
          const SizedBox(width: Space.s12),
          Expanded(child: shown),
        ],
      ),
    );
    if (onSwap == null && onDetach == null) return quote;
    final l10n = AppLocalizations.of(context);
    final lineHeight = lineHeightOf(style, MediaQuery.textScalerOf(context));
    // 아이콘 가운데를 질문 첫 줄 가운데에 맞춥니다(`swap.align`, `remove.align: first-line`).
    final iconTop = (lineHeight - AppIconSize.s20.logical) / 2;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: quote),
        const SizedBox(width: DiaryEditor.questionActionsGap),
        if (onSwap != null)
          _QuestionAction(
            targetKey: DiaryEditor.swapKey,
            glyph: _arrowsClockwise,
            label: l10n.diaryEditQuestionSwap,
            onTap: onSwap,
            iconTop: iconTop,
          ),
        // 바꾸기 바로 뒤(오른쪽 끝)에 44 터치 영역끼리 붙여 둡니다(`remove.position`, `gap`).
        if (onDetach != null)
          _QuestionAction(
            targetKey: DiaryEditor.removeKey,
            glyph: _x,
            label: l10n.diaryEditGuideRemove,
            onTap: onDetach,
            iconTop: iconTop,
            identifier: widget.removeSlotId,
          ),
      ],
    );
  }

  Widget _body(BuildContext context) {
    final tokens = context.tokens;
    final style = tokens.typography.sentenceBody.copyWith(
      color: tokens.colors.textPrimary,
    );
    final body = widget.body;
    if (body != null) {
      return Semantics(
        identifier: widget.bodySlotId,
        child: SelectableText(body, style: style),
      );
    }
    final placeholder = widget.placeholder;
    // 본문 초점 중 키보드 위 내리기 버튼(`states.focused` `keyboardDismiss`, V83).
    return KeyboardDismissPortal(
      focus: _focus,
      child: Semantics(
        identifier: widget.bodySlotId,
        label: placeholder,
        child: TextField(
          controller: widget.controller,
          focusNode: _focus,
          // 모바일 기본은 밖을 눌러도 초점이 남아 키보드를 내릴 수 없습니다(F-013).
          onTapOutside: (_) => _focus.unfocus(),
          // 커서 줄이 키보드 내리기 버튼(44 + space.12)에 가리지 않게 그 자리만큼 더 올립니다
          // (`parts.body.scrollPaddingBottom`).
          scrollPadding: const EdgeInsets.fromLTRB(
            Space.s20,
            Space.s20,
            Space.s20,
            Space.s20 + KeyboardDismissPortal.reservedHeight,
          ),
          onChanged: widget.onChanged,
          style: style,
          cursorColor: tokens.colors.actionPrimary,
          minLines: DiaryEditor._minLines,
          maxLines: null,
          maxLength: widget.maxLength,
          maxLengthEnforcement: MaxLengthEnforcement.enforced,
          buildCounter: (
            context, {
            required currentLength,
            required isFocused,
            required maxLength,
          }) => null,
          keyboardType: TextInputType.multiline,
          textInputAction: TextInputAction.newline,
          decoration: InputDecoration.collapsed(
            hintText: placeholder,
            hintStyle: style.copyWith(color: tokens.colors.textSecondary),
          ),
        ),
      ),
    );
  }

  Widget _seal(BuildContext context) {
    final date = widget.date;
    return Seal(
      size: SealSize.paper,
      child: Text(
        '${date.month}.${date.day}',
        style: context.tokens.typography.labelLg.copyWith(
          fontWeight: FontWeight.w300,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

/// 질문 줄의 아이콘 버튼: 바꾸기(`question.swap`, `arrows-clockwise`)와 떼기
/// (`question.remove`, `x`). 44 터치 안 Light 20 `text.secondary`이고, 아이콘은
/// [iconTop]에 놓아 질문 첫 줄 가운데에 맞춥니다. 본문 초점과 키보드를 빼앗지 않게 입력칸과
/// 같은 누름 묶음에 넣습니다.
class _QuestionAction extends StatelessWidget {
  const new({
    required this.glyph,
    required this.label,
    required this.onTap,
    required this.iconTop,
    required this.targetKey,
    this.identifier,
  });

  final AppGlyph glyph;
  final String label;
  final VoidCallback onTap;
  final double iconTop;
  final String? identifier;

  /// 44 터치 영역의 key(테스트가 영역과 그 버튼 의미 노드를 찾음).
  final Key targetKey;

  @override
  Widget build(BuildContext context) {
    return TextFieldTapRegion(
      child: Semantics(
        button: true,
        label: label,
        identifier: identifier,
        onTap: onTap,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          // 바꾸기와 떼기는 같은 44 터치 영역입니다(`swap.minTarget`, `remove.minTarget`).
          child: SizedBox.square(
            key: targetKey,
            dimension: DiaryEditor.swapTarget,
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: EdgeInsets.only(top: iconTop < 0 ? 0 : iconTop),
                child: AppIcon(
                  glyph,
                  size: AppIconSize.s20,
                  color: context.tokens.colors.textSecondary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 질문을 뗀 자리의 권유 줄(`question.detached`, V102): 세로선 없이 본문과 같은 시작선에
/// `diary-edit.guide.attach`(문장 글꼴 14 `invite.fg`)와 뒤 `space.4`의 말풍선
/// `chat-teardrop-dots` Light(옆 글자 크기, 같은 색, 장식)입니다.
///
/// 줄 전체가 버튼(높이 44 이상)이고 누르면 [onTap](그날 기본 질문을 다시 붙임)입니다. 본문
/// 초점과 키보드는 그대로입니다. 스크린리더는 글자 그대로 읽고(말풍선은 읽지 않음), 나타날 때
/// polite로 읽습니다(`remove.a11y.changedAnnounced`).
class _DetachedLine extends StatelessWidget {
  const new({required this.onTap, this.identifier});

  final VoidCallback? onTap;
  final String? identifier;

  static const double _fontSize = DiaryEditor.questionFontSize;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final label = AppLocalizations.of(context).diaryEditGuideAttach;
    final color = tokens.colors.inviteFg;
    final onTap = this.onTap;
    return TextFieldTapRegion(
      child: Semantics(
        key: DiaryEditor.detachedKey,
        container: true,
        liveRegion: true,
        button: true,
        label: label,
        identifier: identifier,
        onTap: onTap,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: DiaryEditor.detachedMinHeight,
              minWidth: double.infinity,
            ),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      label,
                      style: tokens.typography.sentenceBody.copyWith(
                        fontSize: _fontSize,
                        color: color,
                      ),
                    ),
                  ),
                  const SizedBox(width: DiaryEditor.detachedIconGap),
                  AppIcon(
                    _chatTeardropDots,
                    key: DiaryEditor.detachedIconKey,
                    size: AppIconSize.adjacentText(_fontSize),
                    color: color,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
