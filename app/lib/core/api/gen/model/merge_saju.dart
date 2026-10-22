//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:myungli_diary/core/api/gen/model/calendar_type.dart';
import 'package:myungli_diary/core/api/gen/model/birth_time.dart';
import 'package:myungli_diary/core/api/gen/model/lunar_or_solar_date.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'merge_saju.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class MergeSaju {
  /// Returns a new [MergeSaju] instance.
  MergeSaju({
    required this.status,

    this.calendar,

    this.date,

    this.isLeapMonth,

    this.birthTime,
  });

  @JsonKey(name: r'status', required: true, includeIfNull: false)
  final MergeSajuStatusEnum status;

  @JsonKey(name: r'calendar', required: false, includeIfNull: false)
  final CalendarType? calendar;

  @JsonKey(name: r'date', required: false, includeIfNull: false)
  final LunarOrSolarDate? date;

  /// `Birth.isLeapMonth`와 같습니다. `calendar`가 `solar`면 false입니다.
  @JsonKey(name: r'isLeapMonth', required: false, includeIfNull: false)
  final bool? isLeapMonth;

  @JsonKey(name: r'birthTime', required: false, includeIfNull: false)
  final BirthTime? birthTime;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MergeSaju &&
          other.status == status &&
          other.calendar == calendar &&
          other.date == date &&
          other.isLeapMonth == isLeapMonth &&
          other.birthTime == birthTime;

  @override
  int get hashCode =>
      status.hashCode +
      calendar.hashCode +
      date.hashCode +
      isLeapMonth.hashCode +
      birthTime.hashCode;

  factory MergeSaju.fromJson(Map<String, dynamic> json) =>
      _$MergeSajuFromJson(json);

  Map<String, dynamic> toJson() => _$MergeSajuToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum MergeSajuStatusEnum {
  @JsonValue(r'saved')
  saved(r'saved'),
  @JsonValue(r'none')
  none(r'none');

  const MergeSajuStatusEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
