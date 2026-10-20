import 'package:dio/dio.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/gen/api/default_api.dart';
import 'package:myungli_diary/core/api/gen/model/diary.dart';
import 'package:myungli_diary/core/api/gen/model/diary_input.dart';
import 'package:myungli_diary/core/api/gen/model/diary_list.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';

const _notFound = 404;

/// 한 번에 받는 일기 목록 수. 달력 격자(42일)를 한 번에 덮습니다(A33).
const _datesPageLimit = 100;

/// 일기 목록 한 쪽의 기본 수(A45).
const int diaryPageLimit = 30;

/// 일기 저장소(`listDiaries`·`getDiary`·`putDiary`·`deleteDiary`).
///
/// 실패는 [appErrorFrom]이 분류한 [AppError]입니다([existsOn] 설명). 일기는 기기에 저장하지
/// 않습니다(A45). 초안은 `DiaryDraftStore`가 따로 둡니다.
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

  /// 일기 목록 한 쪽(날짜 내림차순). [cursor]는 앞 쪽의 `nextCursor`이고, [tag]가 있으면 그
  /// 태그가 붙은 일기만입니다.
  Future<DiaryList> page({
    CalendarDate? from,
    CalendarDate? to,
    String? tag,
    String? cursor,
    int limit = diaryPageLimit,
  }) async {
    final DiaryList? list;
    try {
      list = (await _api.listDiaries(
        from: from?.toIso(),
        to: to?.toIso(),
        tag: tag,
        cursor: cursor,
        limit: limit,
      )).data;
    } on DioException catch (e) {
      throw appErrorFrom(e);
    }
    if (list == null) {
      throw UnexpectedError(StateError('빈 응답'));
    }
    return list;
  }

  /// [date]의 일기. 404면 null입니다.
  Future<Diary?> find(CalendarDate date) async {
    try {
      return (await _api.getDiary(date: date.toIso())).data;
    } on DioException catch (e) {
      if (e.response?.statusCode == _notFound) {
        return null;
      }
      throw appErrorFrom(e);
    }
  }

  /// [date]에 [body]를 쓰거나 고칩니다(하루 1편, 멱등 upsert). 저장된 일기를 돌려줍니다.
  ///
  /// 오늘 이후 날짜는 422 `diary.future_date`의 [ProblemError]입니다.
  Future<Diary> put(CalendarDate date, String body) async {
    final Diary? diary;
    try {
      diary = (await _api.putDiary(
        date: date.toIso(),
        diaryInput: DiaryInput(body: body),
      )).data;
    } on DioException catch (e) {
      throw appErrorFrom(e);
    }
    if (diary == null) {
      throw UnexpectedError(StateError('빈 응답'));
    }
    return diary;
  }

  /// [date]의 일기를 지웁니다. 이미 없으면 404 `diary.not_found`의 [ProblemError]입니다.
  Future<void> delete(CalendarDate date) async {
    try {
      await _api.deleteDiary(date: date.toIso());
    } on DioException catch (e) {
      throw appErrorFrom(e);
    }
  }
}
