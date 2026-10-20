import 'package:dio/dio.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/gen/api/default_api.dart';
import 'package:myungli_diary/core/api/gen/model/birth_hour.dart';
import 'package:myungli_diary/core/api/gen/model/birth_hour_request.dart';
import 'package:myungli_diary/core/api/gen/model/calendar_type.dart';
import 'package:myungli_diary/core/api/gen/model/lunar_or_solar_date.dart';
import 'package:myungli_diary/design/components/input/date_picker.dart';

/// 비로그인 시진 확인(`getBirthHour`, D58). 입력은 server에 저장되지 않습니다.
final class BirthHourRepository {
  /// `api`로 요청하고, 설치 id는 `installationId`로 읽습니다.
  const new(this._api, this._installationId);

  final DefaultApi _api;
  final Future<String> Function() _installationId;

  /// [date] 생일의 [time](`HH:MM`)이 속한 시진과 그 벽시계 범위를 받습니다.
  ///
  /// 실패는 [AppError]입니다.
  Future<BirthHour> fetch({
    required BirthDateValue date,
    required String time,
  }) async {
    final lunar = date.calendar == BirthCalendar.lunar;
    final request = BirthHourRequest(
      installationId: await _installationId(),
      calendar: lunar ? CalendarType.lunar : CalendarType.solar,
      date: LunarOrSolarDate(year: date.year, month: date.month, day: date.day),
      isLeapMonth: lunar && date.isLeapMonth,
      time: time,
    );
    try {
      final response = await _api.getBirthHour(birthHourRequest: request);
      final data = response.data;
      if (data == null) {
        throw UnexpectedError(StateError('빈 응답'));
      }
      return data;
    } on DioException catch (e) {
      throw appErrorFrom(e);
    }
  }
}
