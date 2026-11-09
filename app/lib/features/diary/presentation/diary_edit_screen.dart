import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:myungli_diary/app/router/app_router.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/gen/model/diary.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:myungli_diary/core/clock/clock.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/error_messages.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/core/storage/cache_first.dart';
import 'package:myungli_diary/design/components/diary/date_block.dart';
import 'package:myungli_diary/design/components/diary/diary_editor.dart';
import 'package:myungli_diary/design/components/diary/draft_indicator.dart';
import 'package:myungli_diary/design/components/feedback/empty_state.dart';
import 'package:myungli_diary/design/components/feedback/notice_banner.dart';
import 'package:myungli_diary/design/components/feedback/screen_state_view.dart';
import 'package:myungli_diary/design/components/feedback/toast.dart';
import 'package:myungli_diary/design/components/frame/app_bar.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';
import 'package:myungli_diary/features/depth/application/depth_sheets.dart';
import 'package:myungli_diary/features/diary/application/diary_edit.dart';
import 'package:myungli_diary/features/diary/model/diary_edit_target.dart';
import 'package:myungli_diary/features/diary/presentation/diary_tag_chips.dart';
import 'package:myungli_diary/features/glossary/application/glossary_providers.dart';
import 'package:myungli_diary/features/today/application/today_presentation.dart';

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
/// * 위에서부터 `app-bar` `edit`(뒤로, 가운데 제목 또는 초안 상태, 오른쪽 저장 글자 버튼),
///   큰 날짜 블록(`date-block`), 종이(`diary-editor` `edit`: 인용 질문과 질문 바꾸기, 본문)입니다.
///   아래 고정 버튼은 없습니다(V82, IA v5).
/// * 열 때 초안·고칠 일기·오늘 풀이를 읽는 동안 skeleton(`loading`), 고칠 일기를 읽지 못하면
///   오류와 다시 시도(`error`), 없으면(404) 찾지 못했다는 안내입니다. 기기에 남은 초안이
///   있으면 그 글과 고른 질문으로 시작합니다(`draft`, A48, A115).
/// * 본문에 초점이 있는 동안 가운데는 `draft-indicator`(초안 상태와 글자 수)이고, 키보드 위에
///   내리기 버튼이 뜹니다. 종이 밖을 누르거나 스크롤을 끌면 키보드가 내려갑니다(F-013).
/// * 저장이 연결 오류로 실패하면 배너(`offline`), 그 밖의 실패는 오류 toast이고, 둘 다 초안은
///   남고 저장 글자로 다시 시도합니다(A49). 그날 일기가 이미 찼으면(`diary.day_full`) 그 문구의
///   toast, 고른 질문이 그날 후보에 없으면(`diary.guide_invalid`) 후보를 새로 받고 일반 실패
///   문구입니다(A71, A115). 성공하면 저장 순간(도장 → 태그 칩 → toast) 뒤 저장한 일기의
///   `diary-view`로 바꿔 갑니다(뒤로 가면 쓰기 화면이 아니라 그 앞 화면).
class DiaryEditScreen extends ConsumerStatefulWidget {
  /// diary-edit 화면을 만듭니다.
  const new({super.key});

  @override
  ConsumerState<DiaryEditScreen> createState() => _DiaryEditScreenState();
}

class _DiaryEditScreenState extends ConsumerState<DiaryEditScreen> {
  /// 본문. 처음 받은 상태의 본문으로 한 번 채우고, 그 뒤 다시 읽어도 쓰던 글을 덮지 않습니다.
  TextEditingController? _body;
  final FocusNode _focus = FocusNode();
  final DiaryEditorController _editor = DiaryEditorController();

  /// 저장 순간이 도는 중인지. 그동안은 다시 저장하지 않습니다.
  bool _celebrating = false;

  late final DiaryEditTarget _target = diaryEditTargetOf(
    GoRouterState.of(context).uri,
    ref.read(todayProvider),
  );

