// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'schedule.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ScheduleCWProxy {
  Schedule id(String id);

  Schedule date(String date);

  Schedule allDay(bool allDay);

  Schedule time(String? time);

  Schedule title(String title);

  Schedule memo(String? memo);

  Schedule createdAt(DateTime createdAt);

  Schedule updatedAt(DateTime updatedAt);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `Schedule(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// Schedule(...).copyWith(id: 12, name: "My name")
  /// ```
  Schedule call({
    String id,
    String date,
    bool allDay,
    String? time,
    String title,
    String? memo,
    DateTime createdAt,
    DateTime updatedAt,
  });
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfSchedule.copyWith(...)` or call `instanceOfSchedule.copyWith.fieldName(value)` for a single field.
class _$ScheduleCWProxyImpl implements _$ScheduleCWProxy {
  const _$ScheduleCWProxyImpl(this._value);

  final Schedule _value;

  @override
  Schedule id(String id) => call(id: id);

  @override
  Schedule date(String date) => call(date: date);

  @override
  Schedule allDay(bool allDay) => call(allDay: allDay);

  @override
  Schedule time(String? time) => call(time: time);

  @override
  Schedule title(String title) => call(title: title);

  @override
  Schedule memo(String? memo) => call(memo: memo);

  @override
  Schedule createdAt(DateTime createdAt) => call(createdAt: createdAt);

  @override
  Schedule updatedAt(DateTime updatedAt) => call(updatedAt: updatedAt);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `Schedule(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// Schedule(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  Schedule call({
    Object? id = const $CopyWithPlaceholder(),
    Object? date = const $CopyWithPlaceholder(),
    Object? allDay = const $CopyWithPlaceholder(),
    Object? time = const $CopyWithPlaceholder(),
    Object? title = const $CopyWithPlaceholder(),
    Object? memo = const $CopyWithPlaceholder(),
    Object? createdAt = const $CopyWithPlaceholder(),
    Object? updatedAt = const $CopyWithPlaceholder(),
  }) {
    return Schedule(
      id: id == const $CopyWithPlaceholder() || id == null
          ? _value.id
          // ignore: cast_nullable_to_non_nullable
          : id as String,
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
      createdAt: createdAt == const $CopyWithPlaceholder() || createdAt == null
          ? _value.createdAt
          // ignore: cast_nullable_to_non_nullable
          : createdAt as DateTime,
      updatedAt: updatedAt == const $CopyWithPlaceholder() || updatedAt == null
          ? _value.updatedAt
          // ignore: cast_nullable_to_non_nullable
          : updatedAt as DateTime,
    );
  }
}

extension $ScheduleCopyWith on Schedule {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfSchedule.copyWith(...)` or `instanceOfSchedule.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ScheduleCWProxy get copyWith => _$ScheduleCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Schedule _$ScheduleFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('Schedule', json, ($checkedConvert) {
  $checkKeys(
    json,
    requiredKeys: const [
      'id',
      'date',
      'allDay',
      'title',
      'createdAt',
      'updatedAt',
    ],
  );
  final val = Schedule(
    id: $checkedConvert('id', (v) => v as String),
    date: $checkedConvert('date', (v) => v as String),
    allDay: $checkedConvert('allDay', (v) => v as bool),
    time: $checkedConvert('time', (v) => v as String?),
    title: $checkedConvert('title', (v) => v as String),
    memo: $checkedConvert('memo', (v) => v as String?),
    createdAt: $checkedConvert('createdAt', (v) => DateTime.parse(v as String)),
    updatedAt: $checkedConvert('updatedAt', (v) => DateTime.parse(v as String)),
  );
  return val;
});

Map<String, dynamic> _$ScheduleToJson(Schedule instance) => <String, dynamic>{
  'id': instance.id,
  'date': instance.date,
  'allDay': instance.allDay,
  'time': ?instance.time,
  'title': instance.title,
  'memo': ?instance.memo,
  'createdAt': instance.createdAt.toIso8601String(),
  'updatedAt': instance.updatedAt.toIso8601String(),
};
