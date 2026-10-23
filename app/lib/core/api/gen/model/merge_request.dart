//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:myungli_diary/core/api/gen/model/merge_profile.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'merge_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class MergeRequest {
  /// Returns a new [MergeRequest] instance.
  MergeRequest({required this.mergeToken, required this.profile});

  /// `previewMerge`가 준 합치기 토큰
  @JsonKey(name: r'mergeToken', required: true, includeIfNull: false)
  final String mergeToken;

  @JsonKey(name: r'profile', required: true, includeIfNull: false)
  final MergeProfile profile;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MergeRequest &&
          other.mergeToken == mergeToken &&
          other.profile == profile;

  @override
  int get hashCode => mergeToken.hashCode + profile.hashCode;

  factory MergeRequest.fromJson(Map<String, dynamic> json) =>
      _$MergeRequestFromJson(json);

  Map<String, dynamic> toJson() => _$MergeRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
