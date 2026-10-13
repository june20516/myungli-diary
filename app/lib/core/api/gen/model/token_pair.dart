//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'token_pair.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class TokenPair {
  /// Returns a new [TokenPair] instance.
  TokenPair({
    required this.accessToken,

    required this.accessTokenExpiresAt,

    required this.refreshToken,

    required this.refreshTokenExpiresAt,
  });

  @JsonKey(name: r'accessToken', required: true, includeIfNull: false)
  final String accessToken;

  @JsonKey(name: r'accessTokenExpiresAt', required: true, includeIfNull: false)
  final DateTime accessTokenExpiresAt;

  @JsonKey(name: r'refreshToken', required: true, includeIfNull: false)
  final String refreshToken;

  @JsonKey(name: r'refreshTokenExpiresAt', required: true, includeIfNull: false)
  final DateTime refreshTokenExpiresAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TokenPair &&
          other.accessToken == accessToken &&
          other.accessTokenExpiresAt == accessTokenExpiresAt &&
          other.refreshToken == refreshToken &&
          other.refreshTokenExpiresAt == refreshTokenExpiresAt;

  @override
  int get hashCode =>
      accessToken.hashCode +
      accessTokenExpiresAt.hashCode +
      refreshToken.hashCode +
      refreshTokenExpiresAt.hashCode;

  factory TokenPair.fromJson(Map<String, dynamic> json) =>
      _$TokenPairFromJson(json);

  Map<String, dynamic> toJson() => _$TokenPairToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
