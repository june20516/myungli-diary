import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:myungli_diary/app/router/app_router.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/gen/model/diary.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:myungli_diary/core/clock/clock.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/error_messages.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/core/storage/cache_first.dart';
import 'package:myungli_diary/design/components/action/primary_button.dart';
import 'package:myungli_diary/design/components/diary/diary_editor.dart';
import 'package:myungli_diary/design/components/diary/draft_indicator.dart';
import 'package:myungli_diary/design/components/feedback/empty_state.dart';
import 'package:myungli_diary/design/components/feedback/notice_banner.dart';
import 'package:myungli_diary/design/components/feedback/screen_state_view.dart';
import 'package:myungli_diary/design/components/feedback/toast.dart';
import 'package:myungli_diary/design/components/frame/app_bar.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';
import 'package:myungli_diary/features/diary/application/diary_edit.dart';
import 'package:myungli_diary/features/diary/model/diary_edit_target.dart';
import 'package:myungli_diary/features/diary/presentation/diary_tag_chips.dart';
import 'package:myungli_diary/features/glossary/application/glossary_providers.dart';

/// IA `diary-edit`가 직접 처리하는 상태.
const Set<String> diaryEditHandledStates = {
  'loading',
  'error',
  'offline',
  'draft',
};

/// IA `diary-edit`의 출구 대상: 저장 → `diary-view`.
const Set<String> diaryEditExits = {ScreenIds.diaryView};

