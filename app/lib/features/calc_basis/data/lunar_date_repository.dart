import 'package:dio/dio.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/gen/api/default_api.dart';
import 'package:myungli_diary/core/api/gen/model/lunar_date_request.dart';
import 'package:myungli_diary/core/api/gen/model/lunar_or_solar_date.dart';

/// 응답 `solarDate`의 `YYYY-MM-DD` 형식입니다.
final RegExp _solarDatePattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

/// 음력 → 양력 변환(`convertLunarDate`, KASI 기준 D41). 로그인 없이 부릅니다.
final class LunarDateRepository {
  /// `api`로 요청하고, 설치 id는 `installationId`로 읽습니다.
  const new(this._api, this._installationId);

  final DefaultApi _api;
  final Future<String> Function() _installationId;

  /// 음력 [date](윤달이면 [isLeapMonth])의 양력 날짜입니다. 연·월·일만 담습니다.
  ///
  /// 실패(없는 음력 날짜 422 포함)는 [AppError]입니다.
  Future<DateTime> toSolar(
    LunarOrSolarDate date, {
    required bool isLeapMonth,
  }) async {
    final request = LunarDateRequest(
      installationId: await _installationId(),
      date: date,
      isLeapMonth: isLeapMonth,
    );
    try {
      final response = await _api.convertLunarDate(lunarDateRequest: request);
      final data = response.data;
      if (data == null) {
        throw UnexpectedError(StateError('빈 응답'));
      }
      return _parseSolarDate(data.solarDate);
    } on DioException catch (e) {
      throw appErrorFrom(e);
    }
  }
}

DateTime _parseSolarDate(String value) {
  final match = _solarDatePattern.firstMatch(value);
  if (match == null) {
    throw UnexpectedError(FormatException('양력 날짜 형식이 아닙니다', value));
  }
  return DateTime(
    int.parse(match[1]!),
    int.parse(match[2]!),
    int.parse(match[3]!),
  );
}
