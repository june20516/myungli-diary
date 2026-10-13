//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'schedule_patch.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class SchedulePatch {
  /// Returns a new [SchedulePatch] instance.
  SchedulePatch({this.date, this.allDay, this.time, this.title, this.memo});

  @JsonKey(name: r'date', required: false, includeIfNull: false)
  final String? date;

  @JsonKey(name: r'allDay', required: false, includeIfNull: false)
  final bool? allDay;

  /// HH:MM
  @JsonKey(name: r'time', required: false, includeIfNull: false)
  final String? time;

  @JsonKey(name: r'title', required: false, includeIfNull: false)
  final String? title;

  @JsonKey(name: r'memo', required: false, includeIfNull: false)
  final String? memo;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SchedulePatch &&
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

  factory SchedulePatch.fromJson(Map<String, dynamic> json) =>
      _$SchedulePatchFromJson(json);

  Map<String, dynamic> toJson() => _$SchedulePatchToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
