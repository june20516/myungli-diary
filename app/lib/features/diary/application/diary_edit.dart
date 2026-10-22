import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart'
    show AsyncNotifierProviderFamily, FutureProviderFamily;
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/gen/model/diary.dart';
import 'package:myungli_diary/core/api/gen/model/rendered_text.dart';
import 'package:myungli_diary/core/api/rendered_text_plain.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:myungli_diary/core/clock/clock.dart';
import 'package:myungli_diary/core/platform/crash_reporter.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';
import 'package:myungli_diary/core/storage/app_database.dart';
import 'package:myungli_diary/core/storage/cache_first.dart';
import 'package:myungli_diary/core/storage/cache_store.dart';
import 'package:myungli_diary/features/diary/application/diary_pages.dart';
import 'package:myungli_diary/features/diary/application/diary_providers.dart';
import 'package:myungli_diary/features/diary/data/diary_draft_store.dart';
import 'package:myungli_diary/features/diary/model/diary_draft_target.dart';
import 'package:myungli_diary/features/diary/model/diary_edit_target.dart';
import 'package:myungli_diary/features/today/application/daily_controller.dart';
import 'package:uuid/uuid.dart';

/// 입력이 멈춘 뒤 초안을 쓰기까지 기다리는 시간(A48).
const Duration diaryDraftDelay = Duration(milliseconds: 800);

/// 현재 계정의 일기 초안 저장소(A48).
final diaryDraftStoreProvider = Provider<DiaryDraftStore>(
  (ref) => DiaryDraftStore(
    ref.watch(appDatabaseProvider),
    accountId: ref.watch(currentAccountIdProvider),
    nowUtc: ref.watch(clockProvider).nowUtc,
  ),
);

/// [String] id 일기. 없으면(404) null입니다.
///
/// 구독이 끝나면 버리고(autoDispose), 저장·삭제가 그 id를 invalidate합니다. 자동 재시도는
/// 끕니다(실패는 오류 상태로 남김).
final FutureProviderFamily<Diary?, String> diaryProvider = FutureProvider
    .autoDispose
    .family<Diary?, String>(
      (ref, id) => ref.watch(diaryRepositoryProvider).find(id),
      retry: (_, _) => null,
    );

/// 초안 저장 상태(`draft-indicator`).
enum DiaryDraftStatus {
  /// 기기에 초안 저장됨.
  local,

  /// 보내는 중.
  saving,

  /// 서버에 저장됨.
  saved,
}

/// 일기 쓰기 화면의 상태.
@immutable
final class DiaryEditState {
  /// 상태를 만듭니다.
  const new({
    required this.date,
    required this.initialBody,
    required this.existing,
    required this.question,
    required this.fromDraft,
    this.status,
    this.saving = false,
    this.offline = false,
  });

  /// 일기 날짜. 새 일기는 열 때의 날짜, 고치기는 그 일기의 날짜입니다.
  final CalendarDate date;

  /// 화면을 열 때의 본문: 초안이 있으면 초안, 없으면 저장된 본문, 둘 다 없으면 빈 글.
  final String initialBody;

  /// 이미 저장된 일기. 새로 쓰면 null입니다.
  final Diary? existing;

  /// 오늘의 질문. 받지 못했거나 빈 문장이면 null입니다(A47).
  final RenderedText? question;

  /// 기기에 남은 초안으로 시작했는지(IA `draft`).
  final bool fromDraft;

  /// 초안 저장 상태. null이면 아직 아무것도 저장하지 않았습니다.
  final DiaryDraftStatus? status;

  /// 저장 요청 중인지.
  final bool saving;

  /// 마지막 받기·저장이 연결 오류로 실패했는지(IA `offline`, A49).
  final bool offline;

  /// 값을 바꾼 상태.
  DiaryEditState copyWith({
    Diary? existing,
    DiaryDraftStatus? status,
    bool? saving,
    bool? offline,
  }) => DiaryEditState(
    date: date,
    initialBody: initialBody,
    existing: existing ?? this.existing,
    question: question,
    fromDraft: fromDraft,
    status: status ?? this.status,
    saving: saving ?? this.saving,
    offline: offline ?? this.offline,
  );
}

/// 일기 쓰기(`diary-edit`)의 상태와 동작. family 값은 새 일기(날짜)이거나 고칠 일기(id)입니다.
///
/// * 열 때 새 일기는 그날 새 일기 초안·가이드 질문을, 고치기는 그 일기와 그 일기 초안을 읽습니다
///   (A47·A48). 새 일기에서 질문을 받지 못해도 쓰기를 막지 않고, 연결 오류면
///   [DiaryEditState.offline]입니다. 고치는 일기를 받지 못하면 날짜를 몰라 오류로 엽니다(404는
///   `diary.not_found`).
/// * `edit`는 입력이 멈추고 [diaryDraftDelay] 뒤 초안을 씁니다. 공백뿐이면 초안을 지웁니다.
/// * `save`는 두 번 눌러도 요청 하나이고, 실패해도 초안을 남깁니다(A49). 새 일기는 `create`,
///   고치기는 `update`이며 새 일기를 저장한 뒤 같은 화면에서 다시 저장하면 `update`입니다.
final AsyncNotifierProviderFamily<DiaryEdit, DiaryEditState, DiaryEditTarget>
diaryEditProvider = AsyncNotifierProvider.autoDispose
    .family<DiaryEdit, DiaryEditState, DiaryEditTarget>(
      DiaryEdit.new,
      retry: (_, _) => null,
    );

