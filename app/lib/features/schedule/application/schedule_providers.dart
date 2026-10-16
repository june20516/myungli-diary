import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show AsyncNotifierProviderFamily;
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/gen/model/schedule.dart';
import 'package:myungli_diary/core/api/gen/model/schedule_input.dart';
import 'package:myungli_diary/core/api/token_store.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:myungli_diary/core/clock/clock.dart';
import 'package:myungli_diary/features/schedule/data/schedule_repository.dart';
import 'package:myungli_diary/features/schedule/model/schedule_draft.dart';
import 'package:myungli_diary/features/schedule/model/schedule_gone.dart';
import 'package:myungli_diary/features/schedule/model/schedule_range.dart';
import 'package:myungli_diary/features/schedule/model/today_schedule_summary.dart';
import 'package:uuid/uuid.dart';

/// 일정 저장소. 로그인한 계정에서만 읽을 수 있습니다.
final scheduleRepositoryProvider = Provider<ScheduleRepository>(
  (ref) => ScheduleRepository(ref.watch(restClientProvider)),
);

/// 지금 메모리에 들고 있는 일정 범위들. 저장 뒤 어느 범위를 다시 받을지 고를 때 씁니다.
final _heldRangesProvider = Provider<Set<ScheduleRange>>(
  (ref) => <ScheduleRange>{},
);

/// 한 범위의 일정(A34). 메모리에만 들고 앱을 끄면 버립니다(일정은 캐시하지 않음, A5).
///
/// 구독이 끝나도 버리지 않으므로, 오프라인이면 받아 둔 범위의 점과 목록을 그대로 보입니다.
/// 로그아웃([AuthEvent.signedOut])하면 붙들기를 놓아, 구독이 없는 범위는 바로 버리고 보고
/// 있는 범위는 화면이 떠날 때 버립니다(이전 계정 일정이 다음 계정에 남지 않음).
/// 만들기·고치기·지우기가 성공하면 [ScheduleEditor]가 바뀐 날짜를 품은 범위만
/// [SchedulesInRange.refresh]합니다. 자동 재시도는 끕니다(실패는 오류 상태로 남김).
final AsyncNotifierProviderFamily<
  SchedulesInRange,
  List<Schedule>,
  ScheduleRange
>
schedulesInRangeProvider = AsyncNotifierProvider.autoDispose
    .family<SchedulesInRange, List<Schedule>, ScheduleRange>(
      SchedulesInRange.new,
      retry: (_, _) => null,
    );

/// [schedulesInRangeProvider]의 notifier.
final class SchedulesInRange extends AsyncNotifier<List<Schedule>> {
  /// [range]의 일정을 듭니다.
  new(this.range);

  /// 받는 범위.
  final ScheduleRange range;

  @override
  Future<List<Schedule>> build() {
    final keepAlive = ref.keepAlive();
    final signOuts = ref
        .watch(tokenStoreProvider)
        .events
        .where((event) => event == AuthEvent.signedOut)
        .listen((_) => keepAlive.close());
    final held = ref.read(_heldRangesProvider)..add(range);
    ref.onDispose(() {
      unawaited(signOuts.cancel());
      held.remove(range);
    });
    return ref.watch(scheduleRepositoryProvider).list(range.from, range.to);
  }

  /// 범위를 다시 받습니다.
  ///
  /// 실패해도 받아 둔 목록이 있으면 그대로 둡니다(오프라인 표시, A34). 받아 둔 목록이
  /// 없을 때만 오류 상태가 됩니다.
  Future<void> refresh() async {
    final List<Schedule> fresh;
    try {
      fresh = await ref
          .read(scheduleRepositoryProvider)
          .list(range.from, range.to);
    } on Object catch (error, stackTrace) {
      if (!state.hasValue) {
        state = AsyncError(error, stackTrace);
      }
      return;
    }
    state = AsyncData(fresh);
  }
}

/// 일정 만들기·고치기·지우기. 상태는 처리 중인지입니다(화면이 저장 단추를 막는 데 씀).
final scheduleEditorProvider = NotifierProvider<ScheduleEditor, bool>(
  ScheduleEditor.new,
);

/// 일정 쓰기 동작. 저장은 온라인에서만 합니다(D47②): 연결이 없으면 요청은 server에 닿지
/// 않고 [AppError]로 끝나며, 대기열에 두지 않습니다.
final class ScheduleEditor extends Notifier<bool> {
  static const _uuid = Uuid();

