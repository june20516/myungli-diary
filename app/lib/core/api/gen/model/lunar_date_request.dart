//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:myungli_diary/core/api/gen/model/lunar_or_solar_date.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'lunar_date_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class LunarDateRequest {
  /// Returns a new [LunarDateRequest] instance.
  LunarDateRequest({
    required this.installationId,

    required this.date,

    required this.isLeapMonth,
  });

  /// 앱 설치마다 만든 무작위 값
  @JsonKey(name: r'installationId', required: true, includeIfNull: false)
  final String installationId;

  @JsonKey(name: r'date', required: true, includeIfNull: false)
  final LunarOrSolarDate date;

  /// 윤달이면 true입니다. 그해 그 달에 윤달이 없으면 422 `date.invalid`입니다.
  @JsonKey(name: r'isLeapMonth', required: true, includeIfNull: false)
  final bool isLeapMonth;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LunarDateRequest &&
          other.installationId == installationId &&
          other.date == date &&
          other.isLeapMonth == isLeapMonth;

  @override
  int get hashCode =>
      installationId.hashCode + date.hashCode + isLeapMonth.hashCode;

  factory LunarDateRequest.fromJson(Map<String, dynamic> json) =>
      _$LunarDateRequestFromJson(json);

  Map<String, dynamic> toJson() => _$LunarDateRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
