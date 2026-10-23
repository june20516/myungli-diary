//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:myungli_diary/core/api/gen/model/purchase.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'purchase_list.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class PurchaseList {
  /// Returns a new [PurchaseList] instance.
  PurchaseList({required this.items});

  /// 최근 구매 먼저
  @JsonKey(name: r'items', required: true, includeIfNull: false)
  final List<Purchase> items;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is PurchaseList && other.items == items;

  @override
  int get hashCode => items.hashCode;

  factory PurchaseList.fromJson(Map<String, dynamic> json) =>
      _$PurchaseListFromJson(json);

  Map<String, dynamic> toJson() => _$PurchaseListToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
