//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:myungli_diary/core/api/gen/model/purchase_status.dart';
import 'package:myungli_diary/core/api/gen/model/purchase_period.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'purchase.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class Purchase {
  /// Returns a new [Purchase] instance.
  Purchase({
    required this.productId,

    required this.purchasedAt,

    required this.status,

    this.period,
  });

  /// 상품 id. 이름은 app이 자기 문구나 스토어 이름에서 찾습니다.
  @JsonKey(name: r'productId', required: true, includeIfNull: false)
  final String productId;

  @JsonKey(name: r'purchasedAt', required: true, includeIfNull: false)
  final DateTime purchasedAt;

  @JsonKey(
    name: r'status',
    required: true,
    includeIfNull: false,
    unknownEnumValue: PurchaseStatus.unknownDefaultOpenApi,
  )
  final PurchaseStatus status;

  @JsonKey(name: r'period', required: false, includeIfNull: false)
  final PurchasePeriod? period;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Purchase &&
          other.productId == productId &&
          other.purchasedAt == purchasedAt &&
          other.status == status &&
          other.period == period;

  @override
  int get hashCode =>
      productId.hashCode +
      purchasedAt.hashCode +
      status.hashCode +
      period.hashCode;

  factory Purchase.fromJson(Map<String, dynamic> json) =>
      _$PurchaseFromJson(json);

  Map<String, dynamic> toJson() => _$PurchaseToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