/// 일기 쓰기(`diary-edit`): 그날 가이드 질문을 보며 일기 한 편을 쓰고 고칩니다. `?id=`면 그
/// 일기를 고치고, 아니면 `?date=`(없으면 오늘)의 새 일기입니다(A67, [diaryEditTargetOf]).
///
/// * 열 때 초안·고칠 일기·질문을 읽는 동안 skeleton(`loading`), 고칠 일기를 읽지 못하면
///   오류와 다시 시도(`error`), 없으면(404) 찾지 못했다는 안내입니다. 기기에 남은 초안이
///   있으면 그 글로 시작합니다(`draft`, A48).
/// * 입력이 멈추면 초안을 기기에 쓰고 앱 바의 `draft-indicator`가 바뀝니다.
/// * 저장이 연결 오류로 실패하면 배너(`offline`), 그 밖의 실패는 오류 toast이고, 둘 다 초안은
///   남고 버튼으로 다시 시도합니다(A49). 그날 일기가 이미 찼으면(`diary.day_full`) 그 문구의
///   toast입니다(A71). 성공하면 저장 순간(도장 → 태그 칩 → toast) 뒤 저장한 일기의
///   `diary-view`로 바꿔 갑니다(뒤로 가면 쓰기 화면이 아니라 그 앞 화면).
class DiaryEditScreen extends ConsumerWidget {
  /// diary-edit 화면을 만듭니다.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final target = diaryEditTargetOf(
      GoRouterState.of(context).uri,
      ref.read(todayProvider),
    );
    final edit = ref.watch(diaryEditProvider(target));
    final state = edit.value;
    final status = state?.status;
    return PopScope(
      // 저장 중에 화면이 사라지면 결과를 알릴 곳이 없습니다.
      canPop: !(state?.saving ?? false),
      child: Semantics(
        identifier: ScreenIds.diaryEdit,
        child: Scaffold(
          key: const ValueKey(ScreenIds.diaryEdit),
          body: SafeArea(
            child: Column(
              children: [
                MyungliAppBar.inner(
                  title: l10n.diaryEditBarTitle,
                  titleIdentifier: SlotIds.diaryEditBarTitle,
                  showBack: MyungliAppBar.canGoBack(context),
                  status: status == null
                      ? null
                      : Semantics(
                          identifier: SlotIds.diaryEditDraftStatus,
                          child: DraftIndicator(
                            state: _indicatorOf(status),
                            label: _statusLabel(l10n, status),
                          ),
                        ),
                ),
                Expanded(
                  child: _isNotFound(edit)
                      ? EmptyState(body: l10n.errorDiaryNotFound)
                      : ScreenStateView<DiaryEditState>(
                          value: edit,
                          onRetry: () =>
                              ref.invalidate(diaryEditProvider(target)),
                          data: (state) => _DiaryEditForm(
                            // 다른 일기로 바뀌면 입력 상태를 새로 만듭니다.
                            key: ValueKey(target),
                            target: target,
                            date: state.date,
                            initialBody: state.initialBody,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 고칠 일기가 없어(404) 열지 못했는지. 다시 시도해도 같아 안내만 둡니다.
  static bool _isNotFound(AsyncValue<DiaryEditState> edit) {
    final error = edit.error;
    return !edit.hasValue &&
        error is ProblemError &&
        error.code == 'diary.not_found';
  }

  static DraftIndicatorState _indicatorOf(DiaryDraftStatus status) =>
      switch (status) {
        DiaryDraftStatus.local => DraftIndicatorState.local,
        DiaryDraftStatus.saving => DraftIndicatorState.saving,
        DiaryDraftStatus.saved => DraftIndicatorState.saved,
      };

  static String _statusLabel(AppLocalizations l10n, DiaryDraftStatus status) =>
      switch (status) {
        DiaryDraftStatus.local => l10n.diaryEditDraftStatusLocal,
        DiaryDraftStatus.saving => l10n.diaryEditDraftStatusSaving,
        DiaryDraftStatus.saved => l10n.diaryEditDraftStatusSaved,
      };
}

/// 종이와 저장 버튼. 본문 입력 상태(controller)를 듭니다.
class _DiaryEditForm extends ConsumerStatefulWidget {
  const new({
    required this.target,
    required this.date,
    required this.initialBody,
    super.key,
  });

  final DiaryEditTarget target;

  /// 일기 날짜(종이의 날짜).
  final CalendarDate date;
  final String initialBody;

  @override
  ConsumerState<_DiaryEditForm> createState() => _DiaryEditFormState();
}

class _DiaryEditFormState extends ConsumerState<_DiaryEditForm> {
  late final TextEditingController _body = TextEditingController(
    text: widget.initialBody,
  );
  final DiaryEditorController _editor = DiaryEditorController();

  /// 저장 순간이 도는 중인지. 그동안은 다시 저장하지 않습니다.
  bool _celebrating = false;

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  bool get _savable => _body.text.trim().isNotEmpty && !_celebrating;

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final notifier = ref.read(diaryEditProvider(widget.target).notifier);
    final Diary? saved;
    try {
      saved = await notifier.save(_body.text);
    } on Object catch (error) {
      if (!mounted || isConnectivityError(error)) return;
      showMyungliToast(
        context,
        errorMessage(l10n, error is AppError ? error : UnexpectedError(error)),
      );
      return;
    }
    if (saved == null || !mounted) return;
    setState(() => _celebrating = true);
    await _editor.playSaveSequence(
      diaryTagChipsOf(
        context,
        ref.read(glossaryProvider).value,
        saved.tags.featured,
      ),
    );
    if (!mounted) return;
    showMyungliToast(context, l10n.diaryEditSavedTags);
    context.pushReplacement(diaryPathOf(ScreenIds.diaryView, saved.id));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(diaryEditProvider(widget.target)).value;
    // 저장 순간의 태그 칩 이름을 위해 용어 사전을 미리 받아 둡니다.
    ref.watch(glossaryProvider);
    final saving = state?.saving ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              Space.s20,
              Space.s8,
              Space.s20,
              Space.s24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                NoticeBanner(
                  variant: NoticeBannerVariant.offline,
                  message: l10n.diaryEditOfflineNotice,
                  present: state?.offline ?? false,
                  identifier: SlotIds.diaryEditOfflineNotice,
                ),
                DiaryEditor.edit(
                  date: widget.date,
                  controller: _body,
                  question: state?.question,
                  questionSlotId: SlotIds.diaryEditGuideQuestion,
                  placeholder: l10n.diaryEditBodyPlaceholder,
                  editorController: _editor,
                  onChanged: (body) {
                    setState(() {});
                    ref
                        .read(diaryEditProvider(widget.target).notifier)
                        .edit(body);
                  },
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.s20,
            Space.s8,
            Space.s20,
            Space.s16,
          ),
          child: ToastAnchor(
            child: PrimaryButton(
              label: l10n.diaryEditSave,
              identifier: SlotIds.diaryEditSaveCta,
              loading: saving,
              onPressed: _savable && !saving ? () => unawaited(_save()) : null,
            ),
          ),
        ),
      ],
    );
  }
}
