//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:myungli_diary/core/api/gen/model/five_element.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'element_weight.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ElementWeight {
  /// Returns a new [ElementWeight] instance.
  ElementWeight({required this.element, required this.weight});

  @JsonKey(name: r'element', required: true, includeIfNull: false)
  final FiveElement element;

  @JsonKey(name: r'weight', required: true, includeIfNull: false)
  final num weight;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ElementWeight &&
          other.element == element &&
          other.weight == weight;

  @override
  int get hashCode => element.hashCode + weight.hashCode;

  factory ElementWeight.fromJson(Map<String, dynamic> json) =>
      _$ElementWeightFromJson(json);

  Map<String, dynamic> toJson() => _$ElementWeightToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
