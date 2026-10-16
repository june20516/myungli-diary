//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'lunar_conversion.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class LunarConversion {
  /// Returns a new [LunarConversion] instance.
  LunarConversion({required this.solarDate, required this.monthHasLeap});

  /// 변환한 양력 날짜
  @JsonKey(name: r'solarDate', required: true, includeIfNull: false)
  final String solarDate;

  /// 그해 그 음력 달에 윤달이 있는지
  @JsonKey(name: r'monthHasLeap', required: true, includeIfNull: false)
  final bool monthHasLeap;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LunarConversion &&
          other.solarDate == solarDate &&
          other.monthHasLeap == monthHasLeap;

  @override
  int get hashCode => solarDate.hashCode + monthHasLeap.hashCode;

  factory LunarConversion.fromJson(Map<String, dynamic> json) =>
      _$LunarConversionFromJson(json);

  Map<String, dynamic> toJson() => _$LunarConversionToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
