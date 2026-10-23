// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'purchase_list.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$PurchaseListCWProxy {
  PurchaseList items(List<Purchase> items);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `PurchaseList(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// PurchaseList(...).copyWith(id: 12, name: "My name")
  /// ```
  PurchaseList call({List<Purchase> items});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfPurchaseList.copyWith(...)` or call `instanceOfPurchaseList.copyWith.fieldName(value)` for a single field.
class _$PurchaseListCWProxyImpl implements _$PurchaseListCWProxy {
  const _$PurchaseListCWProxyImpl(this._value);

  final PurchaseList _value;

  @override
  PurchaseList items(List<Purchase> items) => call(items: items);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `PurchaseList(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// PurchaseList(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  PurchaseList call({Object? items = const $CopyWithPlaceholder()}) {
    return PurchaseList(
      items: items == const $CopyWithPlaceholder() || items == null
          ? _value.items
          // ignore: cast_nullable_to_non_nullable
          : items as List<Purchase>,
    );
  }
}

extension $PurchaseListCopyWith on PurchaseList {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfPurchaseList.copyWith(...)` or `instanceOfPurchaseList.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$PurchaseListCWProxy get copyWith => _$PurchaseListCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PurchaseList _$PurchaseListFromJson(Map<String, dynamic> json) =>
    $checkedCreate('PurchaseList', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['items']);
      final val = PurchaseList(
        items: $checkedConvert(
          'items',
          (v) => (v as List<dynamic>)
              .map((e) => Purchase.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
      );
      return val;
    });

Map<String, dynamic> _$PurchaseListToJson(PurchaseList instance) =>
    <String, dynamic>{'items': instance.items.map((e) => e.toJson()).toList()};
