//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'birth_place.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class BirthPlace {
  /// Returns a new [BirthPlace] instance.
  BirthPlace({required this.status, this.cityId});

  @JsonKey(name: r'status', required: true, includeIfNull: false)
  final BirthPlaceStatusEnum status;

  /// `City.id`
  @JsonKey(name: r'cityId', required: false, includeIfNull: false)
  final String? cityId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BirthPlace && other.status == status && other.cityId == cityId;

  @override
  int get hashCode => status.hashCode + cityId.hashCode;

  factory BirthPlace.fromJson(Map<String, dynamic> json) =>
      _$BirthPlaceFromJson(json);

  Map<String, dynamic> toJson() => _$BirthPlaceToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum BirthPlaceStatusEnum {
  @JsonValue(r'not_asked')
  notAsked(r'not_asked'),
  @JsonValue(r'skipped')
  skipped(r'skipped'),
  @JsonValue(r'city')
  city(r'city');

  const BirthPlaceStatusEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
