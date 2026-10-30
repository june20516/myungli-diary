import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/platform/purchases.dart';
import 'package:purchases_flutter/purchases_flutter.dart' as rc;

// RevenueCat 공개 SDK 키(#632, 앱 바이너리에 들어가는 공개 값). 결정 D99 ②, A98.

/// Test Store 키. debug 빌드에서만 값이 있습니다. release 빌드는 상수 접힘으로 문자열이
/// 바이너리에 남지 않습니다(SDK가 release에서 Test Store 키를 보면 앱을 종료함).
const String revenueCatTestStoreKey = kDebugMode
    ? 'test_VAjkMbgwXttpDENLTNVHVgHblHP'
    : '';

const _playStoreKey = 'goog_QusGlSiIzlZVNWQwzqjGwGZEEhQ';
const _appStoreKey = 'appl_xtRYyUOVcHmfCoEPftNtNVIZFAp';

/// [platform]에서 쓸 SDK 키. Test Store 키([testStoreKey])가 있으면(debug) 그것이고,
/// 없으면(release) Android Play, iOS App Store 키입니다. 그 밖의 플랫폼은 null입니다.
String? revenueCatApiKey({
  required TargetPlatform platform,
  String testStoreKey = revenueCatTestStoreKey,
}) {
  if (testStoreKey.isNotEmpty) return testStoreKey;
  return switch (platform) {
    TargetPlatform.android => _playStoreKey,
    TargetPlatform.iOS => _appStoreKey,
    _ => null,
  };
}

/// RevenueCat SDK 실패의 종류.
enum RevenueCatFailureKind {
  /// 사용자가 구매를 취소했습니다.
  cancelled,

  /// 네트워크에 연결할 수 없습니다.
  offline,

  /// 그 밖의 실패.
  other,
}

/// SDK 경계가 던지는 실패. SDK 오류 코드를 [kind]로 옮깁니다.
final class RevenueCatFailure implements Exception {
  /// 실패를 담습니다.
  const new(this.kind, this.cause);

  /// 실패 종류.
  final RevenueCatFailureKind kind;

  /// 원인(대개 SDK의 [PlatformException]).
  final Object cause;
}

/// RevenueCat SDK 경계. SDK 호출을 옮기고 실패를 [RevenueCatFailure]로 바꾸기만 하며,
/// 분기는 [RevenueCatPurchases]에 둡니다.
abstract interface class RevenueCatApi {
  /// [apiKey]로 SDK를 설정합니다. 처음에는 익명 사용자입니다.
  Future<void> configure(String apiKey);

  /// 앱 사용자 id를 [appUserId]로 바꿉니다.
  Future<void> logIn(String appUserId);

  /// 지금 익명 사용자인지.
  Future<bool> isAnonymous();

  /// 익명 사용자로 돌아갑니다. 이미 익명이면 SDK가 던집니다.
  Future<void> logOut();

  /// 스토어 구매 내역을 RevenueCat에 맞춥니다.
  Future<void> syncPurchases();

  /// [ids]의 스토어 상품(광고 제거권은 소모성이라 비구독 상품).
  Future<List<StoreProduct>> getProducts(List<String> ids);

  /// [productId]를 삽니다.
  Future<void> purchase(String productId);
}

/// 실제 RevenueCat SDK를 부르는 경계(기본값).
final class SdkRevenueCatApi implements RevenueCatApi {
  /// 경계를 만듭니다.
  const new();

  @override
  Future<void> configure(String apiKey) =>
      _call(() => rc.Purchases.configure(rc.PurchasesConfiguration(apiKey)));

  @override
  Future<void> logIn(String appUserId) =>
      _call(() => rc.Purchases.logIn(appUserId));

  @override
  Future<bool> isAnonymous() => _call(() => rc.Purchases.isAnonymous);

  @override
  Future<void> logOut() => _call(rc.Purchases.logOut);

  @override
  Future<void> syncPurchases() => _call(rc.Purchases.syncPurchasesForResult);

  @override
  Future<List<StoreProduct>> getProducts(List<String> ids) async {
    final products = await _call(() => _storeProducts(ids));
    return [
      for (final product in products)
        StoreProduct(
          id: product.identifier,
          title: product.title,
          priceLabel: product.priceString,
        ),
    ];
  }

  @override
  Future<void> purchase(String productId) => _call(() async {
    final products = await _storeProducts([productId]);
    if (products.isEmpty) {
      throw RevenueCatFailure(
        RevenueCatFailureKind.other,
        StateError('상품 $productId가 스토어에 없음'),
      );
    }
    await rc.Purchases.purchase(rc.PurchaseParams.storeProduct(products.first));
  });

