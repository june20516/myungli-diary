//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:myungli_diary/core/api/gen/model/birth_place.dart';
import 'package:myungli_diary/core/api/gen/model/calendar_type.dart';
import 'package:myungli_diary/core/api/gen/model/birth_time.dart';
import 'package:myungli_diary/core/api/gen/model/lunar_or_solar_date.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'birth.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class Birth {
  /// Returns a new [Birth] instance.
  Birth({
    required this.calendar,

    required this.date,

    required this.isLeapMonth,

    required this.time,

    required this.gender,

    required this.timezone,

    required this.place,
  });

  @JsonKey(name: r'calendar', required: true, includeIfNull: false)
  final CalendarType calendar;

  @JsonKey(name: r'date', required: true, includeIfNull: false)
  final LunarOrSolarDate date;

  /// `calendar`가 `solar`면 false입니다. 양력인데 true면 422 `request.inconsistent`(`forbidden_by_status`)입니다. 음력 날짜가 존재하지 않으면(예 윤달이 없는 달의 윤달) 엔진 판정 422 `birth.invalid`입니다.
  @JsonKey(name: r'isLeapMonth', required: true, includeIfNull: false)
  final bool isLeapMonth;

  @JsonKey(name: r'time', required: true, includeIfNull: false)
  final BirthTime time;

  @JsonKey(name: r'gender', required: true, includeIfNull: false)
  final BirthGenderEnum gender;

  /// 출생 시간대 IANA 이름(예 `Asia/Seoul`)
  @JsonKey(name: r'timezone', required: true, includeIfNull: false)
  final String timezone;

  @JsonKey(name: r'place', required: true, includeIfNull: false)
  final BirthPlace place;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Birth &&
          other.calendar == calendar &&
          other.date == date &&
          other.isLeapMonth == isLeapMonth &&
          other.time == time &&
          other.gender == gender &&
          other.timezone == timezone &&
          other.place == place;

  @override
  int get hashCode =>
      calendar.hashCode +
      date.hashCode +
      isLeapMonth.hashCode +
      time.hashCode +
      gender.hashCode +
      timezone.hashCode +
      place.hashCode;

  factory Birth.fromJson(Map<String, dynamic> json) => _$BirthFromJson(json);

  Map<String, dynamic> toJson() => _$BirthToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum BirthGenderEnum {
  @JsonValue(r'male')
  male(r'male'),
  @JsonValue(r'female')
  female(r'female');

  const BirthGenderEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
