import 'package:dio/dio.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/gen/api/default_api.dart';
import 'package:myungli_diary/core/api/gen/model/purchase.dart';

/// 구매 내역 조회와 구매 장부 맞추기.
///
/// 구매 장부와 권한 계산은 server만 합니다(D60). 캐시하지 않고 매번 묻습니다.
final class PurchaseRepository {
  /// [_api]로 묻습니다.
  const new(this._api);

  final DefaultApi _api;

  /// 구매 내역. 최근 구매 먼저인 server 순서 그대로입니다. 실패는 [AppError]로 던집니다.
  Future<List<Purchase>> list() async {
    try {
      final data = (await _api.listPurchases()).data;
      if (data == null) {
        throw UnexpectedError(StateError('빈 응답'));
      }
      return data.items;
    } on DioException catch (e) {
      throw appErrorFrom(e);
    }
  }

  /// server가 RevenueCat 구매 목록으로 장부와 광고 제거권을 다시 맞추게 합니다.
  ///
  /// 실패는 [AppError]로 던집니다. RevenueCat 장애는 `billing.provider_unavailable`입니다.
  Future<void> reconcile() async {
    try {
      final data = (await _api.restorePurchases()).data;
      if (data == null) {
        throw UnexpectedError(StateError('빈 응답'));
      }
    } on DioException catch (e) {
      throw appErrorFrom(e);
    }
  }
}
