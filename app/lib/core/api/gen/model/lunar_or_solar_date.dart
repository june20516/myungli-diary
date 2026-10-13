//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'lunar_or_solar_date.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class LunarOrSolarDate {
  /// Returns a new [LunarOrSolarDate] instance.
  LunarOrSolarDate({
    required this.year,

    required this.month,

    required this.day,
  });

  // minimum: 1900
  // maximum: 2099
  @JsonKey(name: r'year', required: true, includeIfNull: false)
  final int year;

  // minimum: 1
  // maximum: 12
  @JsonKey(name: r'month', required: true, includeIfNull: false)
  final int month;

  // minimum: 1
  // maximum: 31
  @JsonKey(name: r'day', required: true, includeIfNull: false)
  final int day;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LunarOrSolarDate &&
          other.year == year &&
          other.month == month &&
          other.day == day;

  @override
  int get hashCode => year.hashCode + month.hashCode + day.hashCode;

  factory LunarOrSolarDate.fromJson(Map<String, dynamic> json) =>
      _$LunarOrSolarDateFromJson(json);

  Map<String, dynamic> toJson() => _$LunarOrSolarDateToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
