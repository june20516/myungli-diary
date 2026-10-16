import 'package:dio/dio.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/gen/api/default_api.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';

const _notFound = 404;

/// 일기 저장소. 계획 3에서는 그날 일기가 있는지만 묻습니다(일기 화면은 계획 5).
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
}