  static Future<List<rc.StoreProduct>> _storeProducts(List<String> ids) =>
      rc.Purchases.getProducts(
        ids,
        productCategory: rc.ProductCategory.nonSubscription,
      );

  static Future<T> _call<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on PlatformException catch (error) {
      throw RevenueCatFailure(_kindOf(error), error);
    }
  }

  static RevenueCatFailureKind _kindOf(PlatformException error) =>
      switch (rc.PurchasesErrorHelper.getErrorCode(error)) {
        rc.PurchasesErrorCode.purchaseCancelledError =>
          RevenueCatFailureKind.cancelled,
        rc.PurchasesErrorCode.networkError ||
        rc.PurchasesErrorCode.offlineConnectionError =>
          RevenueCatFailureKind.offline,
        _ => RevenueCatFailureKind.other,
      };
}

/// 인앱결제의 실제 구현(RevenueCat, #684).
///
/// SDK는 처음 부를 때 [apiKey]로 한 번 설정하고, 설정이 실패하면 다음 호출에서 다시
/// 설정합니다. 앱 사용자 id는 server 계정 id입니다(`AccountLinker`, server S79). 상품은
/// 빌드 설정의 광고 제거권 id([productIds])로 조회합니다. [apiKey]가 null인 플랫폼은 SDK를
/// 부르지 않고 결제를 쓸 수 없는 상태로 둡니다. 상품 조회와 동기화는 [timeout]을 넘으면
/// [TimeoutError]입니다(화면이 오류 상태로 다시 시도를 줌). 구매는 사용자가 스토어 창을
/// 보는 동안이라 시간 한계를 두지 않습니다.
final class RevenueCatPurchases implements Purchases {
  /// adapter를 만듭니다.
  new({
    required this.apiKey,
    required this.productIds,
    this.api = const SdkRevenueCatApi(),
    this.timeout = const Duration(seconds: 15),
  });

  /// SDK 키([revenueCatApiKey]).
  final String? apiKey;

  /// 광고 제거권 상품 id.
  final Set<String> productIds;

  /// SDK 경계.
  final RevenueCatApi api;

  /// 상품 조회와 동기화의 시간 한계.
  final Duration timeout;

  Future<void>? _configured;

  @override
  Future<void> logIn(String accountId) =>
      _run(() => api.logIn(accountId), orElse: null);

  @override
  Future<void> logOut() => _run(() async {
    if (!await api.isAnonymous()) await api.logOut();
  }, orElse: null);

  @override
  Future<void> sync() => _limited(_run(api.syncPurchases, orElse: null));

  @override
  Future<List<StoreProduct>> products() {
    if (productIds.isEmpty) return Future.value(const []);
    return _limited(
      _run(
        () => api.getProducts(productIds.toList()),
        orElse: const <StoreProduct>[],
      ),
    );
  }

  @override
  Future<PurchaseOutcome> buy(String productId) async {
    if (apiKey == null) {
      return PurchaseFailed(UnexpectedError(StateError('결제를 쓸 수 없는 플랫폼')));
    }
    try {
      await _run(() => api.purchase(productId), orElse: null);
      return const PurchaseSucceeded();
    } on _Cancelled {
      return const PurchaseCancelled();
    } on AppError catch (error) {
      return PurchaseFailed(error);
    }
  }

  Future<T> _limited<T>(Future<T> call) =>
      call.timeout(timeout, onTimeout: () => throw const TimeoutError());

  /// SDK를 설정한 뒤 [body]를 부르고, SDK 실패를 [AppError]로 바꿉니다(취소는
  /// [_Cancelled]). 키가 없으면 [orElse]입니다.
  Future<T> _run<T>(Future<T> Function() body, {required T orElse}) async {
    final key = apiKey;
    if (key == null) return orElse;
    try {
      try {
        await (_configured ??= api.configure(key));
      } on Object {
        _configured = null;
        rethrow;
      }
      return await body();
    } on RevenueCatFailure catch (failure) {
      throw switch (failure.kind) {
        RevenueCatFailureKind.cancelled => const _Cancelled(),
        RevenueCatFailureKind.offline => const OfflineError(),
        RevenueCatFailureKind.other => UnexpectedError(failure.cause),
      };
    }
  }
}

/// 구매 취소. [RevenueCatPurchases.buy]만 받아 [PurchaseCancelled]로 바꿉니다. 그 밖의
/// 호출에서는 취소가 나오지 않습니다.
final class _Cancelled implements Exception {
  const new();
}
