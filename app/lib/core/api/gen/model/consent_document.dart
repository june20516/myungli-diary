//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'consent_document.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ConsentDocument {
  /// Returns a new [ConsentDocument] instance.
  ConsentDocument({required this.document, required this.version});

  @JsonKey(name: r'document', required: true, includeIfNull: false)
  final ConsentDocumentDocumentEnum document;

  @JsonKey(name: r'version', required: true, includeIfNull: false)
  final String version;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConsentDocument &&
          other.document == document &&
          other.version == version;

  @override
  int get hashCode => document.hashCode + version.hashCode;

  factory ConsentDocument.fromJson(Map<String, dynamic> json) =>
      _$ConsentDocumentFromJson(json);

  Map<String, dynamic> toJson() => _$ConsentDocumentToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum ConsentDocumentDocumentEnum {
  @JsonValue(r'terms')
  terms(r'terms'),
  @JsonValue(r'privacy')
  privacy(r'privacy');

  const ConsentDocumentDocumentEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
