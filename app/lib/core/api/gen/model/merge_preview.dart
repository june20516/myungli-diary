//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:myungli_diary/core/api/gen/model/merge_account_summary.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'merge_preview.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class MergePreview {
  /// Returns a new [MergePreview] instance.
  MergePreview({
    required this.current,

    required this.other,

    required this.overlapDayCount,
  });

  @JsonKey(name: r'current', required: true, includeIfNull: false)
  final MergeAccountSummary current;

  @JsonKey(name: r'other', required: true, includeIfNull: false)
  final MergeAccountSummary other;

  /// 두 계정 모두 살아 있는 일기가 있는 날짜 수. 0이면 app은 겹치는 날 안내를 보이지 않습니다.
  // minimum: 0
  @JsonKey(name: r'overlapDayCount', required: true, includeIfNull: false)
  final int overlapDayCount;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MergePreview &&
          other.current == current &&
          other.other == other &&
          other.overlapDayCount == overlapDayCount;

  @override
  int get hashCode =>
      current.hashCode + other.hashCode + overlapDayCount.hashCode;

  factory MergePreview.fromJson(Map<String, dynamic> json) =>
      _$MergePreviewFromJson(json);

  Map<String, dynamic> toJson() => _$MergePreviewToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
