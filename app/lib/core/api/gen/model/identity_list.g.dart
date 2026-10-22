// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'identity_list.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$IdentityListCWProxy {
  IdentityList items(List<Identity> items);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `IdentityList(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// IdentityList(...).copyWith(id: 12, name: "My name")
  /// ```
  IdentityList call({List<Identity> items});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfIdentityList.copyWith(...)` or call `instanceOfIdentityList.copyWith.fieldName(value)` for a single field.
class _$IdentityListCWProxyImpl implements _$IdentityListCWProxy {
  const _$IdentityListCWProxyImpl(this._value);

  final IdentityList _value;

  @override
  IdentityList items(List<Identity> items) => call(items: items);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `IdentityList(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// IdentityList(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  IdentityList call({Object? items = const $CopyWithPlaceholder()}) {
    return IdentityList(
      items: items == const $CopyWithPlaceholder() || items == null
          ? _value.items
          // ignore: cast_nullable_to_non_nullable
          : items as List<Identity>,
    );
  }
}

extension $IdentityListCopyWith on IdentityList {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfIdentityList.copyWith(...)` or `instanceOfIdentityList.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$IdentityListCWProxy get copyWith => _$IdentityListCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

IdentityList _$IdentityListFromJson(Map<String, dynamic> json) =>
    $checkedCreate('IdentityList', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['items']);
      final val = IdentityList(
        items: $checkedConvert(
          'items',
          (v) => (v as List<dynamic>)
              .map((e) => Identity.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
      );
      return val;
    });

Map<String, dynamic> _$IdentityListToJson(IdentityList instance) =>
    <String, dynamic>{'items': instance.items.map((e) => e.toJson()).toList()};
