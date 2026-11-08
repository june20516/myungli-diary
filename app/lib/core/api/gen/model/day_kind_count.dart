//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:myungli_diary/core/api/gen/model/day_kind.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'day_kind_count.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class DayKindCount {
  /// Returns a new [DayKindCount] instance.
  DayKindCount({required this.dayKind, required this.days});

  @JsonKey(name: r'dayKind', required: true, includeIfNull: false)
  final DayKind dayKind;

  /// 그날 성격으로 기록된, 살아 있는 일기가 있는 날짜 수
  // minimum: 0
  @JsonKey(name: r'days', required: true, includeIfNull: false)
  final int days;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DayKindCount && other.dayKind == dayKind && other.days == days;

  @override
  int get hashCode => dayKind.hashCode + days.hashCode;

  factory DayKindCount.fromJson(Map<String, dynamic> json) =>
      _$DayKindCountFromJson(json);

  Map<String, dynamic> toJson() => _$DayKindCountToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
