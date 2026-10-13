//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:myungli_diary/core/api/gen/model/ten_god.dart';
import 'package:myungli_diary/core/api/gen/model/stem.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'hidden_stem.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class HiddenStem {
  /// Returns a new [HiddenStem] instance.
  HiddenStem({required this.stem, required this.tenGod});

  @JsonKey(name: r'stem', required: true, includeIfNull: false)
  final Stem stem;

  @JsonKey(name: r'tenGod', required: true, includeIfNull: false)
  final TenGod tenGod;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HiddenStem && other.stem == stem && other.tenGod == tenGod;

  @override
  int get hashCode => stem.hashCode + tenGod.hashCode;

  factory HiddenStem.fromJson(Map<String, dynamic> json) =>
      _$HiddenStemFromJson(json);

  Map<String, dynamic> toJson() => _$HiddenStemToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
