// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'merge_added_days.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$MergeAddedDaysCWProxy {
  MergeAddedDays adFree(int adFree);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `MergeAddedDays(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// MergeAddedDays(...).copyWith(id: 12, name: "My name")
  /// ```
  MergeAddedDays call({int adFree});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfMergeAddedDays.copyWith(...)` or call `instanceOfMergeAddedDays.copyWith.fieldName(value)` for a single field.
class _$MergeAddedDaysCWProxyImpl implements _$MergeAddedDaysCWProxy {
  const _$MergeAddedDaysCWProxyImpl(this._value);

  final MergeAddedDays _value;

  @override
  MergeAddedDays adFree(int adFree) => call(adFree: adFree);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `MergeAddedDays(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// MergeAddedDays(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  MergeAddedDays call({Object? adFree = const $CopyWithPlaceholder()}) {
    return MergeAddedDays(
      adFree: adFree == const $CopyWithPlaceholder() || adFree == null
          ? _value.adFree
          // ignore: cast_nullable_to_non_nullable
          : adFree as int,
    );
  }
}

extension $MergeAddedDaysCopyWith on MergeAddedDays {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfMergeAddedDays.copyWith(...)` or `instanceOfMergeAddedDays.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$MergeAddedDaysCWProxy get copyWith => _$MergeAddedDaysCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MergeAddedDays _$MergeAddedDaysFromJson(Map<String, dynamic> json) =>
    $checkedCreate('MergeAddedDays', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['adFree']);
      final val = MergeAddedDays(
        adFree: $checkedConvert('adFree', (v) => (v as num).toInt()),
      );
      return val;
    });

Map<String, dynamic> _$MergeAddedDaysToJson(MergeAddedDays instance) =>
    <String, dynamic>{'adFree': instance.adFree};
