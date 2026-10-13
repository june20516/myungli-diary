// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ad_free.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$AdFreeCWProxy {
  AdFree active(bool active);

  AdFree expiresAt(DateTime? expiresAt);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `AdFree(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// AdFree(...).copyWith(id: 12, name: "My name")
  /// ```
  AdFree call({bool active, DateTime? expiresAt});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfAdFree.copyWith(...)` or call `instanceOfAdFree.copyWith.fieldName(value)` for a single field.
class _$AdFreeCWProxyImpl implements _$AdFreeCWProxy {
  const _$AdFreeCWProxyImpl(this._value);

  final AdFree _value;

  @override
  AdFree active(bool active) => call(active: active);

  @override
  AdFree expiresAt(DateTime? expiresAt) => call(expiresAt: expiresAt);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `AdFree(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// AdFree(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  AdFree call({
    Object? active = const $CopyWithPlaceholder(),
    Object? expiresAt = const $CopyWithPlaceholder(),
  }) {
    return AdFree(
      active: active == const $CopyWithPlaceholder() || active == null
          ? _value.active
          // ignore: cast_nullable_to_non_nullable
          : active as bool,
      expiresAt: expiresAt == const $CopyWithPlaceholder()
          ? _value.expiresAt
          // ignore: cast_nullable_to_non_nullable
          : expiresAt as DateTime?,
    );
  }
}

extension $AdFreeCopyWith on AdFree {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfAdFree.copyWith(...)` or `instanceOfAdFree.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$AdFreeCWProxy get copyWith => _$AdFreeCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AdFree _$AdFreeFromJson(Map<String, dynamic> json) =>
    $checkedCreate('AdFree', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['active']);
      final val = AdFree(
        active: $checkedConvert('active', (v) => v as bool),
        expiresAt: $checkedConvert(
          'expiresAt',
          (v) => v == null ? null : DateTime.parse(v as String),
        ),
      );
      return val;
    });

Map<String, dynamic> _$AdFreeToJson(AdFree instance) => <String, dynamic>{
  'active': instance.active,
  'expiresAt': ?instance.expiresAt?.toIso8601String(),
};
