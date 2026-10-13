// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'schedule_patch.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$SchedulePatchCWProxy {
  SchedulePatch date(String? date);

  SchedulePatch allDay(bool? allDay);

  SchedulePatch time(String? time);

  SchedulePatch title(String? title);

  SchedulePatch memo(String? memo);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `SchedulePatch(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// SchedulePatch(...).copyWith(id: 12, name: "My name")
  /// ```
  SchedulePatch call({
    String? date,
    bool? allDay,
    String? time,
    String? title,
    String? memo,
  });
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfSchedulePatch.copyWith(...)` or call `instanceOfSchedulePatch.copyWith.fieldName(value)` for a single field.
class _$SchedulePatchCWProxyImpl implements _$SchedulePatchCWProxy {
  const _$SchedulePatchCWProxyImpl(this._value);

  final SchedulePatch _value;

  @override
  SchedulePatch date(String? date) => call(date: date);

  @override
  SchedulePatch allDay(bool? allDay) => call(allDay: allDay);

  @override
  SchedulePatch time(String? time) => call(time: time);

  @override
  SchedulePatch title(String? title) => call(title: title);

  @override
  SchedulePatch memo(String? memo) => call(memo: memo);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `SchedulePatch(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// SchedulePatch(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  SchedulePatch call({
    Object? date = const $CopyWithPlaceholder(),
    Object? allDay = const $CopyWithPlaceholder(),
    Object? time = const $CopyWithPlaceholder(),
    Object? title = const $CopyWithPlaceholder(),
    Object? memo = const $CopyWithPlaceholder(),
  }) {
    return SchedulePatch(
      date: date == const $CopyWithPlaceholder()
          ? _value.date
          // ignore: cast_nullable_to_non_nullable
          : date as String?,
      allDay: allDay == const $CopyWithPlaceholder()
          ? _value.allDay
          // ignore: cast_nullable_to_non_nullable
          : allDay as bool?,
      time: time == const $CopyWithPlaceholder()
          ? _value.time
          // ignore: cast_nullable_to_non_nullable
          : time as String?,
      title: title == const $CopyWithPlaceholder()
          ? _value.title
          // ignore: cast_nullable_to_non_nullable
          : title as String?,
      memo: memo == const $CopyWithPlaceholder()
          ? _value.memo
          // ignore: cast_nullable_to_non_nullable
          : memo as String?,
    );
  }
}

extension $SchedulePatchCopyWith on SchedulePatch {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfSchedulePatch.copyWith(...)` or `instanceOfSchedulePatch.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$SchedulePatchCWProxy get copyWith => _$SchedulePatchCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SchedulePatch _$SchedulePatchFromJson(Map<String, dynamic> json) =>
    $checkedCreate('SchedulePatch', json, ($checkedConvert) {
      final val = SchedulePatch(
        date: $checkedConvert('date', (v) => v as String?),
        allDay: $checkedConvert('allDay', (v) => v as bool?),
        time: $checkedConvert('time', (v) => v as String?),
        title: $checkedConvert('title', (v) => v as String?),
        memo: $checkedConvert('memo', (v) => v as String?),
      );
      return val;
    });

Map<String, dynamic> _$SchedulePatchToJson(SchedulePatch instance) =>
    <String, dynamic>{
      'date': ?instance.date,
      'allDay': ?instance.allDay,
      'time': ?instance.time,
      'title': ?instance.title,
      'memo': ?instance.memo,
    };
