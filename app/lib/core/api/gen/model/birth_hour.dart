//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:myungli_diary/core/api/gen/model/branch.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'birth_hour.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class BirthHour {
  /// Returns a new [BirthHour] instance.
  BirthHour({required this.branch, required this.start, required this.end});

  @JsonKey(name: r'branch', required: true, includeIfNull: false)
  final Branch branch;

  /// HH:MM, 벽시계 기준
  @JsonKey(name: r'start', required: true, includeIfNull: false)
  final String start;

  /// HH:MM, 벽시계 기준
  @JsonKey(name: r'end', required: true, includeIfNull: false)
  final String end;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BirthHour &&
          other.branch == branch &&
          other.start == start &&
          other.end == end;

  @override
  int get hashCode => branch.hashCode + start.hashCode + end.hashCode;

  factory BirthHour.fromJson(Map<String, dynamic> json) =>
      _$BirthHourFromJson(json);

  Map<String, dynamic> toJson() => _$BirthHourToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
