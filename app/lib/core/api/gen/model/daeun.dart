//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:myungli_diary/core/api/gen/model/daeun_period.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'daeun.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class Daeun {
  /// Returns a new [Daeun] instance.
  Daeun({
    required this.forward,

    required this.startYears,

    required this.startMonths,

    required this.periods,
  });

  /// 순행 여부
  @JsonKey(name: r'forward', required: true, includeIfNull: false)
  final bool forward;

  @JsonKey(name: r'startYears', required: true, includeIfNull: false)
  final int startYears;

  @JsonKey(name: r'startMonths', required: true, includeIfNull: false)
  final int startMonths;

  @JsonKey(name: r'periods', required: true, includeIfNull: false)
  final List<DaeunPeriod> periods;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Daeun &&
          other.forward == forward &&
          other.startYears == startYears &&
          other.startMonths == startMonths &&
          other.periods == periods;

  @override
  int get hashCode =>
      forward.hashCode +
      startYears.hashCode +
      startMonths.hashCode +
      periods.hashCode;

  factory Daeun.fromJson(Map<String, dynamic> json) => _$DaeunFromJson(json);

  Map<String, dynamic> toJson() => _$DaeunToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
