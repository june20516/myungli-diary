// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'purchase_period.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$PurchasePeriodCWProxy {
  PurchasePeriod startsAt(DateTime startsAt);

  PurchasePeriod endsAt(DateTime endsAt);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `PurchasePeriod(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// PurchasePeriod(...).copyWith(id: 12, name: "My name")
  /// ```
  PurchasePeriod call({DateTime startsAt, DateTime endsAt});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfPurchasePeriod.copyWith(...)` or call `instanceOfPurchasePeriod.copyWith.fieldName(value)` for a single field.
class _$PurchasePeriodCWProxyImpl implements _$PurchasePeriodCWProxy {
  const _$PurchasePeriodCWProxyImpl(this._value);

  final PurchasePeriod _value;

  @override
  PurchasePeriod startsAt(DateTime startsAt) => call(startsAt: startsAt);

  @override
  PurchasePeriod endsAt(DateTime endsAt) => call(endsAt: endsAt);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `PurchasePeriod(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// PurchasePeriod(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  PurchasePeriod call({
    Object? startsAt = const $CopyWithPlaceholder(),
    Object? endsAt = const $CopyWithPlaceholder(),
  }) {
    return PurchasePeriod(
      startsAt: startsAt == const $CopyWithPlaceholder() || startsAt == null
          ? _value.startsAt
          // ignore: cast_nullable_to_non_nullable
          : startsAt as DateTime,
      endsAt: endsAt == const $CopyWithPlaceholder() || endsAt == null
          ? _value.endsAt
          // ignore: cast_nullable_to_non_nullable
          : endsAt as DateTime,
    );
  }
}

extension $PurchasePeriodCopyWith on PurchasePeriod {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfPurchasePeriod.copyWith(...)` or `instanceOfPurchasePeriod.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$PurchasePeriodCWProxy get copyWith => _$PurchasePeriodCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PurchasePeriod _$PurchasePeriodFromJson(Map<String, dynamic> json) =>
    $checkedCreate('PurchasePeriod', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['startsAt', 'endsAt']);
      final val = PurchasePeriod(
        startsAt: $checkedConvert(
          'startsAt',
          (v) => DateTime.parse(v as String),
        ),
        endsAt: $checkedConvert('endsAt', (v) => DateTime.parse(v as String)),
      );
      return val;
    });

Map<String, dynamic> _$PurchasePeriodToJson(PurchasePeriod instance) =>
    <String, dynamic>{
      'startsAt': instance.startsAt.toIso8601String(),
      'endsAt': instance.endsAt.toIso8601String(),
    };
