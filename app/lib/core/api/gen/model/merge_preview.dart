//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:myungli_diary/core/api/gen/model/merge_summary.dart';
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
    required this.mergeToken,

    required this.expiresAt,

    required this.summary,
  });

  /// 합치기 토큰(랜덤 32바이트, base64url 패딩 없음). 일회용이고 현재 유저 계정의 bearer만 `mergeAccounts`에 쓸 수 있습니다. URL에 넣지 않습니다.
  @JsonKey(name: r'mergeToken', required: true, includeIfNull: false)
  final String mergeToken;

  /// 합치기 토큰 만료 시각(발급 + 10분)
  @JsonKey(name: r'expiresAt', required: true, includeIfNull: false)
  final DateTime expiresAt;

  @JsonKey(name: r'summary', required: true, includeIfNull: false)
  final MergeSummary summary;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MergePreview &&
          other.mergeToken == mergeToken &&
          other.expiresAt == expiresAt &&
          other.summary == summary;

  @override
  int get hashCode =>
      mergeToken.hashCode + expiresAt.hashCode + summary.hashCode;

  factory MergePreview.fromJson(Map<String, dynamic> json) =>
      _$MergePreviewFromJson(json);

  Map<String, dynamic> toJson() => _$MergePreviewToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
