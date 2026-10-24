import 'package:dio/dio.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/gen/api/default_api.dart';
import 'package:myungli_diary/core/api/gen/model/diary.dart';
import 'package:myungli_diary/core/api/gen/model/diary_body_input.dart';
import 'package:myungli_diary/core/api/gen/model/diary_input.dart';
import 'package:myungli_diary/core/api/gen/model/diary_list.dart';
import 'package:myungli_diary/core/api/gen/model/diary_summary.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:myungli_diary/features/diary/model/diary_limits.dart';

const _notFound = 404;

/// 한 번에 받는 일기 목록 수의 최대(계약 `limit` 상한).
const _maxPageLimit = 100;

/// 일기 목록 한 쪽의 기본 수(A45).
const int diaryPageLimit = 30;

/// 달력 격자 하나(42일)의 일기 날짜를 받는 쪽 수의 상한(spec §7). 42일 × `diaryDayLimit`편
/// 을 `limit` 100으로 나눈 올림이 5입니다.
const _maxDatePages = 5;

/// 일기 저장소(`listDiaries`·`createDiary`·`getDiary`·`updateDiary`·`deleteDiary`).
///
/// 실패는 [appErrorFrom]이 분류한 [AppError]입니다([find] 설명). 일기는 기기에 저장하지
/// 않습니다(A45). 초안은 `DiaryDraftStore`가 따로 둡니다.
final class DiaryRepository {
  /// `api`로 묻습니다.
  const new(this._api);

  final DefaultApi _api;

  /// [date]에 [body]로 새 일기를 씁니다(하루 여러 편). 쓴 일기를 돌려줍니다.
  ///
  /// [idempotencyKey]가 같으면 server가 24시간 동안 같은 일기를 돌려주므로, 실패 뒤 다시
  /// 저장할 때는 같은 키를 씁니다. 그날 일기가 이미 [diaryDayLimit]편이면 422
  /// `diary.day_full`, 오늘 이후 날짜는 422 `diary.future_date`의 [ProblemError]입니다.
  Future<Diary> create(
    CalendarDate date,
    String body, {
    required String idempotencyKey,
  }) async {
    final Diary? diary;
    try {
      diary = (await _api.createDiary(
        diaryInput: DiaryInput(date: date.toIso(), body: body),
        idempotencyKey: idempotencyKey,
      )).data;
    } on DioException catch (e) {
      throw appErrorFrom(e);
    }
    return _required<Diary>(diary);
  }

  /// [id] 일기의 본문을 [body]로 바꿉니다(전체 교체, 멱등). 고친 일기를 돌려줍니다.
  ///
  /// 없거나 지운 일기는 404 `diary.not_found`의 [ProblemError]입니다.
  Future<Diary> update(String id, String body) async {
    final Diary? diary;
    try {
      diary = (await _api.updateDiary(
        id: id,
        diaryBodyInput: DiaryBodyInput(body: body),
      )).data;
    } on DioException catch (e) {
      throw appErrorFrom(e);
    }
    return _required<Diary>(diary);
  }

  /// [id] 일기. 404면 null입니다.
  ///
  /// 그 밖의 통신 실패는 [appErrorFrom]이 분류한 [AppError]입니다: 연결 없음은
  /// [OfflineError], 시간 초과는 [TimeoutError], server problem은 [ProblemError],
  /// 응답 본문을 읽지 못한 경우(역직렬화 실패 등 생성 클라이언트가 감싼 오류)는
  /// [UnexpectedError]입니다. Dio 밖에서 난 예외는 바꾸지 않고 그대로 던집니다.
  Future<Diary?> find(String id) async {
    try {
      return (await _api.getDiary(id: id)).data;
    } on DioException catch (e) {
      if (e.response?.statusCode == _notFound) {
        return null;
      }
      throw appErrorFrom(e);
    }
  }

  /// [id] 일기를 지웁니다. 이미 없으면 404 `diary.not_found`의 [ProblemError]입니다.
  Future<void> delete(String id) async {
    try {
      await _api.deleteDiary(id: id);
    } on DioException catch (e) {
      throw appErrorFrom(e);
    }
  }

  /// [date]에 쓴 일기의 요약. server 순서(같은 날은 작성 순) 그대로입니다.
  ///
  /// 하루 상한([diaryDayLimit])이 `limit`보다 작아 보통 한 쪽이지만, `nextCursor`가 있으면
  /// [datesIn]처럼 최대 [_maxDatePages]쪽까지 이어 받습니다. 실패는 [find]와 같은
  /// [AppError]입니다.
  Future<List<DiarySummary>> diariesOn(CalendarDate date) =>
      _allItems(from: date, to: date);

  /// [from]~[to](둘 다 포함)에 쓴 일기의 날짜(A33). 달력 격자(42일)에는 같은 날 여러 편이
  /// 있을 수 있어 `nextCursor`를 이어 받습니다([_allItems]). 상한에 닿으면 받은 날짜까지만
  /// 돌려줍니다. 실패는 [find]와 같은 [AppError]입니다.
  Future<Set<CalendarDate>> datesIn(CalendarDate from, CalendarDate to) async {
    final items = await _allItems(from: from, to: to);
    return {for (final item in items) CalendarDate.parse(item.date)};
  }

  /// [from]~[to]의 일기 요약을 `nextCursor`가 없을 때까지 이어 받되, 최대 [_maxDatePages]쪽이고
  /// 같은 cursor가 다시 오면 멈춥니다.
  Future<List<DiarySummary>> _allItems({
    required CalendarDate from,
    required CalendarDate to,
  }) async {
    final items = <DiarySummary>[];
    String? cursor;
    for (var received = 0; received < _maxDatePages; received++) {
      final list = await page(
        from: from,
        to: to,
        cursor: cursor,
        limit: _maxPageLimit,
      );
      items.addAll(list.items);
      final next = list.nextCursor;
      if (next == null || next == cursor) {
        break;
      }
      cursor = next;
    }
    return items;
  }

  /// 일기 목록 한 쪽(날짜 내림차순, 같은 날은 작성 순). [cursor]는 앞 쪽의 `nextCursor`이고,
  /// [tag]가 있으면 그 태그가 붙은 일기만입니다.
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
    return _required<DiaryList>(list);
  }
}

/// 응답 본문이 비어 있으면 [UnexpectedError]입니다.
T _required<T extends Object>(T? value) =>
    value ?? (throw UnexpectedError(StateError('빈 응답')));
