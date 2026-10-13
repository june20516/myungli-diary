//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'lunar_date.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class LunarDate {
  /// Returns a new [LunarDate] instance.
  LunarDate({
    required this.month,

    required this.day,

    required this.isLeapMonth,
  });

  @JsonKey(name: r'month', required: true, includeIfNull: false)
  final int month;

  @JsonKey(name: r'day', required: true, includeIfNull: false)
  final int day;

  @JsonKey(name: r'isLeapMonth', required: true, includeIfNull: false)
  final bool isLeapMonth;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LunarDate &&
          other.month == month &&
          other.day == day &&
          other.isLeapMonth == isLeapMonth;

  @override
  int get hashCode => month.hashCode + day.hashCode + isLeapMonth.hashCode;

  factory LunarDate.fromJson(Map<String, dynamic> json) =>
      _$LunarDateFromJson(json);

  Map<String, dynamic> toJson() => _$LunarDateToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
