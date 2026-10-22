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
import 'package:myungli_diary/core/l10n/day_kind_names.dart';
import 'package:myungli_diary/core/l10n/error_messages.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/diary/diary_editor.dart';
import 'package:myungli_diary/design/components/feedback/dialog.dart';
import 'package:myungli_diary/design/components/feedback/empty_state.dart';
import 'package:myungli_diary/design/components/feedback/screen_state_view.dart';
import 'package:myungli_diary/design/components/feedback/toast.dart';
import 'package:myungli_diary/design/components/frame/app_bar.dart';
import 'package:myungli_diary/design/components/sentence/press_ink_target.dart';
import 'package:myungli_diary/design/components/sentence/sentence_block.dart';
import 'package:myungli_diary/design/components/today/day_character.dart';
import 'package:myungli_diary/design/elements/app_icon.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';
import 'package:myungli_diary/features/calendar/application/calendar_providers.dart';
import 'package:myungli_diary/features/depth/application/depth_sheets.dart';
import 'package:myungli_diary/features/diary/application/diary_edit.dart';
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

/// 일기 보기(`diary-view`): 그날 성격과 이유(용어는 풀이 시트), 도장이 찍힌 종이, 태그 칩.
/// 일기는 `?id=`(A67)이고, 제목의 날짜는 받은 일기의 날짜입니다(받기 전에는 제목 없음).
///
/// * 일기를 받는 동안 skeleton(`loading`), 받지 못하면 오류와 다시 시도(`error`)입니다.
///   일기가 없으면(다른 곳에서 지워짐, `id` 없음) 그 안내만 둡니다.
/// * 그날 성격은 달 길흉 캐시(A46)이고, 받지 못하면 성격 줄 없이 일기만 보입니다.
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
    final l10n = AppLocalizations.of(context);
    final date = CalendarDate.parse(diary.date);
    final day = ref.watch(calendarDayProvider(date)).value;
    final names = ref.watch(glossaryProvider).value;
    final sheets = ref.read(depthSheetsProvider);
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
          if (day != null) ...[
            Semantics(
              identifier: SlotIds.diaryViewCharacterLabel,
              container: true,
              child: KeyedSubtree(
                key: const ValueKey(SlotIds.diaryViewCharacterLabel),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  // 날의 성격을 누르면 그 성격 용어(`day_kind.<값>`)의 풀이 시트입니다.
                  child: PressInkTarget(
                    semanticLabel: dayKindName(l10n, day.dayKind),
                    borderRadius: const BorderRadius.all(
                      Radius.circular(Radii.full),
                    ),
                    onTap: () => sheets.openExplain(
                      context,
                      termId: 'day_kind.${day.dayKind.value}',
                    ),
                    child: DayCharacter(
                      variant: dayCharacterVariantOf(day.dayKind),
                      label: dayKindName(l10n, day.dayKind),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: Space.s12),
            // diary-view의 IA에는 term-token이 없어 용어는 일반 글자입니다(V28).
            SentenceBlock(
              variant: SentenceBlockVariant.body,
              text: day.characterReason.text,
            ),
            const SizedBox(height: Space.s24),
          ],
          DiaryEditor.view(
            date: date,
            body: diary.body,
            question: diary.guideQuestion,
            tags: diaryTagChipsOf(context, names, diary.tags.featured),
          ),
        ],
      ),
    );
  }
}
