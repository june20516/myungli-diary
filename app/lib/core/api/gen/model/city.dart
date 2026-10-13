//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'city.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class City {
  /// Returns a new [City] instance.
  City({
    required this.id,

    required this.name,

    required this.country,

    required this.timezone,
  });

  /// GeoNames id
  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final String id;

  @JsonKey(name: r'name', required: true, includeIfNull: false)
  final String name;

  /// ISO 3166-1 alpha-2
  @JsonKey(name: r'country', required: true, includeIfNull: false)
  final String country;

  /// IANA 이름
  @JsonKey(name: r'timezone', required: true, includeIfNull: false)
  final String timezone;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is City &&
          other.id == id &&
          other.name == name &&
          other.country == country &&
          other.timezone == timezone;

  @override
  int get hashCode =>
      id.hashCode + name.hashCode + country.hashCode + timezone.hashCode;

  factory City.fromJson(Map<String, dynamic> json) => _$CityFromJson(json);

  Map<String, dynamic> toJson() => _$CityToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
