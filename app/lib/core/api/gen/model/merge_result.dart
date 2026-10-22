//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:myungli_diary/core/api/gen/model/token_pair.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'merge_result.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class MergeResult {
  /// Returns a new [MergeResult] instance.
  MergeResult({required this.accountId, required this.tokens});

  /// 남은 계정 id
  @JsonKey(name: r'accountId', required: true, includeIfNull: false)
  final String accountId;

  @JsonKey(name: r'tokens', required: true, includeIfNull: false)
  final TokenPair tokens;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MergeResult &&
          other.accountId == accountId &&
          other.tokens == tokens;

  @override
  int get hashCode => accountId.hashCode + tokens.hashCode;

  factory MergeResult.fromJson(Map<String, dynamic> json) =>
      _$MergeResultFromJson(json);

  Map<String, dynamic> toJson() => _$MergeResultToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
