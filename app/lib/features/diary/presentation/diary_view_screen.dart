import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:myungli_diary/app/router/app_router.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/gen/model/diary.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/error_messages.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/diary/diary_editor.dart';
import 'package:myungli_diary/design/components/feedback/dialog.dart';
import 'package:myungli_diary/design/components/feedback/empty_state.dart';
import 'package:myungli_diary/design/components/feedback/screen_state_view.dart';
import 'package:myungli_diary/design/components/feedback/skeleton.dart';
import 'package:myungli_diary/design/components/feedback/toast.dart';
import 'package:myungli_diary/design/components/frame/app_bar.dart';
import 'package:myungli_diary/design/components/sentence/hanja_tag.dart';
import 'package:myungli_diary/design/elements/app_icon.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';
import 'package:myungli_diary/features/depth/application/depth_sheets.dart';
import 'package:myungli_diary/features/diary/application/diary_edit.dart';
import 'package:myungli_diary/features/diary/presentation/diary_row_tags.dart';
import 'package:myungli_diary/features/diary/presentation/diary_tag_chips.dart';
import 'package:myungli_diary/features/glossary/application/glossary_providers.dart';
import 'package:phosphor_glyphs/phosphor_glyphs.dart';

/// IA `diary-view`가 직접 처리하는 상태.
const Set<String> diaryViewHandledStates = {'loading', 'error'};

/// IA `diary-view`의 출구 대상.
const Set<String> diaryViewExits = {
  ScreenIds.diaryEdit,
  ScreenIds.tagDiary,
  ScreenIds.explainSheet,
};

const AppGlyph _pencil = AppGlyph(
  light: PhosphorIconsLight.pencilSimple,
  regular: PhosphorIconsRegular.pencilSimple,
);

const AppGlyph _trash = AppGlyph(
  light: PhosphorIconsLight.trash,
  regular: PhosphorIconsRegular.trash,
);

/// 일기 보기(`diary-view`): 그날 성격 `hanja-tag`(누르면 뜻 시트), 도장이 찍힌 종이(쓸 때 고른
/// 질문은 인용형), 태그 칩.
/// 일기는 `?id=`(A67)이고, 제목의 날짜는 받은 일기의 날짜입니다(받기 전에는 제목 없음).
///
/// * 일기를 받는 동안 skeleton(`loading`), 받지 못하면 오류와 다시 시도(`error`)입니다.
///   일기가 없으면(다른 곳에서 지워짐, `id` 없음) 그 안내만 둡니다.
/// * 그날 성격은 쓸 때 기록한 값만이고(D90 ①) 이유 문장은 없습니다(IA v5). 기록이 없는
///   일기는 성격 줄 없이 일기만 보입니다.
/// * 고치기는 이 화면을 그 일기의 `diary-edit`로 바꿔 엽니다(저장하면 다시 이 화면으로 바뀜).
///   지우기는 확인 창(`dialog` `destructive`) 뒤 지우고 앞 화면으로 돌아가 toast입니다.
///   되살리기는 없습니다(A50).
class DiaryViewScreen extends ConsumerWidget {
  /// diary-view 화면을 만듭니다.
  const new({super.key});

  /// 앱 바의 고치기 동작.
  static const Key editKey = ValueKey('diary-view.edit');

