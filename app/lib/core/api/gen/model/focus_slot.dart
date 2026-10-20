//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:myungli_diary/core/api/gen/model/branch.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'focus_slot.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class FocusSlot {
  /// Returns a new [FocusSlot] instance.
  FocusSlot({
    required this.branch,

    required this.start,

    required this.end,

    required this.huangdaoLucky,

    required this.reasons,
  });

  @JsonKey(name: r'branch', required: true, includeIfNull: false)
  final Branch branch;

  /// 프로필 현재 시간대의 offset으로 나타냅니다.
  @JsonKey(name: r'start', required: true, includeIfNull: false)
  final DateTime start;

  /// 프로필 현재 시간대의 offset으로 나타냅니다.
  @JsonKey(name: r'end', required: true, includeIfNull: false)
  final DateTime end;

  /// 황도길시
  @JsonKey(name: r'huangdaoLucky', required: true, includeIfNull: false)
  final bool huangdaoLucky;

  /// 가점 사유 식별자(glossary `focus_reason` 범주의 키)
  @JsonKey(
    name: r'reasons',
    required: true,
    includeIfNull: false,
    unknownEnumValue: FocusSlotReasonsEnum.unknownDefaultOpenApi,
  )
  final List<FocusSlotReasonsEnum> reasons;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FocusSlot &&
          other.branch == branch &&
          other.start == start &&
          other.end == end &&
          other.huangdaoLucky == huangdaoLucky &&
          other.reasons == reasons;

  @override
  int get hashCode =>
      branch.hashCode +
      start.hashCode +
      end.hashCode +
      huangdaoLucky.hashCode +
      reasons.hashCode;

  factory FocusSlot.fromJson(Map<String, dynamic> json) =>
      _$FocusSlotFromJson(json);

  Map<String, dynamic> toJson() => _$FocusSlotToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum FocusSlotReasonsEnum {
  @JsonValue(r'gwiin')
  gwiin(r'gwiin'),
  @JsonValue(r'yongsin')
  yongsin(r'yongsin'),
  @JsonValue(r'huisin')
  huisin(r'huisin'),
  @JsonValue(r'hap')
  hap(r'hap'),

  /// 계약에 아직 없는 값. 열린 enum이라 모르는 값은 응답 decode를 실패시키지 않고 이 값이 됩니다(결정 A66).
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const FocusSlotReasonsEnum(this.value);

  final String value;

  /// 계약이 정한 값이면 true, 모르는 값([unknownDefaultOpenApi])이면 false입니다.
  bool get isKnown => this != unknownDefaultOpenApi;

  @override
  String toString() => value;
}
