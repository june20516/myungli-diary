// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'purchase.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$PurchaseCWProxy {
  Purchase productId(String productId);

  Purchase purchasedAt(DateTime purchasedAt);

  Purchase status(PurchaseStatus status);

  Purchase period(PurchasePeriod? period);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `Purchase(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// Purchase(...).copyWith(id: 12, name: "My name")
  /// ```
  Purchase call({
    String productId,
    DateTime purchasedAt,
    PurchaseStatus status,
    PurchasePeriod? period,
  });
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfPurchase.copyWith(...)` or call `instanceOfPurchase.copyWith.fieldName(value)` for a single field.
class _$PurchaseCWProxyImpl implements _$PurchaseCWProxy {
  const _$PurchaseCWProxyImpl(this._value);

  final Purchase _value;

  @override
  Purchase productId(String productId) => call(productId: productId);

  @override
  Purchase purchasedAt(DateTime purchasedAt) => call(purchasedAt: purchasedAt);

  @override
  Purchase status(PurchaseStatus status) => call(status: status);

  @override
  Purchase period(PurchasePeriod? period) => call(period: period);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `Purchase(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// Purchase(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  Purchase call({
    Object? productId = const $CopyWithPlaceholder(),
    Object? purchasedAt = const $CopyWithPlaceholder(),
    Object? status = const $CopyWithPlaceholder(),
    Object? period = const $CopyWithPlaceholder(),
  }) {
    return Purchase(
      productId: productId == const $CopyWithPlaceholder() || productId == null
          ? _value.productId
          // ignore: cast_nullable_to_non_nullable
          : productId as String,
      purchasedAt:
          purchasedAt == const $CopyWithPlaceholder() || purchasedAt == null
          ? _value.purchasedAt
          // ignore: cast_nullable_to_non_nullable
          : purchasedAt as DateTime,
      status: status == const $CopyWithPlaceholder() || status == null
          ? _value.status
          // ignore: cast_nullable_to_non_nullable
          : status as PurchaseStatus,
      period: period == const $CopyWithPlaceholder()
          ? _value.period
          // ignore: cast_nullable_to_non_nullable
          : period as PurchasePeriod?,
    );
  }
}

extension $PurchaseCopyWith on Purchase {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfPurchase.copyWith(...)` or `instanceOfPurchase.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$PurchaseCWProxy get copyWith => _$PurchaseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Purchase _$PurchaseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('Purchase', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['productId', 'purchasedAt', 'status']);
  final val = Purchase(
    productId: $checkedConvert('productId', (v) => v as String),
    purchasedAt: $checkedConvert(
      'purchasedAt',
      (v) => DateTime.parse(v as String),
    ),
    status: $checkedConvert(
      'status',
      (v) => $enumDecode(
        _$PurchaseStatusEnumMap,
        v,
        unknownValue: PurchaseStatus.unknownDefaultOpenApi,
      ),
    ),
    period: $checkedConvert(
      'period',
      (v) =>
          v == null ? null : PurchasePeriod.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$PurchaseToJson(Purchase instance) => <String, dynamic>{
  'productId': instance.productId,
  'purchasedAt': instance.purchasedAt.toIso8601String(),
  'status': _$PurchaseStatusEnumMap[instance.status]!,
  'period': ?instance.period?.toJson(),
};

const _$PurchaseStatusEnumMap = {
  PurchaseStatus.active: 'active',
  PurchaseStatus.pending: 'pending',
  PurchaseStatus.expired: 'expired',
  PurchaseStatus.refunded: 'refunded',
  PurchaseStatus.owned: 'owned',
  PurchaseStatus.unknownDefaultOpenApi: 'unknown_default_open_api',
};
