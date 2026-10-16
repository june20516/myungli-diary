import 'package:dio/dio.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/gen/api/default_api.dart';
import 'package:myungli_diary/core/api/gen/model/schedule.dart';
import 'package:myungli_diary/core/api/gen/model/schedule_input.dart';
import 'package:myungli_diary/core/api/gen/model/schedule_patch.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:myungli_diary/features/schedule/model/schedule_gone.dart';

const _notFound = 404;

/// 일정 server 요청(`listSchedules`·`createSchedule`·`updateSchedule`·
/// `deleteSchedule`).
///
/// 일정은 캐시하지 않습니다(A5, A34). 실패는 [appErrorFrom]이 분류한 [AppError]이고,
/// 고치기·지우기의 404만 [ScheduleGone]입니다(A41).
final class ScheduleRepository {
  /// [_api]로 요청합니다.
  const new(this._api);

  final DefaultApi _api;

  /// [from]~[to](둘 다 포함) 일정. 범위는 62일 이내여야 합니다(넘으면 400 [ProblemError]).
  Future<List<Schedule>> list(CalendarDate from, CalendarDate to) async {
    final response = await _call(
      () => _api.listSchedules(from: from.toIso(), to: to.toIso()),
    );
    return _required(response.data).items;
  }

  /// 일정을 만듭니다. [idempotencyKey]는 사용자 동작 하나마다 하나이고, 재시도에도 같은
  /// 값을 넘깁니다(같은 키·같은 본문이면 server가 처음 응답을 돌려줍니다).
  Future<Schedule> create(
    ScheduleInput input, {
    required String idempotencyKey,
  }) async {
    final response = await _call(
      () => _api.createSchedule(
        scheduleInput: input,
        idempotencyKey: idempotencyKey,
      ),
    );
    return _required<Schedule>(response.data);
  }

  /// [id] 일정에 [patch]의 필드만 반영합니다(merge-patch). 없으면 [ScheduleGone]입니다.
  Future<Schedule> update(String id, SchedulePatch patch) async {
    final response = await _call(
      () => _api.updateSchedule(id: id, schedulePatch: patch),
      notFoundIsGone: true,
    );
    return _required<Schedule>(response.data);
  }

  /// [id] 일정을 지웁니다. 없으면 [ScheduleGone]입니다.
  Future<void> delete(String id) async {
    await _call(() => _api.deleteSchedule(id: id), notFoundIsGone: true);
  }

  Future<Response<T>> _call<T>(
    Future<Response<T>> Function() request, {
    bool notFoundIsGone = false,
  }) async {
    try {
      return await request();
    } on DioException catch (e) {
      if (notFoundIsGone && e.response?.statusCode == _notFound) {
        throw const ScheduleGone();
      }
      throw appErrorFrom(e);
    }
  }

  T _required<T extends Object>(T? data) =>
      data ?? (throw UnexpectedError(StateError('빈 응답')));
}
