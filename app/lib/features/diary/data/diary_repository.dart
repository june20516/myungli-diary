import 'package:dio/dio.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/gen/api/default_api.dart';
import 'package:myungli_diary/core/api/gen/model/diary_list.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';

const _notFound = 404;

/// 한 번에 받는 일기 목록 수. 달력 격자(42일)를 한 번에 덮습니다(A33).
const _datesPageLimit = 100;

/// 일기 저장소. 그날 일기가 있는지와 달력 도장용 일기 날짜만 묻습니다(일기 화면은 계획 5).
final class DiaryRepository {
  /// `api`로 묻습니다.
  const new(this._api);

  final DefaultApi _api;

  /// [date]에 쓴 일기가 있으면 true, 404면 false입니다.
  ///
  /// 그 밖의 통신 실패는 [appErrorFrom]이 분류한 [AppError]입니다: 연결 없음은
  /// [OfflineError], 시간 초과는 [TimeoutError], server problem은 [ProblemError],
  /// 응답 본문을 읽지 못한 경우(역직렬화 실패 등 생성 클라이언트가 감싼 오류)는
  /// [UnexpectedError]입니다. Dio 밖에서 난 예외는 바꾸지 않고 그대로 던집니다.
  Future<bool> existsOn(CalendarDate date) async {
    try {
      await _api.getDiary(date: date.toIso());
      return true;
    } on DioException catch (e) {
      if (e.response?.statusCode == _notFound) {
        return false;
      }
      throw appErrorFrom(e);
    }
  }

  /// [from]~[to](둘 다 포함)에 쓴 일기의 날짜(A33, `listDiaries` limit 100).
  ///
  /// 범위는 달력 격자(42일)라 한 쪽으로 끝나므로 다음 쪽(`nextCursor`)은 받지 않습니다.
  /// 실패는 [existsOn]과 같은 [AppError]입니다.
  Future<Set<CalendarDate>> datesIn(CalendarDate from, CalendarDate to) async {
    final DiaryList? list;
    try {
      list = (await _api.listDiaries(
        from: from.toIso(),
        to: to.toIso(),
        limit: _datesPageLimit,
      )).data;
    } on DioException catch (e) {
      throw appErrorFrom(e);
    }
    if (list == null) {
      throw UnexpectedError(StateError('빈 응답'));
    }
    return {for (final item in list.items) CalendarDate.parse(item.date)};
  }
}
