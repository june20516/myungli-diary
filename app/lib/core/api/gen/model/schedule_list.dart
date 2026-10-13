//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:myungli_diary/core/api/gen/model/schedule.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'schedule_list.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ScheduleList {
  /// Returns a new [ScheduleList] instance.
  ScheduleList({required this.items});

  @JsonKey(name: r'items', required: true, includeIfNull: false)
  final List<Schedule> items;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ScheduleList && other.items == items;

  @override
  int get hashCode => items.hashCode;

  factory ScheduleList.fromJson(Map<String, dynamic> json) =>
      _$ScheduleListFromJson(json);

  Map<String, dynamic> toJson() => _$ScheduleListToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
