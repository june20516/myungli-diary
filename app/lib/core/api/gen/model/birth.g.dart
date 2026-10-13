// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'birth.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$BirthCWProxy {
  Birth calendar(CalendarType calendar);

  Birth date(LunarOrSolarDate date);

  Birth isLeapMonth(bool isLeapMonth);

  Birth time(BirthTime time);

  Birth gender(BirthGenderEnum gender);

  Birth timezone(String timezone);

  Birth place(BirthPlace place);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `Birth(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// Birth(...).copyWith(id: 12, name: "My name")
  /// ```
  Birth call({
    CalendarType calendar,
    LunarOrSolarDate date,
    bool isLeapMonth,
    BirthTime time,
    BirthGenderEnum gender,
    String timezone,
    BirthPlace place,
  });
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfBirth.copyWith(...)` or call `instanceOfBirth.copyWith.fieldName(value)` for a single field.
class _$BirthCWProxyImpl implements _$BirthCWProxy {
  const _$BirthCWProxyImpl(this._value);

  final Birth _value;

  @override
  Birth calendar(CalendarType calendar) => call(calendar: calendar);

  @override
  Birth date(LunarOrSolarDate date) => call(date: date);

  @override
  Birth isLeapMonth(bool isLeapMonth) => call(isLeapMonth: isLeapMonth);

  @override
  Birth time(BirthTime time) => call(time: time);

  @override
  Birth gender(BirthGenderEnum gender) => call(gender: gender);

  @override
  Birth timezone(String timezone) => call(timezone: timezone);

  @override
  Birth place(BirthPlace place) => call(place: place);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `Birth(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// Birth(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  Birth call({
    Object? calendar = const $CopyWithPlaceholder(),
    Object? date = const $CopyWithPlaceholder(),
    Object? isLeapMonth = const $CopyWithPlaceholder(),
    Object? time = const $CopyWithPlaceholder(),
    Object? gender = const $CopyWithPlaceholder(),
    Object? timezone = const $CopyWithPlaceholder(),
    Object? place = const $CopyWithPlaceholder(),
  }) {
    return Birth(
      calendar: calendar == const $CopyWithPlaceholder() || calendar == null
          ? _value.calendar
          // ignore: cast_nullable_to_non_nullable
          : calendar as CalendarType,
      date: date == const $CopyWithPlaceholder() || date == null
          ? _value.date
          // ignore: cast_nullable_to_non_nullable
          : date as LunarOrSolarDate,
      isLeapMonth:
          isLeapMonth == const $CopyWithPlaceholder() || isLeapMonth == null
          ? _value.isLeapMonth
          // ignore: cast_nullable_to_non_nullable
          : isLeapMonth as bool,
      time: time == const $CopyWithPlaceholder() || time == null
          ? _value.time
          // ignore: cast_nullable_to_non_nullable
          : time as BirthTime,
      gender: gender == const $CopyWithPlaceholder() || gender == null
          ? _value.gender
          // ignore: cast_nullable_to_non_nullable
          : gender as BirthGenderEnum,
      timezone: timezone == const $CopyWithPlaceholder() || timezone == null
          ? _value.timezone
          // ignore: cast_nullable_to_non_nullable
          : timezone as String,
      place: place == const $CopyWithPlaceholder() || place == null
          ? _value.place
          // ignore: cast_nullable_to_non_nullable
          : place as BirthPlace,
    );
  }
}

extension $BirthCopyWith on Birth {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfBirth.copyWith(...)` or `instanceOfBirth.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$BirthCWProxy get copyWith => _$BirthCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Birth _$BirthFromJson(Map<String, dynamic> json) =>
    $checkedCreate('Birth', json, ($checkedConvert) {
      $checkKeys(
        json,
        requiredKeys: const [
          'calendar',
          'date',
          'isLeapMonth',
          'time',
          'gender',
          'timezone',
          'place',
        ],
      );
      final val = Birth(
        calendar: $checkedConvert(
          'calendar',
          (v) => $enumDecode(_$CalendarTypeEnumMap, v),
        ),
        date: $checkedConvert(
          'date',
          (v) => LunarOrSolarDate.fromJson(v as Map<String, dynamic>),
        ),
        isLeapMonth: $checkedConvert('isLeapMonth', (v) => v as bool),
        time: $checkedConvert(
          'time',
          (v) => BirthTime.fromJson(v as Map<String, dynamic>),
        ),
        gender: $checkedConvert(
          'gender',
          (v) => $enumDecode(_$BirthGenderEnumEnumMap, v),
        ),
        timezone: $checkedConvert('timezone', (v) => v as String),
        place: $checkedConvert(
          'place',
          (v) => BirthPlace.fromJson(v as Map<String, dynamic>),
        ),
      );
      return val;
    });

Map<String, dynamic> _$BirthToJson(Birth instance) => <String, dynamic>{
  'calendar': _$CalendarTypeEnumMap[instance.calendar]!,
  'date': instance.date.toJson(),
  'isLeapMonth': instance.isLeapMonth,
  'time': instance.time.toJson(),
  'gender': _$BirthGenderEnumEnumMap[instance.gender]!,
  'timezone': instance.timezone,
  'place': instance.place.toJson(),
};

const _$CalendarTypeEnumMap = {
  CalendarType.solar: 'solar',
  CalendarType.lunar: 'lunar',
};

const _$BirthGenderEnumEnumMap = {
  BirthGenderEnum.male: 'male',
  BirthGenderEnum.female: 'female',
};
