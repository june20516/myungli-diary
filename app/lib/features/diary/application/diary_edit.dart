import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart'
    show AsyncNotifierProviderFamily, FutureProviderFamily;
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/gen/model/daily.dart';
import 'package:myungli_diary/core/api/gen/model/diary.dart';
import 'package:myungli_diary/core/api/gen/model/guide_choice.dart';
import 'package:myungli_diary/core/api/gen/model/pillar.dart';
import 'package:myungli_diary/core/api/gen/model/rendered_text.dart';
import 'package:myungli_diary/core/api/gen/model/slot_text.dart';
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
import 'package:myungli_diary/features/me/application/diary_stats_provider.dart';
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
    required this.fromDraft,
    this.candidates = const [],
    this.questionIndex = 0,
    this.savedQuestion,
    this.dayPillar,
    this.dayPillarPending = false,
    this.status,
    this.saving = false,
    this.offline = false,
  }) : assert(
         candidates.length == 0 ||
             (questionIndex >= 0 && questionIndex < candidates.length),
         'questionIndex는 후보 범위 안이어야 합니다',
       );

  /// 일기 날짜. 새 일기는 열 때의 날짜, 고치기는 그 일기의 날짜입니다.
  final CalendarDate date;

  /// 화면을 열 때의 본문: 초안이 있으면 초안, 없으면 저장된 본문, 둘 다 없으면 빈 글.
  final String initialBody;

  /// 이미 저장된 일기. 새로 쓰면 null입니다.
  final Diary? existing;

  /// 그날 오늘의 질문 후보(`Daily.guideCandidates`, server 순서, 빈 문장은 뺌, A47·A115).
  /// 고치기와 후보를 받지 못한 새 일기(오프라인)는 비어 있습니다.
  final List<SlotText> candidates;

  /// [candidates] 가운데 고른 후보의 순번.
  final int questionIndex;

  /// 고치는 일기에 저장된 질문(`Diary.guideQuestion`). 새 일기는 null입니다.
  final RenderedText? savedQuestion;

  /// 그날 일진(`Daily.dayPillar`, `date-block`). 받지 못했으면 null입니다.
  final Pillar? dayPillar;

  /// 일진을 아직 받는 중인지(고치기는 화면을 먼저 열고 일진을 뒤에서 받음).
  final bool dayPillarPending;

  /// 기기에 남은 초안으로 시작했는지(IA `draft`).
  final bool fromDraft;

  /// 초안 저장 상태. null이면 아직 아무것도 저장하지 않았습니다.
  final DiaryDraftStatus? status;

  /// 저장 요청 중인지.
  final bool saving;

  /// 마지막 받기·저장이 연결 오류로 실패했는지(IA `offline`, A49).
  final bool offline;

  /// 보일 질문: 고른 후보, 없으면 저장된 질문. 둘 다 없으면 null입니다(질문 줄 없음).
  RenderedText? get question =>
      candidates.isEmpty ? savedQuestion : candidates[questionIndex].text;

  /// 질문 바꾸기를 보일지: 새 일기이고 후보가 둘 이상일 때(A115, `swap.visibleWhen`).
  bool get canSwapQuestion => existing == null && candidates.length >= 2;

  /// 저장 요청에 실을 고른 질문. 후보를 받지 못했으면 null이고 필드를 뺍니다(A115).
  GuideChoice? get guideChoice =>
      candidates.isEmpty ? null : guideChoiceOf(candidates[questionIndex]);

  /// 값을 바꾼 상태.
  DiaryEditState copyWith({
    Diary? existing,
    List<SlotText>? candidates,
    int? questionIndex,
    Pillar? dayPillar,
    bool? dayPillarPending,
    DiaryDraftStatus? status,
    bool? saving,
    bool? offline,
  }) => DiaryEditState(
    date: date,
    initialBody: initialBody,
    existing: existing ?? this.existing,
    fromDraft: fromDraft,
    candidates: candidates ?? this.candidates,
    questionIndex: questionIndex ?? this.questionIndex,
    savedQuestion: savedQuestion,
    dayPillar: dayPillar ?? this.dayPillar,
    dayPillarPending: dayPillarPending ?? this.dayPillarPending,
    status: status ?? this.status,
    saving: saving ?? this.saving,
    offline: offline ?? this.offline,
  );
}

/// 후보 [candidate]의 고른 질문 값(`createDiary.guideQuestion`).
GuideChoice guideChoiceOf(SlotText candidate) => GuideChoice(
  messageKey: candidate.messageKey,
  variant: candidate.variant.value,
);

/// [a]와 [b]가 같은 질문인지(둘 다 없음도 같음).
bool sameGuideChoice(GuideChoice? a, GuideChoice? b) =>
    a?.messageKey == b?.messageKey && a?.variant == b?.variant;

