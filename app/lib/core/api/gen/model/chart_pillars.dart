//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:myungli_diary/core/api/gen/model/pillar.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'chart_pillars.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ChartPillars {
  /// Returns a new [ChartPillars] instance.
  ChartPillars({
    required this.year,

    required this.month,

    required this.day,

    this.hour,
  });

  @JsonKey(name: r'year', required: true, includeIfNull: false)
  final Pillar year;

  @JsonKey(name: r'month', required: true, includeIfNull: false)
  final Pillar month;

  @JsonKey(name: r'day', required: true, includeIfNull: false)
  final Pillar day;

  @JsonKey(name: r'hour', required: false, includeIfNull: false)
  final Pillar? hour;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChartPillars &&
          other.year == year &&
          other.month == month &&
          other.day == day &&
          other.hour == hour;

  @override
  int get hashCode =>
      year.hashCode + month.hashCode + day.hashCode + hour.hashCode;

  factory ChartPillars.fromJson(Map<String, dynamic> json) =>
      _$ChartPillarsFromJson(json);

  Map<String, dynamic> toJson() => _$ChartPillarsToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