  @override
  void dispose() {
    _body?.dispose();
    _focus.dispose();
    super.dispose();
  }

  TextEditingController _bodyFor(DiaryEditState state) =>
      _body ??= TextEditingController(text: state.initialBody);

  bool get _savable =>
      (_body?.text.trim().isNotEmpty ?? false) && !_celebrating;

  Future<void> _save() async {
    final body = _body;
    if (body == null) return;
    final l10n = AppLocalizations.of(context);
    final notifier = ref.read(diaryEditProvider(_target).notifier);
    final Diary? saved;
    try {
      saved = await notifier.save(body.text);
    } on Object catch (error) {
      if (!mounted || isConnectivityError(error)) return;
      // `diary.guide_invalid`도 전용 문구 없이 일반 저장 실패 문구입니다(A115).
      showMyungliToast(
        context,
        errorMessage(l10n, error is AppError ? error : UnexpectedError(error)),
      );
      return;
    }
    if (saved == null || !mounted) return;
    _focus.unfocus();
    setState(() => _celebrating = true);
    await _editor.playSaveSequence(
      diaryTagChipsOf(
        context,
        ref.read(depthSheetsProvider),
        ref.read(glossaryProvider).value,
        saved.tags.featured,
      ),
    );
    if (!mounted) return;
    showMyungliToast(context, l10n.diaryEditSavedTags);
    context.pushReplacement(diaryPathOf(ScreenIds.diaryView, saved.id));
  }