/// [diaryEditProvider]의 notifier.
final class DiaryEdit extends AsyncNotifier<DiaryEditState> {
  /// [target] 일기를 씁니다.
  new(this.target);

  /// 여는 대상.
  final DiaryEditTarget target;

  static const _uuid = Uuid();

  Timer? _draftTimer;
  String? _pendingDraft;

  /// 지금 본문이 붙는 초안 대상. 새 일기를 저장하면 그 일기로 바뀝니다.
  DiaryDraftTarget? _draftTarget;

  /// 새 일기 저장 요청의 본문과 `Idempotency-Key`. 실패 뒤 같은 본문을 다시 저장하면 같은
  /// 키를 쓰고(시간 초과 뒤 일기가 두 편 생기지 않게), 성공하면 비웁니다.
  ({String body, String key})? _pendingCreate;

  @override
  Future<DiaryEditState> build() async {
    ref.onDispose(() {
      _draftTimer?.cancel();
      // 화면을 떠나며 아직 쓰지 않은 초안을 남깁니다.
      final pending = _pendingDraft;
      final draftTarget = _draftTarget;
      if (pending != null && draftTarget != null) {
        unawaited(
          _writeDraft(ref.read(diaryDraftStoreProvider), draftTarget, pending),
        );
      }
    });
    final drafts = ref.watch(diaryDraftStoreProvider);
    switch (target) {
      case NewDiaryEditTarget(:final date):
        final draftTarget = DiaryDraftTarget.newOn(date);
        _draftTarget = draftTarget;
        final draft = await drafts.read(draftTarget);
        var offline = false;
        final question = await _guideQuestion(
          date,
          onOffline: () => offline = true,
        );
        return DiaryEditState(
          date: date,
          initialBody: draft ?? '',
          existing: null,
          question: _usableQuestion(question),
          fromDraft: draft != null,
          status: draft != null ? DiaryDraftStatus.local : null,
          offline: offline,
        );
      case ExistingDiaryEditTarget(:final id):
        final existing = await ref.watch(diaryRepositoryProvider).find(id);
        if (existing == null) {
          throw const ProblemError(
            code: 'diary.not_found',
            status: 404,
            fieldErrors: [],
            traceId: '',
          );
        }
        final date = CalendarDate.parse(existing.date);
        final draftTarget = DiaryDraftTarget.existing(date: date, id: id);
        _draftTarget = draftTarget;
        final draft = await drafts.read(draftTarget);
        return DiaryEditState(
          date: date,
          initialBody: draft ?? existing.body,
          existing: existing,
          question: _usableQuestion(existing.guideQuestion),
          fromDraft: draft != null,
          status: draft != null
              ? DiaryDraftStatus.local
              : DiaryDraftStatus.saved,
        );
    }
  }

  /// 빈 문장이면 질문이 없는 것으로 칩니다(A47).
  RenderedText? _usableQuestion(RenderedText? question) =>
      question == null || plainTextOf(question).trim().isEmpty
      ? null
      : question;

  /// 그날 `getDaily`의 가이드 질문(A47). 받지 못하면 null이고 쓰기를 막지 않습니다.
  Future<RenderedText?> _guideQuestion(
    CalendarDate date, {
    required VoidCallback onOffline,
  }) async {
    try {
      return (await ref.read(dailyRepositoryProvider).fetch(date)).guide.text;
    } on Object catch (error, stackTrace) {
      if (isConnectivityError(error)) {
        onOffline();
      } else if (error is! ProblemError) {
        ref
            .read(crashReporterProvider)
            .record(CrashSummary.from(error), stackTrace);
      }
      return null;
    }
  }

  /// 본문이 [body]로 바뀌었습니다. 입력이 멈추면 초안을 씁니다(A48).
  void edit(String body) {
    _pendingDraft = body;
    _draftTimer?.cancel();
    _draftTimer = Timer(diaryDraftDelay, () => unawaited(_flushDraft()));
  }

  Future<void> _flushDraft() async {
    final body = _pendingDraft;
    final draftTarget = _draftTarget;
    _pendingDraft = null;
    if (body == null || draftTarget == null || !ref.mounted) {
      return;
    }
    await _writeDraft(ref.read(diaryDraftStoreProvider), draftTarget, body);
    final current = state.value;
    if (!ref.mounted || current == null || current.saving) {
      return;
    }
    if (body.trim().isNotEmpty) {
      state = AsyncData(current.copyWith(status: DiaryDraftStatus.local));
    }
  }

