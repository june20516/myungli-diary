import 'package:dio/dio.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/gen/api/default_api.dart';
import 'package:myungli_diary/core/api/gen/model/inquiry_input.dart';

/// 문의 server 요청(`createInquiry`, D102).
///
/// server는 문의를 저장하지 않고 운영 메일함으로 보냅니다. 실패는 [appErrorFrom]이 분류한
/// [AppError]입니다(429 `rate_limited`, 503 `service.unavailable` 등).
final class InquiryRepository {
  /// [_api]로 요청합니다.
  const new(this._api);

  final DefaultApi _api;

  /// [input]을 보냅니다. [idempotencyKey]는 같은 문의를 다시 보낼 때 같은 값을 넘깁니다(24시간
  /// 안의 같은 키에는 server가 처음 응답을 돌려주고 메일을 다시 보내지 않음).
  Future<void> send(
    InquiryInput input, {
    required String idempotencyKey,
  }) async {
    try {
      await _api.createInquiry(
        inquiryInput: input,
        idempotencyKey: idempotencyKey,
      );
    } on DioException catch (e) {
      throw appErrorFrom(e);
    }
  }
}
