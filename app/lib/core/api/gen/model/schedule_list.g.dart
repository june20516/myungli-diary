// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'schedule_list.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ScheduleListCWProxy {
  ScheduleList items(List<Schedule> items);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `ScheduleList(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// ScheduleList(...).copyWith(id: 12, name: "My name")
  /// ```
  ScheduleList call({List<Schedule> items});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfScheduleList.copyWith(...)` or call `instanceOfScheduleList.copyWith.fieldName(value)` for a single field.
class _$ScheduleListCWProxyImpl implements _$ScheduleListCWProxy {
  const _$ScheduleListCWProxyImpl(this._value);

  final ScheduleList _value;

  @override
  ScheduleList items(List<Schedule> items) => call(items: items);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `ScheduleList(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// ScheduleList(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  ScheduleList call({Object? items = const $CopyWithPlaceholder()}) {
    return ScheduleList(
      items: items == const $CopyWithPlaceholder() || items == null
          ? _value.items
          // ignore: cast_nullable_to_non_nullable
          : items as List<Schedule>,
    );
  }
}

extension $ScheduleListCopyWith on ScheduleList {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfScheduleList.copyWith(...)` or `instanceOfScheduleList.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ScheduleListCWProxy get copyWith => _$ScheduleListCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ScheduleList _$ScheduleListFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ScheduleList', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['items']);
      final val = ScheduleList(
        items: $checkedConvert(
          'items',
          (v) => (v as List<dynamic>)
              .map((e) => Schedule.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
      );
      return val;
    });

Map<String, dynamic> _$ScheduleListToJson(ScheduleList instance) =>
    <String, dynamic>{'items': instance.items.map((e) => e.toJson()).toList()};
