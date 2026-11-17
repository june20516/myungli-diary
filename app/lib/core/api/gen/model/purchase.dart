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

  /// 스토어 상품 식별자(App Store, Google Play 상품 id, 예 `ad_free_1m`)입니다. RevenueCat 내부 상품 id(`prod…`)가 아닙니다. 광고 제거권은 두 스토어와 RevenueCat Test Store가 같은 식별자 하나를 씁니다. 이름은 app이 자기 문구나 스토어 이름에서 찾습니다. server 상품 목록에 없는 상품(설정 실수)은 바꿀 값이 없어 RevenueCat 상품 id가 그대로 올 수 있습니다(1.13.3에서 분명히 함, server S166).
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
