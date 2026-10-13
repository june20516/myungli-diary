//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:myungli_diary/core/api/gen/model/pillar.dart';
import 'package:myungli_diary/core/api/gen/model/relation_kind.dart';
import 'package:myungli_diary/core/api/gen/model/ten_god.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'seun_year.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class SeunYear {
  /// Returns a new [SeunYear] instance.
  SeunYear({
    required this.year,

    required this.pillar,

    required this.tenGod,

    required this.relationsWithNatal,
  });

  @JsonKey(name: r'year', required: true, includeIfNull: false)
  final int year;

  @JsonKey(name: r'pillar', required: true, includeIfNull: false)
  final Pillar pillar;

  @JsonKey(name: r'tenGod', required: true, includeIfNull: false)
  final TenGod tenGod;

  @JsonKey(name: r'relationsWithNatal', required: true, includeIfNull: false)
  final List<RelationKind> relationsWithNatal;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SeunYear &&
          other.year == year &&
          other.pillar == pillar &&
          other.tenGod == tenGod &&
          other.relationsWithNatal == relationsWithNatal;

  @override
  int get hashCode =>
      year.hashCode +
      pillar.hashCode +
      tenGod.hashCode +
      relationsWithNatal.hashCode;

  factory SeunYear.fromJson(Map<String, dynamic> json) =>
      _$SeunYearFromJson(json);

  Map<String, dynamic> toJson() => _$SeunYearToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
