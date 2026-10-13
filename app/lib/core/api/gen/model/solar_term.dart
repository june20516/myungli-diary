//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:myungli_diary/core/api/gen/model/solar_term_kind.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'solar_term.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class SolarTerm {
  /// Returns a new [SolarTerm] instance.
  SolarTerm({required this.kind, required this.at});

  @JsonKey(name: r'kind', required: true, includeIfNull: false)
  final SolarTermKind kind;

  /// 프로필 현재 시간대의 offset으로 나타냅니다.
  @JsonKey(name: r'at', required: true, includeIfNull: false)
  final DateTime at;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SolarTerm && other.kind == kind && other.at == at;

  @override
  int get hashCode => kind.hashCode + at.hashCode;

  factory SolarTerm.fromJson(Map<String, dynamic> json) =>
      _$SolarTermFromJson(json);

  Map<String, dynamic> toJson() => _$SolarTermToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
