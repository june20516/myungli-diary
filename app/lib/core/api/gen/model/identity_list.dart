//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:myungli_diary/core/api/gen/model/identity.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'identity_list.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class IdentityList {
  /// Returns a new [IdentityList] instance.
  IdentityList({required this.items});

  /// 붙인 순서
  @JsonKey(name: r'items', required: true, includeIfNull: false)
  final List<Identity> items;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is IdentityList && other.items == items;

  @override
  int get hashCode => items.hashCode;

  factory IdentityList.fromJson(Map<String, dynamic> json) =>
      _$IdentityListFromJson(json);

  Map<String, dynamic> toJson() => _$IdentityListToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
