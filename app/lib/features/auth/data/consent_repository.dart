import 'package:dio/dio.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/gen/api/default_api.dart';
import 'package:myungli_diary/core/api/gen/model/consent_document.dart';
import 'package:myungli_diary/core/api/gen/model/consent_request.dart';

/// 약관 동의 server 요청입니다(D50).
///
/// 실패는 [AppError]입니다. 동의한 버전이 현재 버전과 다르면 422
/// `consent.version_mismatch`(`errors[].field` `/documents/<i>/version`)입니다.
final class ConsentRepository {
  /// [_api]로 요청합니다.
  const new(this._api);

  final DefaultApi _api;

  /// [documents](문서와 버전, `Me.requiredConsents`)에 동의합니다(`agreeConsents`, 204).
  Future<void> agree(List<ConsentDocument> documents) async {
    try {
      await _api.agreeConsents(
        consentRequest: ConsentRequest(documents: documents),
      );
    } on DioException catch (e) {
      throw appErrorFrom(e);
    }
  }
}
