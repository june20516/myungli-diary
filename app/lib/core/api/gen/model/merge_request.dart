//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
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
  MergeRequest({required this.mergeToken, required this.keep});

  /// `linkIdentity`의 409 `auth.identity_in_use`가 준 합치기 토큰
  @JsonKey(name: r'mergeToken', required: true, includeIfNull: false)
  final String mergeToken;

  /// 남길 계정. `current`는 요청한 bearer 계정, `other`는 붙이려던 연결을 가진 다른 계정입니다. 반대쪽이 없앨 계정입니다.
  @JsonKey(name: r'keep', required: true, includeIfNull: false)
  final MergeRequestKeepEnum keep;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MergeRequest &&
          other.mergeToken == mergeToken &&
          other.keep == keep;

  @override
  int get hashCode => mergeToken.hashCode + keep.hashCode;

  factory MergeRequest.fromJson(Map<String, dynamic> json) =>
      _$MergeRequestFromJson(json);

  Map<String, dynamic> toJson() => _$MergeRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

/// 남길 계정. `current`는 요청한 bearer 계정, `other`는 붙이려던 연결을 가진 다른 계정입니다. 반대쪽이 없앨 계정입니다.
enum MergeRequestKeepEnum {
  @JsonValue(r'current')
  current(r'current'),
  @JsonValue(r'other')
  other(r'other');

  const MergeRequestKeepEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
