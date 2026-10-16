import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart'
    show AsyncNotifierProviderFamily, KeepAliveLink, ProviderFamily;
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
import 'package:myungli_diary/features/schedule/model/schedule_order.dart';
import 'package:myungli_diary/features/schedule/model/schedule_range.dart';
import 'package:myungli_diary/features/schedule/model/today_schedule_summary.dart';
import 'package:uuid/uuid.dart';

/// 일정 저장소. 로그인한 계정에서만 읽을 수 있습니다.
final scheduleRepositoryProvider = Provider<ScheduleRepository>(
  (ref) => ScheduleRepository(ref.watch(restClientProvider)),
);

/// 지금 메모리에 들고 있는 일정 범위들. 저장 뒤 어느 범위를 다시 받을지 고를 때 씁니다.
final class _HeldRanges {
  final _ranges = <ScheduleRange>{};

  /// [range]를 들고 있다고 적습니다.
  void add(ScheduleRange range) => _ranges.add(range);

  /// [range]를 버렸다고 적습니다.
  void remove(ScheduleRange range) => _ranges.remove(range);

  /// [dates] 중 하나라도 품은, 들고 있는 범위.
  List<ScheduleRange> containingAny(List<CalendarDate> dates) => [
    for (final range in _ranges)
      if (dates.any((date) => rangeContains(range, date))) range,
  ];
}

final _heldRangesProvider = Provider<_HeldRanges>((ref) => _HeldRanges());

/// 로그아웃([AuthEvent.signedOut]) 이벤트.
Stream<AuthEvent> _signOutsOf(Ref ref) => ref
    .watch(tokenStoreProvider)
    .events
    .where((event) => event == AuthEvent.signedOut);

/// 한 범위의 일정(A34). 메모리에만 들고 앱을 끄면 버립니다(일정은 캐시하지 않음, A5).
///
/// 여러 날 범위(달력 격자)는 구독이 끝나도 버리지 않으므로, 오프라인이면 받아 둔 범위의 점과
/// 목록을 그대로 보입니다. 하루 범위(`from == to`, 오늘 요약·그날 시트)는 구독하는 동안만
/// 들고 있어, 오늘이 바뀌면 지난 날의 범위가 남지 않습니다.
///
/// 로그아웃([AuthEvent.signedOut])하면 받아 둔 값을 빈 목록으로 버리고 붙들기를 놓습니다.
/// 구독이 없는 범위는 사라지고, 보고 있는 범위는 빈 목록에서 다시 받습니다(이전 계정 일정이
/// 남지 않음).
///
/// 첫 받기와 [SchedulesInRange.refresh]가 겹치면 나중에 시작한 요청의 응답만 반영합니다.
/// 늦게 끝난 옛 요청이 새 값을 덮지 않습니다.
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

  /// 마지막으로 시작한 요청 번호.
  int _started = 0;

  /// 마지막으로 반영한 응답의 요청 번호와 값.
  int _applied = 0;
  List<Schedule>? _appliedValue;

  @override
  Future<List<Schedule>> build() async {
    final keepAlive = range.from == range.to ? null : ref.keepAlive();
    final signOuts = _signOutsOf(ref).listen((_) => _forget(keepAlive));
    final held = ref.read(_heldRangesProvider)..add(range);
    ref.onDispose(() {
      unawaited(signOuts.cancel());
      held.remove(range);
    });
    final repository = ref.watch(scheduleRepositoryProvider);
    final request = ++_started;
    try {
      final fresh = await repository.list(range.from, range.to);
      if (_accept(request, fresh)) {
        return fresh;
      }
      // 나중 요청이 이미 반영됐으면 그 값을 지킵니다. 값이 없으면 로그아웃으로 버린 요청이고,
      // 그 build는 다시 계산되어 결과가 쓰이지 않습니다.
      return _appliedValue ?? const <Schedule>[];
    } on Object {
      // 나중에 시작한 다시 받기가 이미 성공했으면 그 값을 지킵니다.
      final newer = _appliedValue;
      if (_applied > request && newer != null) {
        return newer;
      }
      rethrow;
    }
  }

  /// 범위를 다시 받습니다.
  ///
  /// 실패해도 받아 둔 목록이 있으면 그대로 둡니다(오프라인 표시, A34). 받아 둔 목록이
  /// 없고 이것이 마지막 요청일 때만 오류 상태가 됩니다.
  Future<void> refresh() async {
    final repository = ref.read(scheduleRepositoryProvider);
    final request = ++_started;
    final List<Schedule> fresh;
    try {
      fresh = await repository.list(range.from, range.to);
    } on Object catch (error, stackTrace) {
      if (!ref.mounted) {
        return;
      }
      if (request == _started && !state.hasValue) {
        state = AsyncError(error, stackTrace);
      }
      return;
    }
    if (!ref.mounted) {
      return;
    }
    if (_accept(request, fresh)) {
      state = AsyncData(fresh);
    }
  }

  /// [request]의 응답 [value]가 반영한 것보다 새 요청이면 기록하고 true입니다.
  bool _accept(int request, List<Schedule> value) {
    if (request <= _applied) {
      return false;
    }
    _applied = request;
    _appliedValue = value;
    return true;
  }

  /// 로그아웃: 받아 둔 값을 버리고 붙들기를 놓습니다. 진행 중인 요청의 응답은 반영하지 않습니다.
  ///
  /// Riverpod은 새 상태(loading 포함)에 이전 값을 늘 옮겨 담으므로, 먼저 [_forgottenSchedules]로
  /// 덮어 이전 계정 일정이 다시 받는 동안에도 남지 않게 합니다. 이 값은 "받은 빈 목록"이
  /// 아니므로 [schedulesOnDateProvider]는 값 없는 상태로 바꿔 내보냅니다.
  void _forget(KeepAliveLink? keepAlive) {
    _applied = ++_started;
    _appliedValue = null;
    state = AsyncData(_forgottenSchedules);
    keepAlive?.close();
    ref.invalidateSelf();
  }
}

