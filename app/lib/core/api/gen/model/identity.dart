//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:myungli_diary/core/api/gen/model/login_provider.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'identity.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class Identity {
  /// Returns a new [Identity] instance.
  Identity({required this.provider, required this.linkedAt});

  @JsonKey(
    name: r'provider',
    required: true,
    includeIfNull: false,
    unknownEnumValue: LoginProvider.unknownDefaultOpenApi,
  )
  final LoginProvider provider;

  @JsonKey(name: r'linkedAt', required: true, includeIfNull: false)
  final DateTime linkedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Identity &&
          other.provider == provider &&
          other.linkedAt == linkedAt;

  @override
  int get hashCode => provider.hashCode + linkedAt.hashCode;

  factory Identity.fromJson(Map<String, dynamic> json) =>
      _$IdentityFromJson(json);

  Map<String, dynamic> toJson() => _$IdentityToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