  /// 앱 바의 지우기 동작.
  static const Key deleteKey = ValueKey('diary-view.delete');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final id = GoRouterState.of(context).uri.queryParameters[diaryIdQuery];
    final hasId = id != null && id.isNotEmpty;
    // id가 없으면 물을 일기가 없어 찾지 못한 것과 같습니다.
    final diary = hasId
        ? ref.watch(diaryProvider(id))
        : const AsyncData<Diary?>(null);
    final loaded = diary.value;
    final locale = Localizations.localeOf(context).toString();
    final deleting = ref.watch(diaryDeleterProvider);
    return PopScope(
      canPop: !deleting,
      child: Semantics(
        identifier: ScreenIds.diaryView,
        child: Scaffold(
          key: const ValueKey(ScreenIds.diaryView),
          body: SafeArea(
            child: Column(
              children: [
                MyungliAppBar.inner(
                  title: loaded == null
                      ? ''
                      : l10n.diaryViewBarTitle(_dateLabel(locale, loaded)),
                  titleIdentifier: SlotIds.diaryViewBarTitle,
                  showBack: MyungliAppBar.canGoBack(context),
                  actions: [
                    if (loaded != null) ...[
                      AppBarAction(
                        key: editKey,
                        icon: _pencil,
                        semanticLabel: l10n.diaryViewEditAction,
                        onPressed: () => context.pushReplacement(
                          diaryPathOf(ScreenIds.diaryEdit, loaded.id),
                        ),
                      ),
                      AppBarAction(
                        key: deleteKey,
                        icon: _trash,
                        semanticLabel: l10n.diaryViewDeleteAction,
                        onPressed: deleting
                            ? () {}
                            : () => unawaited(_delete(context, ref, loaded)),
                      ),
                    ],
                  ],
                ),
                Expanded(
                  child: ScreenStateView<Diary?>(
                    value: diary,
                    onRetry: hasId
                        ? () => ref.invalidate(diaryProvider(id))
                        : null,
                    isEmpty: (value) => value == null,
                    empty: EmptyState(body: l10n.errorDiaryNotFound),
                    skeleton: const _DiaryViewSkeleton(),
                    data: (value) => _DiaryViewBody(diary: value!),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 제목에 넣는 [diary] 날짜(예 `10월 12일`).
  static String _dateLabel(String locale, Diary diary) {
    final date = CalendarDate.parse(diary.date);
    return DateFormat.MMMd(locale)
        .format(DateTime(date.year, date.month, date.day));
  }

  /// 확인 창 뒤 [diary]를 지우고 앞 화면으로 돌아갑니다(A50).
  Future<void> _delete(BuildContext context, WidgetRef ref, Diary diary) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showMyungliDialog(
      context,
      variant: DialogVariant.destructive,
      title: l10n.diaryViewDeleteConfirm,
      identifier: SlotIds.diaryViewDeleteConfirm,
      confirm: l10n.diaryViewDeleteConfirmDelete,
      cancel: l10n.diaryViewDeleteConfirmCancel,
    );
    if (!confirmed || !context.mounted) return;
    try {
      final deleted = await ref
          .read(diaryDeleterProvider.notifier)
          .delete(diary);
      if (!deleted || !context.mounted) return;
      showMyungliToast(
        context,
        l10n.diaryViewDeleted,
        identifier: SlotIds.diaryViewDeletedToast,
      );
      _close(context);
    } on ProblemError catch (error) {
      if (!context.mounted) return;
      showMyungliToast(context, errorMessage(l10n, error));
      // 이미 없는 일기면 볼 것이 없으므로 앞 화면으로 돌아갑니다.
      if (error.code == 'diary.not_found') _close(context);
    } on AppError catch (error) {
      if (!context.mounted) return;
      showMyungliToast(context, errorMessage(l10n, error));
    }
  }

  /// 앞 화면으로 돌아갑니다. 스택 바닥(딥링크·복원)이면 일기 목록으로 갑니다.
  void _close(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(pathOf(ScreenIds.diaryList));
    }
  }
}

/// 그날 성격과 종이.
class _DiaryViewBody extends ConsumerWidget {
  const new({required this.diary});

  final Diary diary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = CalendarDate.parse(diary.date);
    // 쓸 때 기록한 성격만 씁니다(D90 ①). 기록이 없는 일기(1.1.0 전)는 성격 줄이 없습니다.
    final kind = diary.dayKind;
    final names = ref.watch(glossaryProvider).value;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        Space.s20,
        Space.s8,
        Space.s20,
        MediaQuery.paddingOf(context).bottom + Space.s32,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (kind != null) ...[
            // 한자 아이콘 태그만 두고 이유 문장은 두지 않습니다. 누르면 뜻 시트(D108).
            Semantics(
              identifier: SlotIds.diaryViewCharacterLabel,
              container: true,
              child: KeyedSubtree(
                key: const ValueKey(SlotIds.diaryViewCharacterLabel),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: diaryDayKindTagOf(context, ref, kind),
                ),
              ),
            ),
            const SizedBox(height: Space.s24),
          ],
          // 질문은 쓸 때 고른 질문을 같은 인용 모양으로, 바꾸기 없이 보입니다(DS1 관문 Q4 ①).
          DiaryEditor.view(
            date: date,
            body: diary.body,
            question: diary.guideQuestion,
            tags: diaryTagChipsOf(
              context,
              ref.read(depthSheetsProvider),
              names,
              diary.tags.featured,
            ),
          ),
        ],
      ),
    );
  }
}

/// 일기를 받는 동안: [_DiaryViewBody]와 같은 배치(좌우 20, 위 8)에 날의 성격 `hanja-tag` 뼈,
/// 그 아래 [Space.s24]에 `diary-editor` `view` 뼈(V66).
class _DiaryViewSkeleton extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    physics: const NeverScrollableScrollPhysics(),
    padding: const EdgeInsets.fromLTRB(Space.s20, Space.s8, Space.s20, 0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Align(
          alignment: AlignmentDirectional.centerStart,
          child: SkeletonChip(
            width: HanjaTag.skeletonWidth,
            height: HanjaTag.height,
          ),
        ),
        const SizedBox(height: Space.s24),
        DiaryEditor.skeleton(variant: DiaryEditorVariant.view, index: 1),
      ],
    ),
  );
}
