//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:myungli_diary/core/api/gen/model/rendered_text.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'evidence_preview.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class EvidencePreview {
  /// Returns a new [EvidencePreview] instance.
  EvidencePreview({this.basis, this.source_});

  @JsonKey(name: r'basis', required: false, includeIfNull: false)
  final RenderedText? basis;

  @JsonKey(name: r'source', required: false, includeIfNull: false)
  final RenderedText? source_;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EvidencePreview &&
          other.basis == basis &&
          other.source_ == source_;

  @override
  int get hashCode => basis.hashCode + source_.hashCode;

  factory EvidencePreview.fromJson(Map<String, dynamic> json) =>
      _$EvidencePreviewFromJson(json);

  Map<String, dynamic> toJson() => _$EvidencePreviewToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
