import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:myungli_diary/app/router/app_router.dart';
import 'package:myungli_diary/core/api/gen/model/rendered_text.dart';
import 'package:myungli_diary/core/api/gen/model/segment.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/depth/explain_sheet_body.dart';
import 'package:myungli_diary/design/components/feedback/screen_state_view.dart';
import 'package:myungli_diary/design/components/today/color_pair_sheet_body.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';
import 'package:myungli_diary/features/depth/application/depth_sheets.dart';
import 'package:myungli_diary/features/depth/application/explain_content.dart';
import 'package:myungli_diary/features/depth/application/term_origin.dart';
import 'package:myungli_diary/features/glossary/application/glossary_providers.dart';
import 'package:myungli_diary/features/glossary/model/glossary_names.dart';

/// 풀이 시트에 보일 사전 값: 용어 이름과 (있으면) 한자·뜻 문장.
typedef _TermText = ({String title, String? hanja, RenderedText? meaning});

/// 풀이 시트(`explain-sheet`) 본문. [content]의 종류대로 [ExplainSheetBody]에 넘깁니다.
///
/// * [ExplainTerm]: 용어 이름·한자·뜻을 사전에서 찾습니다. 뜻(`term.meaning`)은 계약 draft.3
///   `Glossary.meanings`, 한자는 draft.4 `Glossary.hanja`에서 옵니다. 오늘 그런 이유
///   (`explain.today_reason`)는 여는 화면이 넘긴 출처([ExplainTerm.origin])의 응답에서만 읽습니다
///   (`EvidenceSubject.todayReasonOf`, 오늘 화면에서 열었을 때만). 출처가 없으면 응답을 보지
///   않습니다. 사전·응답에 값이 없으면 그 자리를 그리지 않습니다(A22 남은 규칙). 사전을 받는
///   동안은 skeleton, 실패하거나 사전에 없는 용어면 오류 화면과 다시 시도입니다.
/// * [ExplainUiText], [ExplainLucky]: 사전을 보지 않고 받은 제목과 본문을 그립니다.
/// * [ExplainLuckyColorPair]: 색이 둘인 날 행운 색 시트([ColorPairSheetBody])를 그립니다.
///
/// [diaryLinkTag]가 있으면 본문 아래에 그 태그(키)의 모아보기 링크를 둡니다. 누르면 시트를 닫고
/// `tag-diary`로 page.push 합니다. 태그 이름은 사전에서 찾고, 이름을 아직 모르면 링크를
/// 그리지 않습니다.
class ExplainSheet extends ConsumerWidget {
  /// [content]를 풀이합니다. [head]는 제목 줄 대신 놓을 머리입니다.
  const new({required this.content, this.head, this.diaryLinkTag, super.key});

  /// 풀이할 내용.
  final ExplainContent content;

  /// 제목 줄 대신 놓을 머리(`hanja-tag`).
  final Widget? head;

