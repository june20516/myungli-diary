import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myungli_diary/design/components/depth/explain_sheet_body.dart';
import 'package:myungli_diary/design/components/feedback/screen_state_view.dart';
import 'package:myungli_diary/features/depth/presentation/depth_sheets.dart';
import 'package:myungli_diary/features/glossary/application/glossary_providers.dart';
import 'package:myungli_diary/features/glossary/data/glossary_repository.dart';

/// 풀이 시트(`explain-sheet`) 본문. 용어 이름을 사전에서 찾아 [ExplainSheetBody]에 넘깁니다.
///
/// 용어 뜻·오늘 그런 이유는 계약에 필드가 없어 그리지 않습니다(결정 A22). 필드가 들어오면
/// 이 위젯이 [ExplainSheetBody]의 `meaning`·`todayReason`에 값만 넘깁니다.
/// 사전을 받는 동안은 skeleton, 실패하거나 사전에 없는 용어면 오류 화면과 다시 시도입니다.
class ExplainSheet extends ConsumerWidget {
  /// [termId] 용어의 풀이를 보입니다. [sourceSlotId]는 그 용어가 들어 있던 writing 슬롯 id입니다.
  const new({required this.termId, required this.sourceSlotId, super.key});

  /// 용어 id(`<범주>.<값>`).
  final String termId;

  /// 용어가 눌린 슬롯 id. "근거 보기"가 이 슬롯의 근거를 엽니다.
  final String sourceSlotId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final glossary = ref.watch(glossaryProvider);
    return ScreenStateView<String>(
      value: _titleOf(glossary),
      onRetry: () => ref.invalidate(glossaryProvider),
      dataWithNotice: (title, _) => ExplainSheetBody(
        title: title,
        onEvidence: () => ref
            .read(depthSheetsProvider)
            .openEvidence(context, slotId: sourceSlotId),
      ),
    );
  }

  /// 사전에서 용어 이름을 찾습니다. 사전에 없는 용어는 값 없는 오류로 바꿔
  /// 상태 뷰가 오류 화면과 오류 요약 보고(D64)를 맡게 합니다.
  AsyncValue<String> _titleOf(AsyncValue<GlossaryNames> glossary) {
    final names = glossary.value;
    if (names != null) {
      final title = names.nameOf(termId);
      return title == null
          ? AsyncError(StateError('사전에 없는 용어입니다.'), StackTrace.current)
          : AsyncData(title);
    }
    final error = glossary.error;
    if (error != null) {
      return AsyncError(error, glossary.stackTrace ?? StackTrace.current);
    }
    return const AsyncLoading();
  }
}