/// 로그아웃으로 버린 범위가 다음 응답 전까지 들고 있는 빈 목록. 받은 빈 목록(일정 없음)과
/// 구별하려고 따로 만든 인스턴스이고 `identical`로만 비교합니다.
final List<Schedule> _forgottenSchedules = List.unmodifiable(<Schedule>[]);

/// [state]가 로그아웃으로 버린 값([_forgottenSchedules])을 들고 있으면 그 값을 뺀 상태.
///
/// 다시 받는 중이면 값 없는 loading, 다시 받기가 실패했으면 값 없는 오류입니다. 그래서 그날
/// 시트가 잠깐 "일정 없음"을 보이지 않습니다.
AsyncValue<List<Schedule>> _withoutForgotten(AsyncValue<List<Schedule>> state) {
  if (!identical(state.value, _forgottenSchedules)) {
    return state;
  }
  final error = state.error;
  if (state.isLoading || error == null) {
    return const AsyncLoading<List<Schedule>>();
  }
  return AsyncError<List<Schedule>>(
    error,
    state.stackTrace ?? StackTrace.empty,
  );
}

/// 하루(`date`)의 일정, [inDayOrder] 순서(`day-sheet` 목록).
///
/// 같은 날을 두 번 받지 않습니다. 메모리에 들고 있는 여러 날 범위(달력 격자) 중 그 날을 품고
/// 값이 있거나 아직 받는 중인 범위가 있으면 그 범위를 구독해 그 날만 거릅니다. 받는 중이면
/// 따로 받지 않고 그 응답을 기다립니다. 그런 범위가 없거나 격자를 받지 못했으면 그 날 하루
/// 범위(`from == to`)를 받습니다(A34). 고른 범위의 상태(loading·error·값)를 그대로 옮깁니다.
/// 고른 범위의 상태가 바뀌면 다시 고르므로, 기다리던 격자가 실패하면 하루 범위로 넘어갑니다.
/// 저장이 성공하면 [ScheduleEditor]가 그 날을 품은 범위를 다시 받으므로 여기도 따라 바뀝니다.
/// 로그아웃 뒤 다시 받는 동안은 값 없는 loading입니다(빈 목록으로 보이지 않음).
final ProviderFamily<AsyncValue<List<Schedule>>, CalendarDate>
schedulesOnDateProvider = Provider.autoDispose
    .family<AsyncValue<List<Schedule>>, CalendarDate>((ref, date) {
      final range = _heldGridFor(ref, date) ?? (from: date, to: date);
      final iso = date.toIso();
      return _withoutForgotten(ref.watch(schedulesInRangeProvider(range)))
          .whenData(
            (schedules) =>
                inDayOrder(schedules.where((schedule) => schedule.date == iso)),
          );
    });

/// [date]를 품고 값이 있거나 받는 중인, 들고 있는 여러 날 범위. 없으면 null입니다.
///
/// 값 없이 실패한 범위는 고르지 않습니다(그 날은 하루 범위로 따로 받음).
ScheduleRange? _heldGridFor(Ref ref, CalendarDate date) {
  for (final range in ref.read(_heldRangesProvider).containingAny([date])) {
    if (range.from == range.to) {
      continue;
    }
    final state = ref.read(schedulesInRangeProvider(range));
    if (state.hasValue || !state.hasError) {
      return range;
    }
  }
  return null;
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
  bool build() {
    // 이전 계정의 대기 저장(키와 본문)을 다음 계정에 넘기지 않습니다.
    final signOuts = _signOutsOf(ref).listen((_) => _pendingCreate = null);
    ref.onDispose(signOuts.cancel);
    return false;
  }

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
    final targets = ref.read(_heldRangesProvider).containingAny(dates);
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
/// null이라 줄을 그리지 않습니다(today의 다른 상태에 영향 없음). 구독이 끝나면 버립니다.
final Provider<TodayScheduleSummary?> todayScheduleSummaryProvider =
    Provider.autoDispose<TodayScheduleSummary?>((ref) {
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
