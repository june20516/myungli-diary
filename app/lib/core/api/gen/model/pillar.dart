//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:myungli_diary/core/api/gen/model/branch.dart';
import 'package:myungli_diary/core/api/gen/model/stem.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'pillar.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class Pillar {
  /// Returns a new [Pillar] instance.
  Pillar({required this.stem, required this.branch});

  @JsonKey(name: r'stem', required: true, includeIfNull: false)
  final Stem stem;

  @JsonKey(name: r'branch', required: true, includeIfNull: false)
  final Branch branch;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Pillar && other.stem == stem && other.branch == branch;

  @override
  int get hashCode => stem.hashCode + branch.hashCode;

  factory Pillar.fromJson(Map<String, dynamic> json) => _$PillarFromJson(json);

  Map<String, dynamic> toJson() => _$PillarToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
