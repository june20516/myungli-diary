//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'merge_preview_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class MergePreviewRequest {
  /// Returns a new [MergePreviewRequest] instance.
  MergePreviewRequest({required this.mergeToken});

  /// `linkIdentity`의 409 `auth.identity_in_use`가 준 합치기 토큰
  @JsonKey(name: r'mergeToken', required: true, includeIfNull: false)
  final String mergeToken;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MergePreviewRequest && other.mergeToken == mergeToken;

  @override
  int get hashCode => mergeToken.hashCode;

  factory MergePreviewRequest.fromJson(Map<String, dynamic> json) =>
      _$MergePreviewRequestFromJson(json);

  Map<String, dynamic> toJson() => _$MergePreviewRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
