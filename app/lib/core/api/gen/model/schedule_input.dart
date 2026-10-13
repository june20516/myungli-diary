//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'schedule_input.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ScheduleInput {
  /// Returns a new [ScheduleInput] instance.
  ScheduleInput({
    required this.date,

    required this.allDay,

    this.time,

    required this.title,

    this.memo,
  });

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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScheduleInput &&
          other.date == date &&
          other.allDay == allDay &&
          other.time == time &&
          other.title == title &&
          other.memo == memo;

  @override
  int get hashCode =>
      date.hashCode +
      allDay.hashCode +
      time.hashCode +
      title.hashCode +
      memo.hashCode;

  factory ScheduleInput.fromJson(Map<String, dynamic> json) =>
      _$ScheduleInputFromJson(json);

  Map<String, dynamic> toJson() => _$ScheduleInputToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
