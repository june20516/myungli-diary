// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'birth_hour.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$BirthHourCWProxy {
  BirthHour branch(Branch branch);

  BirthHour start(String start);

  BirthHour end(String end);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `BirthHour(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// BirthHour(...).copyWith(id: 12, name: "My name")
  /// ```
  BirthHour call({Branch branch, String start, String end});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfBirthHour.copyWith(...)` or call `instanceOfBirthHour.copyWith.fieldName(value)` for a single field.
class _$BirthHourCWProxyImpl implements _$BirthHourCWProxy {
  const _$BirthHourCWProxyImpl(this._value);

  final BirthHour _value;

  @override
  BirthHour branch(Branch branch) => call(branch: branch);

  @override
  BirthHour start(String start) => call(start: start);

  @override
  BirthHour end(String end) => call(end: end);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `BirthHour(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// BirthHour(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  BirthHour call({
    Object? branch = const $CopyWithPlaceholder(),
    Object? start = const $CopyWithPlaceholder(),
    Object? end = const $CopyWithPlaceholder(),
  }) {
    return BirthHour(
      branch: branch == const $CopyWithPlaceholder() || branch == null
          ? _value.branch
          // ignore: cast_nullable_to_non_nullable
          : branch as Branch,
      start: start == const $CopyWithPlaceholder() || start == null
          ? _value.start
          // ignore: cast_nullable_to_non_nullable
          : start as String,
      end: end == const $CopyWithPlaceholder() || end == null
          ? _value.end
          // ignore: cast_nullable_to_non_nullable
          : end as String,
    );
  }
}

extension $BirthHourCopyWith on BirthHour {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfBirthHour.copyWith(...)` or `instanceOfBirthHour.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$BirthHourCWProxy get copyWith => _$BirthHourCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BirthHour _$BirthHourFromJson(Map<String, dynamic> json) => $checkedCreate(
  'BirthHour',
  json,
  ($checkedConvert) {
    $checkKeys(json, requiredKeys: const ['branch', 'start', 'end']);
    final val = BirthHour(
      branch: $checkedConvert('branch', (v) => $enumDecode(_$BranchEnumMap, v)),
      start: $checkedConvert('start', (v) => v as String),
      end: $checkedConvert('end', (v) => v as String),
    );
    return val;
  },
);

Map<String, dynamic> _$BirthHourToJson(BirthHour instance) => <String, dynamic>{
  'branch': _$BranchEnumMap[instance.branch]!,
  'start': instance.start,
  'end': instance.end,
};

const _$BranchEnumMap = {
  Branch.ja: 'ja',
  Branch.chuk: 'chuk',
  Branch.in_: 'in',
  Branch.myo: 'myo',
  Branch.jin: 'jin',
  Branch.sa: 'sa',
  Branch.o: 'o',
  Branch.mi: 'mi',
  Branch.shin: 'shin',
  Branch.yu: 'yu',
  Branch.sul: 'sul',
  Branch.hae: 'hae',
};
