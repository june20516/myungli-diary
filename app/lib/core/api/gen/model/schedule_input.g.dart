// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'schedule_input.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ScheduleInputCWProxy {
  ScheduleInput date(String date);

  ScheduleInput allDay(bool allDay);

  ScheduleInput time(String? time);

  ScheduleInput title(String title);

  ScheduleInput memo(String? memo);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `ScheduleInput(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// ScheduleInput(...).copyWith(id: 12, name: "My name")
  /// ```
  ScheduleInput call({
    String date,
    bool allDay,
    String? time,
    String title,
    String? memo,
  });
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfScheduleInput.copyWith(...)` or call `instanceOfScheduleInput.copyWith.fieldName(value)` for a single field.
class _$ScheduleInputCWProxyImpl implements _$ScheduleInputCWProxy {
  const _$ScheduleInputCWProxyImpl(this._value);

  final ScheduleInput _value;

  @override
  ScheduleInput date(String date) => call(date: date);

  @override
  ScheduleInput allDay(bool allDay) => call(allDay: allDay);

  @override
  ScheduleInput time(String? time) => call(time: time);

  @override
  ScheduleInput title(String title) => call(title: title);

  @override
  ScheduleInput memo(String? memo) => call(memo: memo);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `ScheduleInput(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// ScheduleInput(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  ScheduleInput call({
    Object? date = const $CopyWithPlaceholder(),
    Object? allDay = const $CopyWithPlaceholder(),
    Object? time = const $CopyWithPlaceholder(),
    Object? title = const $CopyWithPlaceholder(),
    Object? memo = const $CopyWithPlaceholder(),
  }) {
    return ScheduleInput(
      date: date == const $CopyWithPlaceholder() || date == null
          ? _value.date
          // ignore: cast_nullable_to_non_nullable
          : date as String,
      allDay: allDay == const $CopyWithPlaceholder() || allDay == null
          ? _value.allDay
          // ignore: cast_nullable_to_non_nullable
          : allDay as bool,
      time: time == const $CopyWithPlaceholder()
          ? _value.time
          // ignore: cast_nullable_to_non_nullable
          : time as String?,
      title: title == const $CopyWithPlaceholder() || title == null
          ? _value.title
          // ignore: cast_nullable_to_non_nullable
          : title as String,
      memo: memo == const $CopyWithPlaceholder()
          ? _value.memo
          // ignore: cast_nullable_to_non_nullable
          : memo as String?,
    );
  }
}

extension $ScheduleInputCopyWith on ScheduleInput {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfScheduleInput.copyWith(...)` or `instanceOfScheduleInput.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ScheduleInputCWProxy get copyWith => _$ScheduleInputCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ScheduleInput _$ScheduleInputFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ScheduleInput', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['date', 'allDay', 'title']);
      final val = ScheduleInput(
        date: $checkedConvert('date', (v) => v as String),
        allDay: $checkedConvert('allDay', (v) => v as bool),
        time: $checkedConvert('time', (v) => v as String?),
        title: $checkedConvert('title', (v) => v as String),
        memo: $checkedConvert('memo', (v) => v as String?),
      );
      return val;
    });

Map<String, dynamic> _$ScheduleInputToJson(ScheduleInput instance) =>
    <String, dynamic>{
      'date': instance.date,
      'allDay': instance.allDay,
      'time': ?instance.time,
      'title': instance.title,
      'memo': ?instance.memo,
    };
