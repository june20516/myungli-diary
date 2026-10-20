//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:myungli_diary/core/api/gen/model/shinsal_kind.dart';
import 'package:myungli_diary/core/api/gen/model/position.dart';
import 'package:myungli_diary/core/api/gen/model/rendered_text.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'personal_reading.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class PersonalReading {
  /// Returns a new [PersonalReading] instance.
  PersonalReading({
    required this.kind,

    this.position,

    this.index,

    this.shinsal,

    required this.text,
  });

  @JsonKey(name: r'kind', required: true, includeIfNull: false)
  final PersonalReadingKindEnum kind;

  @JsonKey(name: r'position', required: false, includeIfNull: false)
  final Position? position;

  // minimum: 0
  @JsonKey(name: r'index', required: false, includeIfNull: false)
  final int? index;

  @JsonKey(name: r'shinsal', required: false, includeIfNull: false)
  final ShinsalKind? shinsal;

  @JsonKey(name: r'text', required: true, includeIfNull: false)
  final RenderedText text;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PersonalReading &&
          other.kind == kind &&
          other.position == position &&
          other.index == index &&
          other.shinsal == shinsal &&
          other.text == text;

  @override
  int get hashCode =>
      kind.hashCode +
      position.hashCode +
      index.hashCode +
      shinsal.hashCode +
      text.hashCode;

  factory PersonalReading.fromJson(Map<String, dynamic> json) =>
      _$PersonalReadingFromJson(json);

  Map<String, dynamic> toJson() => _$PersonalReadingToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum PersonalReadingKindEnum {
  @JsonValue(r'day_master')
  PersonalReadingKindDayMaster(r'day_master'),
  @JsonValue(r'ten_god')
  PersonalReadingKindTenGod(r'ten_god'),
  @JsonValue(r'hidden_ten_god')
  PersonalReadingKindHiddenTenGod(r'hidden_ten_god'),
  @JsonValue(r'twelve_stage')
  PersonalReadingKindTwelveStage(r'twelve_stage'),
  @JsonValue(r'shinsal')
  PersonalReadingKindShinsal(r'shinsal'),
  @JsonValue(r'daeun_stem_ten_god')
  PersonalReadingKindDaeunStemTenGod(r'daeun_stem_ten_god'),
  @JsonValue(r'daeun_branch_ten_god')
  PersonalReadingKindDaeunBranchTenGod(r'daeun_branch_ten_god'),
  @JsonValue(r'daeun_twelve_stage')
  PersonalReadingKindDaeunTwelveStage(r'daeun_twelve_stage'),
  @JsonValue(r'seun_ten_god')
  PersonalReadingKindSeunTenGod(r'seun_ten_god');

  const PersonalReadingKindEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
