//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:myungli_diary/core/api/gen/model/consent_document.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'consent_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ConsentRequest {
  /// Returns a new [ConsentRequest] instance.
  ConsentRequest({required this.documents});

  @JsonKey(name: r'documents', required: true, includeIfNull: false)
  final List<ConsentDocument> documents;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConsentRequest && other.documents == documents;

  @override
  int get hashCode => documents.hashCode;

  factory ConsentRequest.fromJson(Map<String, dynamic> json) =>
      _$ConsentRequestFromJson(json);

  Map<String, dynamic> toJson() => _$ConsentRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
