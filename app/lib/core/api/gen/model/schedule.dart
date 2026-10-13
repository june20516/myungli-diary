//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'schedule.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class Schedule {
  /// Returns a new [Schedule] instance.
  Schedule({
    required this.id,

    required this.date,

    required this.allDay,

    this.time,

    required this.title,

    this.memo,

    required this.createdAt,

    required this.updatedAt,
  });

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final String id;

  @JsonKey(name: r'date', required: true, includeIfNull: false)
  final String date;

  @JsonKey(name: r'allDay', required: true, includeIfNull: false)
  final bool allDay;

  /// HH:MM
  @JsonKey(name: r'time', required: false, includeIfNull: false)
  final String? time;

  @JsonKey(name: r'title', required: true, includeIfNull: false)
  final String title;

  @JsonKey(name: r'memo', required: false, includeIfNull: false)
  final String? memo;

  @JsonKey(name: r'createdAt', required: true, includeIfNull: false)
  final DateTime createdAt;

  @JsonKey(name: r'updatedAt', required: true, includeIfNull: false)
  final DateTime updatedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Schedule &&
          other.id == id &&
          other.date == date &&
          other.allDay == allDay &&
          other.time == time &&
          other.title == title &&
          other.memo == memo &&
          other.createdAt == createdAt &&
          other.updatedAt == updatedAt;

  @override
  int get hashCode =>
      id.hashCode +
      date.hashCode +
      allDay.hashCode +
      time.hashCode +
      title.hashCode +
      memo.hashCode +
      createdAt.hashCode +
      updatedAt.hashCode;

  factory Schedule.fromJson(Map<String, dynamic> json) =>
      _$ScheduleFromJson(json);

  Map<String, dynamic> toJson() => _$ScheduleToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
