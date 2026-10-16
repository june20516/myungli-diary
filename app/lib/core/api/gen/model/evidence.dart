//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:myungli_diary/core/api/gen/model/rendered_text.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'evidence.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class Evidence {
  /// Returns a new [Evidence] instance.
  Evidence({
    required this.ruleId,

    required this.sourceRef,

    this.detail,

    this.basis,

    this.source_,
  });

  @JsonKey(name: r'ruleId', required: true, includeIfNull: false)
  final String ruleId;

  @JsonKey(name: r'sourceRef', required: true, includeIfNull: false)
  final String sourceRef;

  @JsonKey(name: r'detail', required: false, includeIfNull: false)
  final Map<String, String>? detail;

  @JsonKey(name: r'basis', required: false, includeIfNull: false)
  final RenderedText? basis;

  @JsonKey(name: r'source', required: false, includeIfNull: false)
  final RenderedText? source_;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Evidence &&
          other.ruleId == ruleId &&
          other.sourceRef == sourceRef &&
          other.detail == detail &&
          other.basis == basis &&
          other.source_ == source_;

  @override
  int get hashCode =>
      ruleId.hashCode +
      sourceRef.hashCode +
      detail.hashCode +
      basis.hashCode +
      source_.hashCode;

  factory Evidence.fromJson(Map<String, dynamic> json) =>
      _$EvidenceFromJson(json);

  Map<String, dynamic> toJson() => _$EvidenceToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
