import 'package:dio/dio.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/gen/api/default_api.dart';
import 'package:myungli_diary/core/api/gen/model/entitlements.dart';

/// 이용권 상태(광고 제거권·근거 열람 권한) 조회.
///
/// 권한은 server만 부여합니다(D60). 보상형 광고 뒤 확인(근거 시트), 광고 제거권 구매 뒤 확인
/// (계획 7)이 같은 조회를 씁니다. 캐시하지 않고 매번 묻습니다.
final class EntitlementsRepository {
  /// [_api]로 묻습니다.
  const new(this._api);

  final DefaultApi _api;

  /// 지금의 이용권 상태. 실패는 [AppError]로 던집니다.
  Future<Entitlements> fetch() async {
    final Entitlements? data;
    try {
      data = (await _api.getEntitlements()).data;
    } on DioException catch (e) {
      throw appErrorFrom(e);
    }
    if (data == null) {
      throw UnexpectedError(StateError('빈 응답'));
    }
    return data;
  }
}
