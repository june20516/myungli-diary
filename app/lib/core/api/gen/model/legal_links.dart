//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'legal_links.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class LegalLinks {
  /// Returns a new [LegalLinks] instance.
  LegalLinks({required this.terms, required this.privacy});

  /// 이용약관 주소(예 `https://<서비스 도메인>/legal/terms`)
  @JsonKey(name: r'terms', required: true, includeIfNull: false)
  final String terms;

  /// 개인정보 처리방침 주소(예 `https://<서비스 도메인>/legal/privacy`)
  @JsonKey(name: r'privacy', required: true, includeIfNull: false)
  final String privacy;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LegalLinks && other.terms == terms && other.privacy == privacy;

  @override
  int get hashCode => terms.hashCode + privacy.hashCode;

  factory LegalLinks.fromJson(Map<String, dynamic> json) =>
      _$LegalLinksFromJson(json);

  Map<String, dynamic> toJson() => _$LegalLinksToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
