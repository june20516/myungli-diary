import 'package:dio/dio.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/gen/api/default_api.dart';
import 'package:myungli_diary/core/api/gen/model/diary_stats.dart';

/// 일기 회고 집계(`getDiaryStats`, S146). 캐시 없이 매번 server에서 받습니다(A119).
final class DiaryStatsRepository {
  /// `api`로 받습니다.
  const new(this._api);

  final DefaultApi _api;

  /// 집계를 받습니다. 실패는 [AppError]입니다.
  Future<DiaryStats> fetch() async {
    final DiaryStats? data;
    try {
      data = (await _api.getDiaryStats()).data;
    } on DioException catch (e) {
      throw appErrorFrom(e);
    }
    if (data == null) {
      throw UnexpectedError(StateError('빈 응답'));
    }
    return data;
  }
}