  /// 모아보기 링크를 둘 태그 키(`Tag.key`). null이면 링크가 없습니다.
  final String? diaryLinkTag;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = this.content;
    // 모아보기 링크가 있으면 태그 이름을 알 때까지 기다려, 링크가 뒤늦게 생겨 본문이 밀리지
    // 않게 합니다. 사전을 못 받으면(error) 링크만 숨기고 본문은 그립니다.
    if (diaryLinkTag != null && content is! ExplainTerm) {
      final glossary = ref.watch(glossaryProvider);
      return ScreenStateView<void>(
        value: glossary.isLoading
            ? const AsyncLoading<void>()
            : const AsyncData<void>(null),
        onRetry: () => ref.invalidate(glossaryProvider),
        skeleton: ExplainSheetBody.skeleton(head: head),
        dataWithNotice: (_, _) => _contentBody(context, ref, content),
      );
    }
    return _contentBody(context, ref, content);
  }

  Widget _contentBody(
    BuildContext context,
    WidgetRef ref,
    ExplainContent content,
  ) {
    return switch (content) {
      final ExplainTerm term => _buildTerm(context, ref, term),
      final ExplainUiText ui => _body(
        context,
        ref,
        title: ui.title,
        meaning: RenderedText(segments: [Segment(text: ui.body)]),
        attachment: ui.attachment,
      ),
      final ExplainLucky lucky => _body(
        context,
        ref,
        title: lucky.title,
        meaning: lucky.body,
        attachment: lucky.attachment,
        attachmentGap: lucky.attachmentGap,
        origin: lucky.origin,
      ),
      final ExplainLuckyColorPair pair => ColorPairSheetBody(
        title: pair.title,
        intro: pair.intro,
        sections: [
          for (final section in pair.sections)
            ColorPairSection(
              element: section.element,
              name: section.name,
              body: section.body,
              bodySlotId: section.bodySlotId,
              onEvidence: () => ref
                  .read(depthSheetsProvider)
                  .openEvidence(
                    context,
                    section.origin.slotId,
                    personal: section.origin.personal,
                  ),
            ),
        ],
      ),
    };
  }

  Widget _buildTerm(BuildContext context, WidgetRef ref, ExplainTerm term) {
    final glossary = ref.watch(glossaryProvider);
    final origin = term.origin;
    // 출처가 없으면 응답을 보지 않습니다(그날 시트에서 열면 오늘 응답을 받지 않음).
    final todayReason = origin == null
        ? null
        : ref.watch(origin.subject.todayReasonOf(origin.slotId));
    return ScreenStateView<_TermText>(
      value: _termTextOf(glossary, term.termId),
      onRetry: () => ref.invalidate(glossaryProvider),
      skeleton: ExplainSheetBody.skeleton(
        head: head,
        titleSize: ExplainTitleSize.title,
      ),
      dataWithNotice: (text, _) => _body(
        context,
        ref,
        title: text.title,
        titleSize: ExplainTitleSize.title,
        hanja: text.hanja,
        meaning: text.meaning,
        meaningSlotId: SlotIds.explainSheetTermMeaning,
        todayReason: todayReason,
        evidenceSubject: term.evidenceSubject,
        origin: origin,
      ),
    );
  }

  Widget _body(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    ExplainTitleSize titleSize = ExplainTitleSize.subtitle,
    String? hanja,
    RenderedText? meaning,
    String? meaningSlotId,
    RenderedText? todayReason,
    Widget? attachment,
    double attachmentGap = Space.s12,
    String? evidenceSubject,
    TermOrigin? origin,
  }) {
    final tag = diaryLinkTag;
    final tagName = tag == null
        ? null
        : ref.watch(glossaryProvider).value?.valueName('tag', tag);
    return ExplainSheetBody(
      title: title,
      titleSize: titleSize,
      head: head,
      hanja: hanja,
      meaning: meaning,
      meaningSlotId: meaningSlotId,
      todayReason: todayReason,
      attachment: attachment,
      attachmentGap: attachmentGap,
      evidenceSubject: evidenceSubject,
      onEvidence: origin == null
          ? null
          : () => ref
                .read(depthSheetsProvider)
                .openEvidence(
                  context,
                  origin.slotId,
                  personal: origin.personal,
                ),
      diaryLinkLabel: tag == null || tagName == null
          ? null
          : AppLocalizations.of(context).explainSheetTagDiaryLink(tagName),
      onDiaryLink: tag == null || tagName == null
          ? null
          : () => _openTagDiary(context, tag),
    );
  }

  /// 시트를 닫고 [tag] 모아보기로 page.push 합니다. 닫은 뒤에는 이 context를 쓸 수 없어서
  /// 라우터를 먼저 잡아 둡니다.
  static void _openTagDiary(BuildContext context, String tag) {
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    unawaited(router.push<void>(taggedPathOf(tag)));
  }

  /// 사전에서 용어 이름·한자·뜻을 찾습니다. 이름이 없는 용어는 값 없는 오류로 바꿔
  /// 상태 뷰가 오류 화면과 오류 요약 보고(D64)를 맡게 합니다.
  AsyncValue<_TermText> _termTextOf(
    AsyncValue<GlossaryNames> glossary,
    String termId,
  ) {
    final names = glossary.value;
    if (names != null) {
      final title = names.nameOf(termId);
      return title == null
          ? AsyncError(StateError('사전에 없는 용어입니다.'), StackTrace.current)
          : AsyncData((
              title: title,
              hanja: names.hanjaOf(termId),
              meaning: names.meaningOf(termId),
            ));
    }
    final error = glossary.error;
    if (error != null) {
      return AsyncError(error, glossary.stackTrace ?? StackTrace.current);
    }
    return const AsyncLoading();
  }
}
