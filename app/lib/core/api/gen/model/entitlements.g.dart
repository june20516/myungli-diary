// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'entitlements.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$EntitlementsCWProxy {
  Entitlements adFree(AdFree adFree);

  Entitlements insight(Insight insight);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `Entitlements(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// Entitlements(...).copyWith(id: 12, name: "My name")
  /// ```
  Entitlements call({AdFree adFree, Insight insight});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfEntitlements.copyWith(...)` or call `instanceOfEntitlements.copyWith.fieldName(value)` for a single field.
class _$EntitlementsCWProxyImpl implements _$EntitlementsCWProxy {
  const _$EntitlementsCWProxyImpl(this._value);

  final Entitlements _value;

  @override
  Entitlements adFree(AdFree adFree) => call(adFree: adFree);

  @override
  Entitlements insight(Insight insight) => call(insight: insight);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `Entitlements(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// Entitlements(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  Entitlements call({
    Object? adFree = const $CopyWithPlaceholder(),
    Object? insight = const $CopyWithPlaceholder(),
  }) {
    return Entitlements(
      adFree: adFree == const $CopyWithPlaceholder() || adFree == null
          ? _value.adFree
          // ignore: cast_nullable_to_non_nullable
          : adFree as AdFree,
      insight: insight == const $CopyWithPlaceholder() || insight == null
          ? _value.insight
          // ignore: cast_nullable_to_non_nullable
          : insight as Insight,
    );
  }
}

extension $EntitlementsCopyWith on Entitlements {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfEntitlements.copyWith(...)` or `instanceOfEntitlements.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$EntitlementsCWProxy get copyWith => _$EntitlementsCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Entitlements _$EntitlementsFromJson(Map<String, dynamic> json) =>
    $checkedCreate('Entitlements', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['adFree', 'insight']);
      final val = Entitlements(
        adFree: $checkedConvert(
          'adFree',
          (v) => AdFree.fromJson(v as Map<String, dynamic>),
        ),
        insight: $checkedConvert(
          'insight',
          (v) => Insight.fromJson(v as Map<String, dynamic>),
        ),
      );
      return val;
    });

Map<String, dynamic> _$EntitlementsToJson(Entitlements instance) =>
    <String, dynamic>{
      'adFree': instance.adFree.toJson(),
      'insight': instance.insight.toJson(),
    };
