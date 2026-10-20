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
import 'package:myungli_diary/features/today/application/daily_controller.dart';

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

/// [CalendarDate] 날의 일기. 없으면(404) null입니다.
///
/// 구독이 끝나면 버리고(autoDispose), 저장·삭제가 그 날을 invalidate합니다. 자동 재시도는
/// 끕니다(실패는 오류 상태로 남김).
final FutureProviderFamily<Diary?, CalendarDate> diaryOnProvider =
    FutureProvider.autoDispose.family<Diary?, CalendarDate>(
      (ref, date) => ref.watch(diaryRepositoryProvider).find(date),
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
    required this.initialBody,
    required this.existing,
    required this.question,
    required this.fromDraft,
    this.status,
    this.saving = false,
    this.offline = false,
  });

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
    initialBody: initialBody,
    existing: existing ?? this.existing,
    question: question,
    fromDraft: fromDraft,
    status: status ?? this.status,
    saving: saving ?? this.saving,
    offline: offline ?? this.offline,
  );
}

/// 일기 쓰기(`diary-edit`)의 상태와 동작. family 값은 일기 날짜입니다.
///
/// * 열 때 그날 초안·저장된 일기·질문을 읽습니다(A47·A48). 저장된 일기를 받지 못해도
///   연결 오류면 초안으로 쓸 수 있게 열고 [DiaryEditState.offline]입니다.
/// * `edit`는 입력이 멈추고 [diaryDraftDelay] 뒤 초안을 씁니다. 공백뿐이면 초안을 지웁니다.
/// * `save`는 두 번 눌러도 요청 하나이고, 실패해도 초안을 남깁니다(A49).
final AsyncNotifierProviderFamily<DiaryEdit, DiaryEditState, CalendarDate>
diaryEditProvider = AsyncNotifierProvider.autoDispose
    .family<DiaryEdit, DiaryEditState, CalendarDate>(
      DiaryEdit.new,
      retry: (_, _) => null,
    );

/// [diaryEditProvider]의 notifier.
final class DiaryEdit extends AsyncNotifier<DiaryEditState> {
  /// [date] 일기를 씁니다.
  new(this.date);

  /// 일기 날짜.
  final CalendarDate date;

  Timer? _draftTimer;
  String? _pendingDraft;

  @override
  Future<DiaryEditState> build() async {
    ref.onDispose(() {
      _draftTimer?.cancel();
      // 화면을 떠나며 아직 쓰지 않은 초안을 남깁니다.
      final pending = _pendingDraft;
      if (pending != null) {
        unawaited(_writeDraft(ref.read(diaryDraftStoreProvider), pending));
      }
    });
    final drafts = ref.watch(diaryDraftStoreProvider);
    final draft = await drafts.read(date);
    Diary? existing;
    var offline = false;
    try {
      existing = await ref.watch(diaryRepositoryProvider).find(date);
    } on Object catch (error) {
      if (!isConnectivityError(error)) {
        rethrow;
      }
      offline = true;
    }
    final question = existing != null
        ? existing.guideQuestion
        : await _guideQuestion(onOffline: () => offline = true);
    return DiaryEditState(
      initialBody: draft ?? existing?.body ?? '',
      existing: existing,
      question: question == null || plainTextOf(question).trim().isEmpty
          ? null
          : question,
      fromDraft: draft != null,
      status: draft != null
          ? DiaryDraftStatus.local
          : existing != null
          ? DiaryDraftStatus.saved
          : null,
      offline: offline,
    );
  }

  /// 그날 `getDaily`의 가이드 질문(A47). 받지 못하면 null이고 쓰기를 막지 않습니다.
  Future<RenderedText?> _guideQuestion({
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
    _pendingDraft = null;
    if (body == null || !ref.mounted) {
      return;
    }
    await _writeDraft(ref.read(diaryDraftStoreProvider), body);
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
  /// 성공하면 초안을 지우고 목록·달력 도장·오늘 카드·그날 입구가 새 상태를 묻게 합니다.
  /// 실패하면 초안을 남기고 [AppError]를 그대로 던집니다(연결 오류면 [DiaryEditState.offline]).
  Future<Diary?> save(String body) async {
    final current = state.value;
    if (current == null || current.saving || body.trim().isEmpty) {
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
      saved = await ref.read(diaryRepositoryProvider).put(date, body);
    } on Object catch (error) {
      await _writeDraft(drafts, body);
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
    await _guard(() => drafts.remove(date));
    if (ref.mounted) {
      invalidateDiaryViews(ref, date);
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

  Future<void> _writeDraft(DiaryDraftStore drafts, String body) => _guard(
    () => body.trim().isEmpty ? drafts.remove(date) : drafts.write(date, body),
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

  /// [date] 일기를 지웁니다. 처리 중이라 무시했으면 false, 지웠으면 true입니다.
  ///
  /// 성공·404(`diary.not_found`, 이미 없음) 모두 그날 초안을 지우고 목록 등이 새 상태를 묻게
  /// 합니다. 404와 그 밖의 실패는 [AppError]를 그대로 던집니다.
  Future<bool> delete(CalendarDate date) async {
    if (state) {
      return false;
    }
    state = true;
    try {
      await ref.read(diaryRepositoryProvider).delete(date);
    } on ProblemError catch (error) {
      if (error.code == 'diary.not_found') {
        await _forgetDay(date);
      }
      rethrow;
    } finally {
      state = false;
    }
    await _forgetDay(date);
    return true;
  }

  Future<void> _forgetDay(CalendarDate date) async {
    try {
      await ref.read(diaryDraftStoreProvider).remove(date);
    } on Object catch (error, stackTrace) {
      ref
          .read(crashReporterProvider)
          .record(CrashSummary.from(error), stackTrace);
    }
    invalidateDiaryViews(ref, date);
  }
}

/// [date] 일기가 바뀐 뒤 그 일기를 보이는 곳이 새 상태를 묻게 합니다: 일기 목록(모든 태그),
/// 그날 일기, 달력 도장, 그날 시트 입구, 오늘이면 오늘 가이드 카드.
void invalidateDiaryViews(Ref ref, CalendarDate date) {
  ref
    ..invalidate(diaryPagesProvider)
    ..invalidate(diaryOnProvider(date))
    ..invalidate(diaryDatesProvider)
    ..invalidate(diaryExistsOnProvider(date));
  if (date == ref.read(todayProvider)) {
    ref.invalidate(todayDiaryExistsProvider);
  }
}
