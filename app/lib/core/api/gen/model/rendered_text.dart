//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:myungli_diary/core/api/gen/model/segment.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'rendered_text.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class RenderedText {
  /// Returns a new [RenderedText] instance.
  RenderedText({required this.segments});

  @JsonKey(name: r'segments', required: true, includeIfNull: false)
  final List<Segment> segments;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RenderedText && other.segments == segments;

  @override
  int get hashCode => segments.hashCode;

  factory RenderedText.fromJson(Map<String, dynamic> json) =>
      _$RenderedTextFromJson(json);

  Map<String, dynamic> toJson() => _$RenderedTextToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
