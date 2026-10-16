import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myungli_diary/core/api/gen/model/rendered_text.dart';
import 'package:myungli_diary/design/components/depth/explain_sheet_body.dart';
import 'package:myungli_diary/design/components/feedback/screen_state_view.dart';
import 'package:myungli_diary/features/depth/application/depth_sheets.dart';
import 'package:myungli_diary/features/glossary/application/glossary_providers.dart';
import 'package:myungli_diary/features/glossary/model/glossary_names.dart';
import 'package:myungli_diary/features/today/application/daily_controller.dart';
import 'package:myungli_diary/features/today/application/today_presentation.dart';

/// 풀이 시트에 보일 사전 값: 용어 이름과 (있으면) 한자·뜻 문장.
typedef _ExplainContent = ({
  String title,
  String? hanja,
  RenderedText? meaning,
});

/// 풀이 시트(`explain-sheet`) 본문. 용어 이름·한자·뜻을 사전에서 찾아 [ExplainSheetBody]에 넘깁니다.
///
/// 뜻(`term.meaning`)은 계약 draft.3 `Glossary.meanings`, 한자는 draft.4
/// `Glossary.hanja`에서 옵니다. 오늘 그런 이유(`explain.today_reason`)는 draft.4
/// `SlotText.todayReason`이고, 용어가 눌린 슬롯([sourceSlotId])이 오늘 응답의 슬롯일
/// 때만 그 문장의 값을 넘깁니다(오늘 화면에서 열었을 때만). 사전·응답에 값이 없으면 그
/// 자리를 그리지 않습니다(A22 남은 규칙).
/// 사전을 받는 동안은 skeleton, 실패하거나 사전에 없는 용어면 오류 화면과 다시 시도입니다.
class ExplainSheet extends ConsumerWidget {
  /// [termId] 용어의 풀이를 보입니다. [sourceSlotId]는 그 용어가 들어 있던 writing 슬롯 id이고,
  /// null이면 근거로 이어지지 않는 곳(그날 시트)에서 연 것이라 근거 보기를 두지 않습니다.
  const new({required this.termId, this.sourceSlotId, super.key});

  /// 용어 id(`<범주>.<값>`).
  final String termId;

  /// 용어가 눌린 슬롯 id. "근거 보기"가 이 슬롯의 근거를 엽니다. null이면 근거 보기가 없습니다.
  final String? sourceSlotId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final glossary = ref.watch(glossaryProvider);
    final slotId = sourceSlotId;
    // 그날 시트처럼 슬롯 없이 열면 오늘 응답을 보지 않습니다.
    final todayReason = slotId == null
        ? null
        : ref.watch(
            dailyControllerProvider.select((value) {
              final view = value.value;
              final reason = view == null
                  ? null
                  : dailySlotText(view.daily, slotId)?.todayReason;
              return reason == null || isBlankText(reason) ? null : reason;
            }),
          );
    return ScreenStateView<_ExplainContent>(
      value: _contentOf(glossary),
      onRetry: () => ref.invalidate(glossaryProvider),
      dataWithNotice: (content, _) => ExplainSheetBody(
        title: content.title,
        hanja: content.hanja,
        meaning: content.meaning,
        todayReason: todayReason,
        onEvidence: slotId == null
            ? null
            : () => ref
                  .read(depthSheetsProvider)
                  .openEvidence(context, slotId: slotId),
      ),
    );
  }

  /// 사전에서 용어 이름·한자·뜻을 찾습니다. 이름이 없는 용어는 값 없는 오류로 바꿔
  /// 상태 뷰가 오류 화면과 오류 요약 보고(D64)를 맡게 합니다.
  AsyncValue<_ExplainContent> _contentOf(AsyncValue<GlossaryNames> glossary) {
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
