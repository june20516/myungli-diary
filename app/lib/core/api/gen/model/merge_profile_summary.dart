//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:myungli_diary/core/api/gen/model/birth.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'merge_profile_summary.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class MergeProfileSummary {
  /// Returns a new [MergeProfileSummary] instance.
  MergeProfileSummary({required this.status, this.honorific, this.birth});

  @JsonKey(name: r'status', required: true, includeIfNull: false)
  final MergeProfileSummaryStatusEnum status;

  /// 호칭
  @JsonKey(name: r'honorific', required: false, includeIfNull: false)
  final String? honorific;

  @JsonKey(name: r'birth', required: false, includeIfNull: false)
  final Birth? birth;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MergeProfileSummary &&
          other.status == status &&
          other.honorific == honorific &&
          other.birth == birth;

  @override
  int get hashCode => status.hashCode + honorific.hashCode + birth.hashCode;

  factory MergeProfileSummary.fromJson(Map<String, dynamic> json) =>
      _$MergeProfileSummaryFromJson(json);

  Map<String, dynamic> toJson() => _$MergeProfileSummaryToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum MergeProfileSummaryStatusEnum {
  @JsonValue(r'saved')
  saved(r'saved'),
  @JsonValue(r'none')
  none(r'none');

  const MergeProfileSummaryStatusEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