  /// 상단 바 뒤로. `Navigator.maybePop`이라 저장 중에는 [PopScope]가 막습니다. 스택 바닥
  /// (딥링크, 복원)이면 일기 목록으로 가되 저장 중에는 가지 않습니다.
  void _back() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).maybePop();
      return;
    }
    if (ref.read(diaryEditProvider(_target)).value?.saving ?? false) return;
    context.go(pathOf(ScreenIds.diaryList));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final edit = ref.watch(diaryEditProvider(_target));
    // 저장 순간의 태그 칩 이름과 일진 독음을 위해 용어 사전을 미리 받아 둡니다.
    ref.watch(glossaryProvider);
    final state = edit.value;
    if (state != null) _bodyFor(state);
    final saving = state?.saving ?? false;
    return PopScope(
      // 저장 중에 화면이 사라지면 결과를 알릴 곳이 없습니다.
      canPop: !saving,
      child: Semantics(
        identifier: ScreenIds.diaryEdit,
        child: Scaffold(
          key: const ValueKey(ScreenIds.diaryEdit),
          body: SafeArea(
            child: Column(
              children: [
                ListenableBuilder(
                  listenable: Listenable.merge([_focus, ?_body]),
                  builder: (context, _) => MyungliAppBar.edit(
                    onBack: _back,
                    title: l10n.diaryEditBarTitle,
                    titleIdentifier: SlotIds.diaryEditBarTitle,
                    status: _statusOf(l10n, state),
                    textAction: AppBarTextAction(
                      label: l10n.diaryEditSave,
                      identifier: SlotIds.diaryEditSaveCta,
                      enabled: _savable,
                      saving: saving,
                      onTap: () => unawaited(_save()),
                    ),
                  ),
                ),
                Expanded(
                  child: _isNotFound(edit)
                      ? EmptyState(body: l10n.errorDiaryNotFound)
                      : ScreenStateView<DiaryEditState>(
                          value: edit,
                          onRetry: () =>
                              ref.invalidate(diaryEditProvider(_target)),
                          skeleton: _DiaryEditSkeleton(
                            date: switch (_target) {
                              NewDiaryEditTarget(:final date) => date,
                              ExistingDiaryEditTarget() => null,
                            },
                          ),
                          data: (state) => _DiaryEditBody(
                            target: _target,
                            state: state,
                            body: _bodyFor(state),
                            focus: _focus,
                            editor: _editor,
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

  /// 가운데 초안 상태: 본문에 초점이 있고(쓰는 중) 저장 상태가 있을 때만. 그 밖에는 제목입니다
  /// (`app-bar.variants.edit.parts.center`).
  Widget? _statusOf(AppLocalizations l10n, DiaryEditState? state) {
    final status = state?.status;
    final body = _body;
    if (status == null || body == null || !_focus.hasFocus) return null;
    return Semantics(
      identifier: SlotIds.diaryEditDraftStatus,
      child: DraftIndicator(
        state: _indicatorOf(status),
        label: _statusLabel(l10n, status),
        length: body.text.characters.length,
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

/// [date]의 일 숫자 글자(`diary-edit.date.day`).
///
/// 숫자만 큰 글자로 그려(44 고정폭) 언어별 날 단위 글자(`일`, `日`)는 붙이지 않습니다.
String _dayText(AppLocalizations l10n, CalendarDate date) =>
    l10n.diaryEditDateDay('${date.day}');

/// [date]의 월과 요일 글자(`diary-edit.date.month`).
String _monthText(AppLocalizations l10n, String locale, CalendarDate date) =>
    l10n.diaryEditDateMonth(
      DateFormat(
        'MMMM EEEE',
        locale,
      ).format(DateTime(date.year, date.month, date.day)),
    );

/// 날짜 블록, (오프라인이면) 배너, 종이. 스크롤을 끌면 키보드가 내려갑니다(F-013).
class _DiaryEditBody extends ConsumerWidget {
  const new({
    required this.target,
    required this.state,
    required this.body,
    required this.focus,
    required this.editor,
  });

  final DiaryEditTarget target;
  final DiaryEditState state;
  final TextEditingController body;
  final FocusNode focus;
  final DiaryEditorController editor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final names = ref.watch(glossaryProvider).value;
    final pillar = state.dayPillar;
    final notifier = ref.read(diaryEditProvider(target).notifier);
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(
        Space.s20,
        Space.s16,
        Space.s20,
        Space.s24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: DateBlock(
              day: _dayText(l10n, state.date),
              monthWeekday: _monthText(l10n, locale, state.date),
              iljin: pillar == null
                  ? null
                  : l10n.diaryEditDateIljin(pillarTextOf(pillar, names)),
              iljinLoading: state.dayPillarPending,
            ),
          ),
          const SizedBox(height: Space.s24),
          NoticeBanner(
            variant: NoticeBannerVariant.offline,
            message: l10n.diaryEditOfflineNotice,
            present: state.offline,
            identifier: SlotIds.diaryEditOfflineNotice,
          ),
          DiaryEditor.edit(
            date: state.date,
            controller: body,
            focusNode: focus,
            question: state.question,
            questionSlotId: SlotIds.diaryEditGuideQuestion,
            onSwapQuestion: state.canSwapQuestion
                ? notifier.swapQuestion
                : null,
            placeholder: l10n.diaryEditBodyPlaceholder,
            editorController: editor,
            onChanged: notifier.edit,
          ),
        ],
      ),
    );
  }
}

/// 오늘 풀이를 받는 동안: [_DiaryEditBody]와 같은 배치(좌우 20, 위 16)에 날짜 블록(새 일기면
/// 기기 날짜는 바로, 일진만 뼈), 그 아래 `diary-editor` `edit` 뼈(V66).
class _DiaryEditSkeleton extends StatelessWidget {
  const new({required this.date});

  /// 새 일기의 날짜. 고치기는 일기를 받기 전이라 모릅니다.
  final CalendarDate? date;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final date = this.date;
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        Space.s20,
        Space.s16,
        Space.s20,
        Space.s24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (date != null) ...[
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: DateBlock(
                day: _dayText(l10n, date),
                monthWeekday: _monthText(l10n, locale, date),
                iljinLoading: true,
              ),
            ),
            const SizedBox(height: Space.s24),
          ],
          DiaryEditor.skeleton(variant: DiaryEditorVariant.edit, index: 1),
        ],
      ),
    );
  }
}
