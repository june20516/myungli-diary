import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:myungli_diary/core/api/gen/model/rendered_text.dart';
import 'package:myungli_diary/core/api/rendered_text_plain.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:myungli_diary/design/components/component_spec.dart';
import 'package:myungli_diary/design/components/diary/tag_chip.dart';
import 'package:myungli_diary/design/elements/seal.dart';
import 'package:myungli_diary/design/interaction/haptics.dart';
import 'package:myungli_diary/design/interaction/motion_prefs.dart';
import 'package:myungli_diary/design/interaction/patterns.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

/// [DiaryEditor] 변형(`diary-editor` `variants`).
enum DiaryEditorVariant {
  /// 쓰기·고치기.
  edit,

  /// 보기(`diary-view`): 도장이 찍힌 채, 아래 태그 칩.
  view,
}

/// 저장 순간 동작을 [DiaryEditor]에 시키는 손잡이. 화면이 하나 만들어 `edit`에 넘깁니다.
class DiaryEditorController {
  _DiaryEditorState? _state;

  /// 저장 순서(`motion.saveSequence`)의 종이 쪽 단계를 돌립니다: 종이 맨 아래(도장 자리)로
  /// 스크롤 → 날짜 도장 찍힘 + 햅틱 light → 대표 태그 칩 스밈. 끝나면 완료됩니다. 버튼 숨쉬기와
  /// toast는 화면 몫입니다. 편집기가 화면에 없으면 바로 끝납니다.
  Future<void> playSaveSequence(List<TagChip> tags) =>
      _state?._playSaveSequence(tags) ?? Future<void>.value();
}

/// 일기 종이(`diary-editor`, `surface.paper`): 날짜, 오늘의 질문(있으면), 본문.
///
/// 종이 아래 끝에 64px 도장 자리를 쓰는 중에도 늘 비워 두어, 글이 길어도 도장이 글을 덮지
/// 않습니다. 해시태그를 쓰는 입력은 없습니다(태그는 저장할 때 엔진이 붙임). 태그 칩은 종이
/// 아래에 놓입니다.
class DiaryEditor extends StatefulWidget {
  /// 쓰기·고치기 종이. 본문은 [controller]가 쥐고, [maxLength](계약 10000자)를 넘게 칠 수
  /// 없습니다. [placeholder]는 빈 본문 안내이자 본문 칸의 스크린리더 이름입니다.
  const new edit({
    required this.date,
    required TextEditingController this.controller,
    this.question,
    this.placeholder,
    this.maxLength = defaultMaxLength,
    this.onChanged,
    this.editorController,
    this.questionSlotId,
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
       editorController = null;

  /// 명세 대조용 요약.
  static const ComponentSpec spec = ComponentSpec(
    'diary-editor',
    {'edit', 'view'},
    {'saving', 'saved'},
  );

  /// 본문 글자 수 상한(계약 `DiaryInput.body` maxLength).
  static const int defaultMaxLength = 10000;

  /// 종이 바탕을 찾는 테스트용 키.
  static const Key paperKey = ValueKey('diary-editor-paper');

  /// 질문 줄을 찾는 테스트용 키.
  static const Key questionKey = ValueKey('diary-editor-question');

  /// 도장 자리를 찾는 테스트용 키.
  static const Key sealReserveKey = ValueKey('diary-editor-seal');

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

  /// `edit` 저장 순간 손잡이.
  final DiaryEditorController? editorController;

  /// `view` 아래 태그 칩.
  final List<TagChip> tags;

  /// 질문의 IA 슬롯 id(`diary-edit.guide.question`).
  final String? questionSlotId;

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
  late List<TagChip> _tags = widget.tags;

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
    super.dispose();
  }

  Future<void> _playSaveSequence(List<TagChip> tags) async {
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
                const SizedBox(height: Space.s12),
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
            padding: const EdgeInsets.only(top: Space.s16),
            child: animate(
              InteractionPattern.appearSeep,
              t: _seep,
              prefs: prefs,
              child: Wrap(
                spacing: Space.s8,
                runSpacing: Space.s8,
                children: tags,
              ),
            ),
          ),
      ],
    );
  }

  List<Widget> _heading(BuildContext context) {
    final tokens = context.tokens;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final date = widget.date;
    final question = widget.question;
    final questionText = question == null ? '' : plainTextOf(question).trim();
    final slotId = widget.questionSlotId;
    return [
      Text(
        DateFormat.yMMMMEEEEd(locale)
            .format(DateTime(date.year, date.month, date.day)),
        style: tokens.typography.captionMd.copyWith(
          color: tokens.colors.textSecondary,
        ),
      ),
      if (questionText.isNotEmpty) ...[
        const SizedBox(height: Space.s8),
        Semantics(
          identifier: slotId,
          child: Text(
            questionText,
            key: DiaryEditor.questionKey,
            style: tokens.typography.captionLg.copyWith(
              color: tokens.colors.textSecondary,
            ),
          ),
        ),
      ],
    ];
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
    return Semantics(
      identifier: widget.bodySlotId,
      label: placeholder,
      child: TextField(
        controller: widget.controller,
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