/// 일기 쓰기(`diary-edit`)의 상태와 동작. family 값은 새 일기(날짜)이거나 고칠 일기(id)입니다.
///
/// * 열 때 새 일기는 그날 새 일기 초안과 오늘 풀이(질문 후보, 일진)를, 고치기는 그 일기와 그
///   일기 초안, 일진을 읽습니다(A47·A48). 새 일기에서 풀이를 받지 못해도 쓰기를 막지 않고, 연결
///   오류면 [DiaryEditState.offline]입니다. 고치는 일기를 받지 못하면 날짜를 몰라 오류로 엽니다
///   (404는 `diary.not_found`).
/// * 새 일기는 [DiaryEdit.swapQuestion]으로 그날 후보를 돌고, 고른 질문은 초안과 저장 요청에
///   실립니다(A115).
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

  /// 저장 요청 중인지. [save]가 시작하면 true, 두 경로(성공·실패) 끝에서 false입니다.
  /// dispose에서 state를 읽지 않으려고 필드로 둡니다.
  bool _saving = false;

  /// dispose 중에도 쓸 수 있게 build에서 잡아 둔 초안 저장소와 crash 보고기(dispose 안에서는
  /// `ref.read`를 쓸 수 없음).
  late DiaryDraftStore _drafts;
  late CrashReporter _crashReporter;

  /// 새 일기 저장 요청의 본문, 고른 질문, `Idempotency-Key`. 실패 뒤 같은 본문과 같은 질문을
  /// 다시 저장하면 같은 키를 쓰고(시간 초과 뒤 일기가 두 편 생기지 않게), 성공하면 비웁니다.
  ({String body, GuideChoice? guide, String key})? _pendingCreate;

  /// 화면이 마지막으로 알려 준 본문. 질문만 바꿔도 초안을 다시 쓰는 데 씁니다.
  String _latestBody = '';

  /// 초안에 남길 고른 질문. dispose 안에서도 쓰려고 state 밖에 둡니다. 후보를 받지 못한
  /// 동안은 초안에 있던 값을 그대로 지킵니다(보낼 때는 빼지만 다음에 열면 되살림).
  GuideChoice? _draftGuide;

  @override
  Future<DiaryEditState> build() async {
    final drafts = ref.watch(diaryDraftStoreProvider);
    _drafts = drafts;
    _crashReporter = ref.read(crashReporterProvider);
    ref.onDispose(() {
      _draftTimer?.cancel();
      // 저장 중이면 아직 쓰지 않은 입력은 저장 경로가 끝에서 맡습니다(옛 대상인 새 일기 초안에
      // 쓰면 저장된 일기 초안과 겹침). 아니면 화면을 떠나며 남은 초안을 씁니다.
      final pending = _pendingDraft;
      final draftTarget = _draftTarget;
      if (!_saving && pending != null && draftTarget != null) {
        unawaited(_writeDraft(drafts, draftTarget, pending));
      }
    });
    switch (target) {
      case NewDiaryEditTarget(:final date):
        final draftTarget = DiaryDraftTarget.newOn(date);
        _draftTarget = draftTarget;
        final draft = await drafts.find(draftTarget);
        var offline = false;
        final daily = await _daily(date, onOffline: () => offline = true);
        final candidates = _usableCandidates(daily);
        final restored = draft?.guideMessageKey == null
            ? null
            : GuideChoice(
                messageKey: draft!.guideMessageKey!,
                variant: draft.guideVariant ?? '',
              );
        final index = restored == null
            ? -1
            : candidates.indexWhere(
                (c) => sameGuideChoice(guideChoiceOf(c), restored),
              );
        final opened = DiaryEditState(
          date: date,
          initialBody: draft?.body ?? '',
          existing: null,
          candidates: candidates,
          questionIndex: index < 0 ? 0 : index,
          dayPillar: daily?.dayPillar,
          fromDraft: draft != null,
          status: draft != null ? DiaryDraftStatus.local : null,
          offline: offline,
        );
        _latestBody = opened.initialBody;
        _draftGuide = candidates.isEmpty ? restored : opened.guideChoice;
        return opened;
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
        final opened = DiaryEditState(
          date: date,
          initialBody: draft ?? existing.body,
          existing: existing,
          savedQuestion: _usableQuestion(existing.guideQuestion),
          dayPillarPending: true,
          fromDraft: draft != null,
          status: draft != null
              ? DiaryDraftStatus.local
              : DiaryDraftStatus.saved,
        );
        _latestBody = opened.initialBody;
        // 일진만 쓰므로 기다리지 않고 열고, 받으면 날짜 블록에 채웁니다. 받지 못하면 일진 줄만
        // 빠집니다(저장은 막지 않음).
        unawaited(_fillDayPillar(date));
        return opened;
    }
  }

  /// 고치기 화면의 일진을 뒤에서 받아 채웁니다.
  ///
  /// 어떤 실패에서도 일진 줄만 빼고 [DiaryEditState.dayPillarPending]을 풉니다. 조용히 넘기는
  /// 실패는 [recordUnlessAppError] 규칙(분류된 실패는 삼키고 예상 밖 오류만 비치명 기록)을
  /// 따릅니다. 일진이 build보다 먼저 와도 build가 끝난 뒤([future])에 반영합니다.
  Future<void> _fillDayPillar(CalendarDate date) async {
    Pillar? pillar;
    try {
      pillar = (await _daily(date, onOffline: () {}))?.dayPillar;
    } on Object catch (error, stackTrace) {
      recordUnlessAppError(_crashReporter, error, stackTrace);
    }
    try {
      await future;
    } on Object {
      // build가 실패했으면 채울 화면이 없습니다(오류는 build가 이미 상태로 남김).
      return;
    }
    if (!ref.mounted) return;
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(dayPillar: pillar, dayPillarPending: false),
    );
  }

  /// [daily]의 질문 후보 가운데 빈 문장이 아닌 것(A47). 받지 못했으면 빈 목록입니다.
  List<SlotText> _usableCandidates(Daily? daily) => [
    for (final candidate in daily?.guideCandidates ?? const <SlotText>[])
      if (_usableQuestion(candidate.text) != null) candidate,
  ];

  /// 빈 문장이면 질문이 없는 것으로 칩니다(A47).
  RenderedText? _usableQuestion(RenderedText? question) =>
      question == null || plainTextOf(question).trim().isEmpty
      ? null
      : question;

  /// 그날 오늘 풀이(`getDaily`, 질문 후보와 일진, A47). 받지 못하면 null이고 쓰기를 막지
  /// 않습니다.
  Future<Daily?> _daily(
    CalendarDate date, {
    required VoidCallback onOffline,
  }) async {
    try {
      return await ref.read(dailyRepositoryProvider).fetch(date);
    } on Object catch (error, stackTrace) {
      if (isConnectivityError(error)) {
        onOffline();
      } else if (error is! ProblemError) {
        // await 뒤라 화면이 닫혔을 수 있어 `ref.read` 대신 build에서 잡아 둔 보고기를 씁니다.
        _crashReporter.record(CrashSummary.from(error), stackTrace);
      }
      return null;
    }
  }

  /// 다음 질문 후보로 바꿉니다(끝에서 처음으로, A115). 새 일기이고 후보가 둘 이상일 때만이고,
  /// 본문은 그대로이며 쓴 글이 있으면 고른 질문을 초안에 다시 씁니다.
  void swapQuestion() {
    final current = state.value;
    if (current == null || !current.canSwapQuestion || current.saving) {
      return;
    }
    final next = current.copyWith(
      questionIndex: (current.questionIndex + 1) % current.candidates.length,
    );
    state = AsyncData(next);
    _draftGuide = next.guideChoice;
    if (_latestBody.trim().isNotEmpty) {
      edit(_latestBody);
    }
  }

  /// 본문이 [body]로 바뀌었습니다. 입력이 멈추면 초안을 씁니다(A48).
  void edit(String body) {
    _latestBody = body;
    _pendingDraft = body;
    _draftTimer?.cancel();
    _draftTimer = Timer(diaryDraftDelay, () => unawaited(_flushDraft()));
  }

  Future<void> _flushDraft() async {
    final body = _pendingDraft;
    final draftTarget = _draftTarget;
    if (body == null || draftTarget == null || !ref.mounted) {
      return;
    }
    // 저장 중에 들어온 입력은 저장이 끝난 뒤 새 대상에 씁니다([save]).
    if (state.value?.saving ?? false) {
      return;
    }
    _pendingDraft = null;
    await _writeDraft(_drafts, draftTarget, body);
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
    _saving = true;
    state = AsyncData(
      current.copyWith(saving: true, status: DiaryDraftStatus.saving),
    );
    final drafts = _drafts;
    final Diary saved;
    try {
      saved = await _send(current, body);
    } on Object catch (error) {
      // 고른 질문이 그날 후보에 없으면 오늘 풀이를 다시 읽어 후보를 새로 받습니다(A115).
      // 초안은 새 후보 기준의 질문으로 씁니다.
      var refreshed = current;
      if (error is ProblemError && error.code == 'diary.guide_invalid') {
        refreshed = await _refreshCandidates(current);
      }
      // 저장 중에 더 입력했다면 그 글이 최신입니다.
      final latest = _pendingDraft ?? body;
      _draftTimer?.cancel();
      _pendingDraft = null;
      await _writeDraft(drafts, draftTarget, latest);
      _saving = false;
      if (ref.mounted) {
        state = AsyncData(
          refreshed.copyWith(
            saving: false,
            status: DiaryDraftStatus.local,
            offline: isConnectivityError(error),
          ),
        );
        _rearmDraftTimer();
      }
      rethrow;
    }
    await _guard(() => drafts.remove(draftTarget));
    // 새 일기를 저장했으면 이 화면의 다음 초안은 방금 쓴 일기에 붙습니다.
    final savedTarget = DiaryDraftTarget.existing(
      date: current.date,
      id: saved.id,
    );
    _draftTarget = savedTarget;
    // 저장한 일기의 초안에는 고른 질문을 남기지 않습니다(고치기는 질문을 바꾸지 않음).
    _draftGuide = null;
    // 저장 중에 들어온 입력이 저장한 본문과 다르면 새 대상의 초안으로 남깁니다.
    final later = _pendingDraft;
    _draftTimer?.cancel();
    _pendingDraft = null;
    final keepLater = later != null && later != body;
    if (keepLater) {
      await _writeDraft(drafts, savedTarget, later);
    }
    _saving = false;
    if (ref.mounted) {
      // 본문만 고친 저장은 편수와 날의 성격, 태그를 바꾸지 않습니다(새 일기만 집계가 바뀜).
      invalidateDiaryViews(
        ref,
        current.date,
        id: saved.id,
        statsChanged: current.existing == null,
      );
      state = AsyncData(
        current.copyWith(
          existing: saved,
          saving: false,
          status: keepLater && later.trim().isNotEmpty
              ? DiaryDraftStatus.local
              : DiaryDraftStatus.saved,
          offline: false,
        ),
      );
      _rearmDraftTimer();
    }
    return saved;
  }

  /// 저장 경로가 초안을 쓰는 동안 들어온 입력은 [_flushDraft]가 saving 때문에 돌아가 타이머
  /// 없이 남습니다. 저장이 끝나면 남은 입력에 디바운스를 다시 겁니다.
  void _rearmDraftTimer() {
    final pending = _pendingDraft;
    if (pending != null) {
      edit(pending);
    }
  }

  /// 그날 오늘 풀이를 다시 받아 [current]의 후보를 바꿉니다. 고른 질문이 새 후보에도 있으면
  /// 그 질문, 없으면 첫 후보입니다. 받지 못하면 후보를 비워 질문 없이 보냅니다.
  Future<DiaryEditState> _refreshCandidates(DiaryEditState current) async {
    final chosen = current.guideChoice;
    final daily = await _daily(current.date, onOffline: () {});
    // 다시 읽지 못하면 받아 둔 후보와 고른 질문을 그대로 둡니다.
    if (daily == null) return current;
    final candidates = _usableCandidates(daily);
    final index = candidates.indexWhere(
      (c) => sameGuideChoice(guideChoiceOf(c), chosen),
    );
    final refreshed = current.copyWith(
      candidates: candidates,
      questionIndex: index < 0 ? 0 : index,
    );
    _draftGuide = refreshed.guideChoice;
    return refreshed;
  }

  Future<Diary> _send(DiaryEditState current, String body) {
    final repository = ref.read(diaryRepositoryProvider);
    final existing = current.existing;
    if (existing != null) {
      return repository.update(existing.id, body);
    }
    final guide = current.guideChoice;
    final pending = _pendingCreate;
    final key =
        pending != null &&
            pending.body == body &&
            sameGuideChoice(pending.guide, guide)
        ? pending.key
        : _uuid.v4();
    _pendingCreate = (body: body, guide: guide, key: key);
    return repository
        .create(current.date, body, idempotencyKey: key, guideQuestion: guide)
        .then((created) {
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
        : drafts.write(draftTarget, body, guide: _draftGuide),
  );

  /// 초안 쓰기는 비치명입니다. 실패하면 요약만 남깁니다(D64: 본문은 싣지 않음).
  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } on Object catch (error, stackTrace) {
      _crashReporter.record(CrashSummary.from(error), stackTrace);
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
    invalidateDiaryViews(ref, date, id: diary.id, statsChanged: true);
  }
}

/// [date] 일기가 바뀐 뒤 그 일기를 보이는 곳이 새 상태를 묻게 합니다: 일기 목록(모든 태그),
/// 그날 일기 요약, 달력 도장, [id]가 있으면 그 일기 한 편. [statsChanged](새 일기 저장,
/// 삭제)면 나 탭 회고 집계도 묻게 합니다(A119). 본문만 고친 저장은 집계가 같습니다.
void invalidateDiaryViews(
  Ref ref,
  CalendarDate date, {
  String? id,
  bool statsChanged = false,
}) {
  ref
    ..invalidate(diaryPagesProvider)
    ..invalidate(diariesOnProvider(date))
    ..invalidate(diaryDatesProvider);
  if (statsChanged) {
    ref.invalidate(diaryStatsProvider);
  }
  if (id != null) {
    ref.invalidate(diaryProvider(id));
  }
}
