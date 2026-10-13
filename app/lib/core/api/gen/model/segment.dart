//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'segment.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class Segment {
  /// Returns a new [Segment] instance.
  Segment({required this.text, this.term});

  @JsonKey(name: r'text', required: true, includeIfNull: false)
  final String text;

  /// 이 조각이 용어면 그 용어 값
  @JsonKey(name: r'term', required: false, includeIfNull: false)
  final String? term;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Segment && other.text == text && other.term == term;

  @override
  int get hashCode => text.hashCode + term.hashCode;

  factory Segment.fromJson(Map<String, dynamic> json) =>
      _$SegmentFromJson(json);

  Map<String, dynamic> toJson() => _$SegmentToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
