//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:myungli_diary/core/api/gen/model/calendar_type.dart';
import 'package:myungli_diary/core/api/gen/model/lunar_or_solar_date.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'birth_hour_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class BirthHourRequest {
  /// Returns a new [BirthHourRequest] instance.
  BirthHourRequest({
    required this.installationId,

    required this.calendar,

    required this.date,

    required this.isLeapMonth,

    required this.time,
  });

  /// 앱 설치마다 만든 무작위 값
  @JsonKey(name: r'installationId', required: true, includeIfNull: false)
  final String installationId;

  @JsonKey(name: r'calendar', required: true, includeIfNull: false)
  final CalendarType calendar;

  @JsonKey(name: r'date', required: true, includeIfNull: false)
  final LunarOrSolarDate date;

  /// `calendar`가 `solar`면 false입니다. 양력인데 true면 422 `request.inconsistent`(`forbidden_by_status`)입니다.
  @JsonKey(name: r'isLeapMonth', required: true, includeIfNull: false)
  final bool isLeapMonth;

  /// HH:MM
  @JsonKey(name: r'time', required: true, includeIfNull: false)
  final String time;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BirthHourRequest &&
          other.installationId == installationId &&
          other.calendar == calendar &&
          other.date == date &&
          other.isLeapMonth == isLeapMonth &&
          other.time == time;

  @override
  int get hashCode =>
      installationId.hashCode +
      calendar.hashCode +
      date.hashCode +
      isLeapMonth.hashCode +
      time.hashCode;

  factory BirthHourRequest.fromJson(Map<String, dynamic> json) =>
      _$BirthHourRequestFromJson(json);

  Map<String, dynamic> toJson() => _$BirthHourRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
