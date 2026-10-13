//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:myungli_diary/core/api/gen/model/city.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'city_list.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CityList {
  /// Returns a new [CityList] instance.
  CityList({required this.dataVersion, required this.items});

  @JsonKey(name: r'dataVersion', required: true, includeIfNull: false)
  final String dataVersion;

  @JsonKey(name: r'items', required: true, includeIfNull: false)
  final List<City> items;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CityList &&
          other.dataVersion == dataVersion &&
          other.items == items;

  @override
  int get hashCode => dataVersion.hashCode + items.hashCode;

  factory CityList.fromJson(Map<String, dynamic> json) =>
      _$CityListFromJson(json);

  Map<String, dynamic> toJson() => _$CityListToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
