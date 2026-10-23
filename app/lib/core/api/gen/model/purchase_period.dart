//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'purchase_period.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class PurchasePeriod {
  /// Returns a new [PurchasePeriod] instance.
  PurchasePeriod({required this.startsAt, required this.endsAt});

  @JsonKey(name: r'startsAt', required: true, includeIfNull: false)
  final DateTime startsAt;

  @JsonKey(name: r'endsAt', required: true, includeIfNull: false)
  final DateTime endsAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PurchasePeriod &&
          other.startsAt == startsAt &&
          other.endsAt == endsAt;

  @override
  int get hashCode => startsAt.hashCode + endsAt.hashCode;

  factory PurchasePeriod.fromJson(Map<String, dynamic> json) =>
      _$PurchasePeriodFromJson(json);

  Map<String, dynamic> toJson() => _$PurchasePeriodToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