  /// [body]를 저장합니다. 저장된 일기를 돌려주고, 처리 중이거나 빈 본문이면 null입니다.
  ///
  /// 새 일기는 `create`, 이미 있는 일기는 `update`입니다. 성공하면 그 초안을 지우고 목록·달력
  /// 도장·그날 입구가 새 상태를 묻게 합니다. 실패하면 초안을 남기고 [AppError]를 그대로 던집니다
  /// (연결 오류면 [DiaryEditState.offline]).
  Future<Diary?> save(String body) async {
    final current = state.value;
    final draftTarget = _draftTarget;
    if (current == null ||
        draftTarget == null ||
        current.saving ||
        body.trim().isEmpty) {
      return null;
    }
    _draftTimer?.cancel();
    _pendingDraft = null;
    state = AsyncData(
      current.copyWith(saving: true, status: DiaryDraftStatus.saving),
    );
    final drafts = ref.read(diaryDraftStoreProvider);
    final Diary saved;
    try {
      saved = await _send(current, body);
    } on Object catch (error) {
      await _writeDraft(drafts, draftTarget, body);
      if (ref.mounted) {
        state = AsyncData(
          current.copyWith(
            saving: false,
            status: DiaryDraftStatus.local,
            offline: isConnectivityError(error),
          ),
        );
      }
      rethrow;
    }
    await _guard(() => drafts.remove(draftTarget));
    // 새 일기를 저장했으면 이 화면의 다음 초안은 방금 쓴 일기에 붙습니다.
    _draftTarget = DiaryDraftTarget.existing(date: current.date, id: saved.id);
    if (ref.mounted) {
      invalidateDiaryViews(ref, current.date, id: saved.id);
      state = AsyncData(
        current.copyWith(
          existing: saved,
          saving: false,
          status: DiaryDraftStatus.saved,
          offline: false,
        ),
      );
    }
    return saved;
  }

  Future<Diary> _send(DiaryEditState current, String body) {
    final repository = ref.read(diaryRepositoryProvider);
    final existing = current.existing;
    if (existing != null) {
      return repository.update(existing.id, body);
    }
    final pending = _pendingCreate;
    final key = pending != null && pending.body == body
        ? pending.key
        : _uuid.v4();
    _pendingCreate = (body: body, key: key);
    return repository.create(current.date, body, idempotencyKey: key).then((
      created,
    ) {
      _pendingCreate = null;
      return created;
    });
  }

  Future<void> _writeDraft(
    DiaryDraftStore drafts,
    DiaryDraftTarget draftTarget,
    String body,
  ) => _guard(
    () => body.trim().isEmpty
        ? drafts.remove(draftTarget)
        : drafts.write(draftTarget, body),
  );

  /// 초안 쓰기는 비치명입니다. 실패하면 요약만 남깁니다(D64: 본문은 싣지 않음).
  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } on Object catch (error, stackTrace) {
      if (ref.mounted) {
        ref
            .read(crashReporterProvider)
            .record(CrashSummary.from(error), stackTrace);
      }
    }
  }
}

/// 일기를 지웁니다. 상태는 처리 중인지입니다.
final diaryDeleterProvider = NotifierProvider<DiaryDeleter, bool>(
  DiaryDeleter.new,
);

/// 일기 지우기(A50). 되살리기는 두지 않습니다.
final class DiaryDeleter extends Notifier<bool> {
  @override
  bool build() => false;

  /// [diary]를 지웁니다. 처리 중이라 무시했으면 false, 지웠으면 true입니다.
  ///
  /// 성공·404(`diary.not_found`, 이미 없음) 모두 그 일기 초안을 지우고 목록 등이 새 상태를
  /// 묻게 합니다. 404와 그 밖의 실패는 [AppError]를 그대로 던집니다.
  Future<bool> delete(Diary diary) async {
    if (state) {
      return false;
    }
    state = true;
    try {
      await ref.read(diaryRepositoryProvider).delete(diary.id);
    } on ProblemError catch (error) {
      if (error.code == 'diary.not_found') {
        await _forget(diary);
      }
      rethrow;
    } finally {
      state = false;
    }
    await _forget(diary);
    return true;
  }

  Future<void> _forget(Diary diary) async {
    final date = CalendarDate.parse(diary.date);
    try {
      await ref
          .read(diaryDraftStoreProvider)
          .remove(DiaryDraftTarget.existing(date: date, id: diary.id));
    } on Object catch (error, stackTrace) {
      ref
          .read(crashReporterProvider)
          .record(CrashSummary.from(error), stackTrace);
    }
    invalidateDiaryViews(ref, date, id: diary.id);
  }
}

/// [date] 일기가 바뀐 뒤 그 일기를 보이는 곳이 새 상태를 묻게 합니다: 일기 목록(모든 태그),
/// 그날 일기 요약, 달력 도장, [id]가 있으면 그 일기 한 편.
void invalidateDiaryViews(Ref ref, CalendarDate date, {String? id}) {
  ref
    ..invalidate(diaryPagesProvider)
    ..invalidate(diariesOnProvider(date))
    ..invalidate(diaryDatesProvider);
  if (id != null) {
    ref.invalidate(diaryProvider(id));
  }
}
