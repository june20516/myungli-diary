// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'merge_saju.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$MergeSajuCWProxy {
  MergeSaju status(MergeSajuStatusEnum status);

  MergeSaju calendar(CalendarType? calendar);

  MergeSaju date(LunarOrSolarDate? date);

  MergeSaju isLeapMonth(bool? isLeapMonth);

  MergeSaju birthTime(BirthTime? birthTime);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `MergeSaju(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// MergeSaju(...).copyWith(id: 12, name: "My name")
  /// ```
  MergeSaju call({
    MergeSajuStatusEnum status,
    CalendarType? calendar,
    LunarOrSolarDate? date,
    bool? isLeapMonth,
    BirthTime? birthTime,
  });
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfMergeSaju.copyWith(...)` or call `instanceOfMergeSaju.copyWith.fieldName(value)` for a single field.
class _$MergeSajuCWProxyImpl implements _$MergeSajuCWProxy {
  const _$MergeSajuCWProxyImpl(this._value);

  final MergeSaju _value;

  @override
  MergeSaju status(MergeSajuStatusEnum status) => call(status: status);

  @override
  MergeSaju calendar(CalendarType? calendar) => call(calendar: calendar);

  @override
  MergeSaju date(LunarOrSolarDate? date) => call(date: date);

  @override
  MergeSaju isLeapMonth(bool? isLeapMonth) => call(isLeapMonth: isLeapMonth);

  @override
  MergeSaju birthTime(BirthTime? birthTime) => call(birthTime: birthTime);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `MergeSaju(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// MergeSaju(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  MergeSaju call({
    Object? status = const $CopyWithPlaceholder(),
    Object? calendar = const $CopyWithPlaceholder(),
    Object? date = const $CopyWithPlaceholder(),
    Object? isLeapMonth = const $CopyWithPlaceholder(),
    Object? birthTime = const $CopyWithPlaceholder(),
  }) {
    return MergeSaju(
      status: status == const $CopyWithPlaceholder() || status == null
          ? _value.status
          // ignore: cast_nullable_to_non_nullable
          : status as MergeSajuStatusEnum,
      calendar: calendar == const $CopyWithPlaceholder()
          ? _value.calendar
          // ignore: cast_nullable_to_non_nullable
          : calendar as CalendarType?,
      date: date == const $CopyWithPlaceholder()
          ? _value.date
          // ignore: cast_nullable_to_non_nullable
          : date as LunarOrSolarDate?,
      isLeapMonth: isLeapMonth == const $CopyWithPlaceholder()
          ? _value.isLeapMonth
          // ignore: cast_nullable_to_non_nullable
          : isLeapMonth as bool?,
      birthTime: birthTime == const $CopyWithPlaceholder()
          ? _value.birthTime
          // ignore: cast_nullable_to_non_nullable
          : birthTime as BirthTime?,
    );
  }
}

extension $MergeSajuCopyWith on MergeSaju {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfMergeSaju.copyWith(...)` or `instanceOfMergeSaju.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$MergeSajuCWProxy get copyWith => _$MergeSajuCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MergeSaju _$MergeSajuFromJson(Map<String, dynamic> json) =>
    $checkedCreate('MergeSaju', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['status']);
      final val = MergeSaju(
        status: $checkedConvert(
          'status',
          (v) => $enumDecode(_$MergeSajuStatusEnumEnumMap, v),
        ),
        calendar: $checkedConvert(
          'calendar',
          (v) => $enumDecodeNullable(_$CalendarTypeEnumMap, v),
        ),
        date: $checkedConvert(
          'date',
          (v) => v == null
              ? null
              : LunarOrSolarDate.fromJson(v as Map<String, dynamic>),
        ),
        isLeapMonth: $checkedConvert('isLeapMonth', (v) => v as bool?),
        birthTime: $checkedConvert(
          'birthTime',
          (v) =>
              v == null ? null : BirthTime.fromJson(v as Map<String, dynamic>),
        ),
      );
      return val;
    });

Map<String, dynamic> _$MergeSajuToJson(MergeSaju instance) => <String, dynamic>{
  'status': _$MergeSajuStatusEnumEnumMap[instance.status]!,
  'calendar': ?_$CalendarTypeEnumMap[instance.calendar],
  'date': ?instance.date?.toJson(),
  'isLeapMonth': ?instance.isLeapMonth,
  'birthTime': ?instance.birthTime?.toJson(),
};

const _$MergeSajuStatusEnumEnumMap = {
  MergeSajuStatusEnum.saved: 'saved',
  MergeSajuStatusEnum.none: 'none',
};

const _$CalendarTypeEnumMap = {
  CalendarType.solar: 'solar',
  CalendarType.lunar: 'lunar',
};
