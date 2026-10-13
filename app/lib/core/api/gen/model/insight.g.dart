// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'insight.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$InsightCWProxy {
  Insight active(bool active);

  Insight expiresAt(DateTime? expiresAt);

  Insight source_(InsightSource_Enum? source_);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `Insight(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// Insight(...).copyWith(id: 12, name: "My name")
  /// ```
  Insight call({bool active, DateTime? expiresAt, InsightSource_Enum? source_});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfInsight.copyWith(...)` or call `instanceOfInsight.copyWith.fieldName(value)` for a single field.
class _$InsightCWProxyImpl implements _$InsightCWProxy {
  const _$InsightCWProxyImpl(this._value);

  final Insight _value;

  @override
  Insight active(bool active) => call(active: active);

  @override
  Insight expiresAt(DateTime? expiresAt) => call(expiresAt: expiresAt);

  @override
  Insight source_(InsightSource_Enum? source_) => call(source_: source_);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `Insight(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// Insight(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  Insight call({
    Object? active = const $CopyWithPlaceholder(),
    Object? expiresAt = const $CopyWithPlaceholder(),
    Object? source_ = const $CopyWithPlaceholder(),
  }) {
    return Insight(
      active: active == const $CopyWithPlaceholder() || active == null
          ? _value.active
          // ignore: cast_nullable_to_non_nullable
          : active as bool,
      expiresAt: expiresAt == const $CopyWithPlaceholder()
          ? _value.expiresAt
          // ignore: cast_nullable_to_non_nullable
          : expiresAt as DateTime?,
      source_: source_ == const $CopyWithPlaceholder()
          ? _value.source_
          // ignore: cast_nullable_to_non_nullable
          : source_ as InsightSource_Enum?,
    );
  }
}

extension $InsightCopyWith on Insight {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfInsight.copyWith(...)` or `instanceOfInsight.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$InsightCWProxy get copyWith => _$InsightCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Insight _$InsightFromJson(Map<String, dynamic> json) =>
    $checkedCreate('Insight', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['active']);
      final val = Insight(
        active: $checkedConvert('active', (v) => v as bool),
        expiresAt: $checkedConvert(
          'expiresAt',
          (v) => v == null ? null : DateTime.parse(v as String),
        ),
        source_: $checkedConvert(
          'source',
          (v) => $enumDecodeNullable(_$InsightSource_EnumEnumMap, v),
        ),
      );
      return val;
    }, fieldKeyMap: const {'source_': 'source'});

Map<String, dynamic> _$InsightToJson(Insight instance) => <String, dynamic>{
  'active': instance.active,
  'expiresAt': ?instance.expiresAt?.toIso8601String(),
  'source': ?_$InsightSource_EnumEnumMap[instance.source_],
};

const _$InsightSource_EnumEnumMap = {
  InsightSource_Enum.rewardedAd: 'rewarded_ad',
  InsightSource_Enum.adFreePass: 'ad_free_pass',
  InsightSource_Enum.subscription: 'subscription',
};
