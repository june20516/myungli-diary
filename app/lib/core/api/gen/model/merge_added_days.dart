//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'merge_added_days.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class MergeAddedDays {
  /// Returns a new [MergeAddedDays] instance.
  MergeAddedDays({required this.adFree});

  /// 광고 제거권 남은 날. 같은 구매가 주는 근거·해석 열람(insight)도 같은 기간입니다.
  // minimum: 0
  @JsonKey(name: r'adFree', required: true, includeIfNull: false)
  final int adFree;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MergeAddedDays && other.adFree == adFree;

  @override
  int get hashCode => adFree.hashCode;

  factory MergeAddedDays.fromJson(Map<String, dynamic> json) =>
      _$MergeAddedDaysFromJson(json);

  Map<String, dynamic> toJson() => _$MergeAddedDaysToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
