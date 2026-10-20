import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:myungli_diary/app/router/app_router.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/feedback/empty_state.dart';
import 'package:myungli_diary/design/components/feedback/screen_state_view.dart';
import 'package:myungli_diary/design/components/frame/app_bar.dart';
import 'package:myungli_diary/design/components/sentence/sentence_block.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';
import 'package:myungli_diary/features/depth/application/depth_sheets.dart';
import 'package:myungli_diary/features/diary/application/diary_pages.dart';
import 'package:myungli_diary/features/diary/presentation/diary_page_list.dart';
import 'package:myungli_diary/features/glossary/application/glossary_providers.dart';

/// IA `tag-diary`가 직접 처리하는 상태.
const Set<String> tagDiaryHandledStates = {'loading', 'empty', 'error'};

/// IA `tag-diary`의 출구 대상.
const Set<String> tagDiaryExits = {ScreenIds.diaryView, ScreenIds.explainSheet};

/// 태그 모아보기(`tag-diary`, D47①): 같은 태그가 붙은 일기를 날짜 내림차순으로 넘겨 보고,
/// 태그 뜻을 한 줄로 알려 줍니다. 태그는 `?tag=<key>`입니다.
///
/// * 제목은 용어 사전의 태그 이름, 뜻 한 줄은 `Glossary.meanings['tag.<key>']`이고 용어는
///   칩(누르면 `explain-sheet`)입니다. 뜻이 없으면 줄을 그리지 않습니다(A52).
/// * 목록은 `diary-list`와 같은 쪽 단위 메모리 목록입니다(A45): 받는 중 skeleton(`loading`),
///   그 태그의 일기 없음(`empty`), 받지 못함(`error`).
/// * 태그가 없는 경로(딥링크 오류)는 목록을 묻지 않고 빈 안내만 둡니다.
class TagDiaryScreen extends ConsumerWidget {
  /// tag-diary 화면을 만듭니다.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final query = GoRouterState.of(context).uri.queryParameters[tagQuery];
    final tag = query == null || query.isEmpty ? null : query;
    final names = ref.watch(glossaryProvider).value;
    final name = tag == null ? null : names?.valueName('tag', tag);
    final meaning = tag == null ? null : names?.meaningOf('tag.$tag');
    final empty = EmptyState(
      body: l10n.tagDiaryEmptyBody,
      identifier: SlotIds.tagDiaryEmptyBody,
    );
    return Semantics(
      identifier: ScreenIds.tagDiary,
      child: Scaffold(
        key: const ValueKey(ScreenIds.tagDiary),
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              MyungliAppBar.inner(
                // 사전을 받기 전에는 키를 그대로 보이지 않도록 제목을 비워 둡니다.
                title: name == null ? '' : l10n.tagDiaryBarTitle(name),
                titleIdentifier: SlotIds.tagDiaryBarTitle,
                showBack: MyungliAppBar.canGoBack(context),
              ),
              if (meaning != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Space.s20,
                    Space.s8,
                    Space.s20,
                    Space.s16,
                  ),
                  child: SentenceBlock(
                    variant: SentenceBlockVariant.body,
                    text: meaning,
                    slotId: SlotIds.tagDiaryTagMeaning,
                    onTerm: (termId) => ref
                        .read(depthSheetsProvider)
                        .openExplain(context, termId: termId),
                  ),
                ),
              Expanded(
                child: tag == null
                    ? empty
                    : _TagDiaryList(tag: tag, empty: empty),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// [tag] 일기 목록과 그 상태.
class _TagDiaryList extends ConsumerWidget {
  const new({required this.tag, required this.empty});

  final String tag;
  final Widget empty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pages = visibleDiaryPagesOf(ref.watch(diaryPagesProvider(tag)));
    return ScreenStateView<DiaryPagesView>(
      value: pages,
      onRetry: () => ref.invalidate(diaryPagesProvider(tag)),
      skeleton: const DiaryPageListSkeleton(),
      isEmpty: (view) => view.items.isEmpty,
      empty: empty,
      dataWithNotice: (view, notice) =>
          DiaryPageList(tag: tag, view: view, leading: [notice]),
    );
  }
}
