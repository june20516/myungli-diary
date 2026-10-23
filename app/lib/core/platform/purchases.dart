import 'package:myungli_diary/core/api/app_error.dart';

/// 스토어 상품.
final class StoreProduct {
  /// 상품 id와 스토어가 현지화한 이름·가격을 담습니다.
  const new({required this.id, required this.title, required this.priceLabel});

  /// 스토어 상품 id.
  final String id;

  /// 스토어가 현지화한 상품 이름. 구매 내역에서 app이 이름을 모르는 상품에 씁니다(D88).
  final String title;

  /// 스토어가 현지화한 가격 문자열.
  final String priceLabel;
}

/// 구매 결과.
sealed class PurchaseOutcome {
  /// 하위 타입이 상속하는 기본 생성자입니다.
  const new();
}

/// 구매 성공.
final class PurchaseSucceeded extends PurchaseOutcome {
  /// 성공.
  const new();
}

/// 사용자가 구매를 취소했습니다.
final class PurchaseCancelled extends PurchaseOutcome {
  /// 취소.
  const new();
}

/// 구매 실패.
final class PurchaseFailed extends PurchaseOutcome {
  /// 실패 원인을 담습니다.
  const new(this.error);

  /// 실패 원인.
  final AppError error;
}

/// 인앱결제(RevenueCat).
abstract interface class Purchases {
  /// 구매 계정을 [accountId]로 연결합니다. 실패하면 `AppError`를 던집니다.
  Future<void> logIn(String accountId);

  /// 로그아웃할 때 구매 계정 연결을 끊습니다.
  Future<void> logOut();

  /// 스토어 구매 내역을 RevenueCat에 다시 맞춥니다. 실패하면 `AppError`를 던집니다.
  Future<void> sync();

  /// 살 수 있는 상품.
  Future<List<StoreProduct>> products();

  /// [productId]를 삽니다.
  Future<PurchaseOutcome> buy(String productId);
}
