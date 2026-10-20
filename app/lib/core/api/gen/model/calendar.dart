//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:myungli_diary/core/api/gen/model/evidence_access.dart';
import 'package:myungli_diary/core/api/gen/model/calendar_day.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'calendar.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class Calendar {
  /// Returns a new [Calendar] instance.
  Calendar({
    required this.year,

    required this.month,

    required this.rulesetVersion,

    required this.evidenceAccess,

    required this.days,
  });

  @JsonKey(name: r'year', required: true, includeIfNull: false)
  final int year;

  @JsonKey(name: r'month', required: true, includeIfNull: false)
  final int month;

  @JsonKey(name: r'rulesetVersion', required: true, includeIfNull: false)
  final String rulesetVersion;

  @JsonKey(name: r'evidenceAccess', required: true, includeIfNull: false)
  final EvidenceAccess evidenceAccess;

  @JsonKey(name: r'days', required: true, includeIfNull: false)
  final List<CalendarDay> days;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Calendar &&
          other.year == year &&
          other.month == month &&
          other.rulesetVersion == rulesetVersion &&
          other.evidenceAccess == evidenceAccess &&
          other.days == days;

  @override
  int get hashCode =>
      year.hashCode +
      month.hashCode +
      rulesetVersion.hashCode +
      evidenceAccess.hashCode +
      days.hashCode;

  factory Calendar.fromJson(Map<String, dynamic> json) =>
      _$CalendarFromJson(json);

  Map<String, dynamic> toJson() => _$CalendarToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
