// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'birth_hour_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$BirthHourRequestCWProxy {
  BirthHourRequest installationId(String installationId);

  BirthHourRequest calendar(CalendarType calendar);

  BirthHourRequest date(LunarOrSolarDate date);

  BirthHourRequest isLeapMonth(bool isLeapMonth);

  BirthHourRequest time(String time);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `BirthHourRequest(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// BirthHourRequest(...).copyWith(id: 12, name: "My name")
  /// ```
  BirthHourRequest call({
    String installationId,
    CalendarType calendar,
    LunarOrSolarDate date,
    bool isLeapMonth,
    String time,
  });
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfBirthHourRequest.copyWith(...)` or call `instanceOfBirthHourRequest.copyWith.fieldName(value)` for a single field.
class _$BirthHourRequestCWProxyImpl implements _$BirthHourRequestCWProxy {
  const _$BirthHourRequestCWProxyImpl(this._value);

  final BirthHourRequest _value;

  @override
  BirthHourRequest installationId(String installationId) =>
      call(installationId: installationId);

  @override
  BirthHourRequest calendar(CalendarType calendar) => call(calendar: calendar);

  @override
  BirthHourRequest date(LunarOrSolarDate date) => call(date: date);

  @override
  BirthHourRequest isLeapMonth(bool isLeapMonth) =>
      call(isLeapMonth: isLeapMonth);

  @override
  BirthHourRequest time(String time) => call(time: time);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `BirthHourRequest(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// BirthHourRequest(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  BirthHourRequest call({
    Object? installationId = const $CopyWithPlaceholder(),
    Object? calendar = const $CopyWithPlaceholder(),
    Object? date = const $CopyWithPlaceholder(),
    Object? isLeapMonth = const $CopyWithPlaceholder(),
    Object? time = const $CopyWithPlaceholder(),
  }) {
    return BirthHourRequest(
      installationId:
          installationId == const $CopyWithPlaceholder() ||
              installationId == null
          ? _value.installationId
          // ignore: cast_nullable_to_non_nullable
          : installationId as String,
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
          : time as String,
    );
  }
}

extension $BirthHourRequestCopyWith on BirthHourRequest {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfBirthHourRequest.copyWith(...)` or `instanceOfBirthHourRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$BirthHourRequestCWProxy get copyWith => _$BirthHourRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BirthHourRequest _$BirthHourRequestFromJson(Map<String, dynamic> json) =>
    $checkedCreate('BirthHourRequest', json, ($checkedConvert) {
      $checkKeys(
        json,
        requiredKeys: const [
          'installationId',
          'calendar',
          'date',
          'isLeapMonth',
          'time',
        ],
      );
      final val = BirthHourRequest(
        installationId: $checkedConvert('installationId', (v) => v as String),
        calendar: $checkedConvert(
          'calendar',
          (v) => $enumDecode(_$CalendarTypeEnumMap, v),
        ),
        date: $checkedConvert(
          'date',
          (v) => LunarOrSolarDate.fromJson(v as Map<String, dynamic>),
        ),
        isLeapMonth: $checkedConvert('isLeapMonth', (v) => v as bool),
        time: $checkedConvert('time', (v) => v as String),
      );
      return val;
    });

Map<String, dynamic> _$BirthHourRequestToJson(BirthHourRequest instance) =>
    <String, dynamic>{
      'installationId': instance.installationId,
      'calendar': _$CalendarTypeEnumMap[instance.calendar]!,
      'date': instance.date.toJson(),
      'isLeapMonth': instance.isLeapMonth,
      'time': instance.time,
    };

const _$CalendarTypeEnumMap = {
  CalendarType.solar: 'solar',
  CalendarType.lunar: 'lunar',
};
