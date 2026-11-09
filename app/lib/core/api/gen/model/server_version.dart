//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'server_version.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ServerVersion {
  /// Returns a new [ServerVersion] instance.
  ServerVersion({required this.supportedRulesetVersion});

  /// 이 server 빌드가 값과 메시지 키를 모두 다루는 엔진 `ruleset_version`의 가장 높은 값입니다(D110).
  @JsonKey(
    name: r'supportedRulesetVersion',
    required: true,
    includeIfNull: false,
  )
  final String supportedRulesetVersion;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ServerVersion &&
          other.supportedRulesetVersion == supportedRulesetVersion;

  @override
  int get hashCode => supportedRulesetVersion.hashCode;

  factory ServerVersion.fromJson(Map<String, dynamic> json) =>
      _$ServerVersionFromJson(json);

  Map<String, dynamic> toJson() => _$ServerVersionToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
