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

    required this.countryName,

    this.regionName,

    required this.timezone,

    required this.longitude,
  });

  /// GeoNames id
  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final String id;

  /// 요청 언어의 이름
  @JsonKey(name: r'name', required: true, includeIfNull: false)
  final String name;

  /// ISO 3166-1 alpha-2
  @JsonKey(name: r'country', required: true, includeIfNull: false)
  final String country;

  /// 요청 언어의 나라 이름
  @JsonKey(name: r'countryName', required: true, includeIfNull: false)
  final String countryName;

  /// 1차 행정구역 이름. GeoNames에 없으면 생략합니다.
  @JsonKey(name: r'regionName', required: false, includeIfNull: false)
  final String? regionName;

  /// IANA 이름
  @JsonKey(name: r'timezone', required: true, includeIfNull: false)
  final String timezone;

  /// 경도(도 단위 소수, 동경 양수·서경 음수). 출생 시각의 경도 보정에 쓰는 값입니다.
  // minimum: -180
  // maximum: 180
  @JsonKey(name: r'longitude', required: true, includeIfNull: false)
  final num longitude;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is City &&
          other.id == id &&
          other.name == name &&
          other.country == country &&
          other.countryName == countryName &&
          other.regionName == regionName &&
          other.timezone == timezone &&
          other.longitude == longitude;

  @override
  int get hashCode =>
      id.hashCode +
      name.hashCode +
      country.hashCode +
      countryName.hashCode +
      regionName.hashCode +
      timezone.hashCode +
      longitude.hashCode;

  factory City.fromJson(Map<String, dynamic> json) => _$CityFromJson(json);

  Map<String, dynamic> toJson() => _$CityToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