  /// 마지막으로 실패한 만들기의 본문과 키. 같은 초안을 다시 저장하면 같은 키로 보내
  /// server에 닿았는데 응답만 잃은 경우에도 두 번 만들어지지 않게 합니다.
  ({ScheduleInput input, String key})? _pendingCreate;

  @override
  bool build() => false;

  /// [draft]를 저장합니다. [original]이 없으면 만들기, 있으면 고치기입니다.
  ///
  /// * 처리 중에 다시 부르면 무시하고 null을 돌려줍니다(두 번 누름).
  /// * 만들기는 동작마다 `Idempotency-Key` 하나(uuid v4)이고, 실패 뒤 같은 초안을 다시
  ///   저장하면 같은 키를 씁니다.
  /// * 고치기는 바뀐 필드만 보냅니다([ScheduleDraft.patchFrom], A36). 바뀐 것이 없으면
  ///   요청하지 않고 [original]을 돌려줍니다.
  /// * 성공하면 옛 날짜·새 날짜를 품은 범위를 다시 받은 뒤 저장된 일정을 돌려줍니다.
  /// * 일정이 이미 없으면(404) 그 날짜의 범위를 다시 받고 [ScheduleGone]을 던집니다(A41).
  /// * 그 밖의 실패는 [AppError]를 그대로 던집니다.
  Future<Schedule?> save(ScheduleDraft draft, {Schedule? original}) async {
    if (state) {
      return null;
    }
    if (original == null) {
      return await _run(() => _create(draft));
    }
    final patch = draft.patchFrom(original);
    if (patch == null) {
      return original;
    }
    return await _run(
      () => ref.read(scheduleRepositoryProvider).update(original.id, patch),
      original: original,
    );
  }

  /// [schedule]을 지웁니다. 처리 중이라 무시했으면 false, 지웠으면 true입니다.
  ///
  /// 성공·404 모두 그 날짜의 범위를 다시 받습니다. 404면 [ScheduleGone]을 던집니다(A41).
  Future<bool> delete(Schedule schedule) async {
    if (state) {
      return false;
    }
    await _run<void>(
      () => ref.read(scheduleRepositoryProvider).delete(schedule.id),
      original: schedule,
    );
    return true;
  }

  Future<Schedule> _create(ScheduleDraft draft) async {
    final input = draft.toInput();
    final pending = _pendingCreate;
    final key = pending != null && pending.input == input
        ? pending.key
        : _uuid.v4();
    _pendingCreate = (input: input, key: key);
    final created = await ref
        .read(scheduleRepositoryProvider)
        .create(input, idempotencyKey: key);
    _pendingCreate = null;
    return created;
  }

  /// [action]을 처리 중 상태로 실행하고, 끝나면 바뀐 날짜의 범위를 다시 받습니다.
  Future<T> _run<T>(Future<T> Function() action, {Schedule? original}) async {
    state = true;
    try {
      final result = await action();
      await _refreshAround([
        if (original != null) CalendarDate.parse(original.date),
        if (result is Schedule) CalendarDate.parse(result.date),
      ]);
      return result;
    } on ScheduleGone {
      await _refreshAround([
        if (original != null) CalendarDate.parse(original.date),
      ]);
      rethrow;
    } finally {
      state = false;
    }
  }

  /// [dates] 중 하나라도 품은, 들고 있는 범위만 다시 받습니다.
  Future<void> _refreshAround(List<CalendarDate> dates) async {
    final held = ref.read(_heldRangesProvider);
    final targets = [
      for (final range in held)
        if (dates.any((date) => rangeContains(range, date))) range,
    ];
    await Future.wait([
      for (final range in targets)
        ref.read(schedulesInRangeProvider(range).notifier).refresh(),
    ]);
  }
}

/// 오늘 화면의 일정 한 줄(`today.event.summary`) 재료(A35).
///
/// 오늘(`todayProvider`) 하루 범위의 일정과 분마다 바뀌는 벽시계(`nowMinuteProvider`)로
/// [summarizeTodaySchedules]합니다. 일정이 없거나, 아직 받는 중이거나, 불러오지 못하면
/// null이라 줄을 그리지 않습니다(today의 다른 상태에 영향 없음).
final todayScheduleSummaryProvider = Provider<TodayScheduleSummary?>((ref) {
  final today = ref.watch(todayProvider);
  final schedules = ref
      .watch(schedulesInRangeProvider((from: today, to: today)))
      .value;
  final now = ref.watch(nowMinuteProvider).value;
  if (schedules == null || now == null) {
    return null;
  }
  return summarizeTodaySchedules(schedules, now: now);
});
