import 'package:dio/dio.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/gen/api/default_api.dart';
import 'package:myungli_diary/core/api/gen/model/preview.dart';
import 'package:myungli_diary/core/api/gen/model/preview_request.dart';
import 'package:myungli_diary/features/onboarding/data/onboarding_draft.dart';

/// 비로그인 첫 풀이 미리보기(`createPreview`, D50). 설치당 한 번만 받을 수 있습니다.
final class PreviewRepository {
  /// `api`로 요청하고, 설치 id와 기기 시간대 이름은 각 함수로 읽습니다.
  const new(this._api, this._installationId, this._deviceTimezone);

  final DefaultApi _api;
  final Future<String> Function() _installationId;
  final Future<String> Function() _deviceTimezone;

  /// [draft]의 입력으로 오늘 풀이 일부를 받습니다.
  ///
  /// [deviceRegionIsKorea]는 출생지·출생 시간대를 정하는 기준입니다(D29).
  /// 입력이 모자라면 [StateError]이고, 서버 실패는 [AppError]입니다(예: 403
  /// `preview.used`, 422 `birth.invalid`).
  Future<Preview> create({
    required OnboardingDraft draft,
    required bool deviceRegionIsKorea,
  }) async {
    final request = PreviewRequest(
      installationId: await _installationId(),
      currentTimezone: await _deviceTimezone(),
      birth: draft.toBirth(deviceRegionIsKorea: deviceRegionIsKorea),
    );
    try {
      final response = await _api.createPreview(previewRequest: request);
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
