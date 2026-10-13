//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'birth_time.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class BirthTime {
  /// Returns a new [BirthTime] instance.
  BirthTime({required this.status, this.value});

  @JsonKey(name: r'status', required: true, includeIfNull: false)
  final BirthTimeStatusEnum status;

  /// HH:MM
  @JsonKey(name: r'value', required: false, includeIfNull: false)
  final String? value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BirthTime && other.status == status && other.value == value;

  @override
  int get hashCode => status.hashCode + value.hashCode;

  factory BirthTime.fromJson(Map<String, dynamic> json) =>
      _$BirthTimeFromJson(json);

  Map<String, dynamic> toJson() => _$BirthTimeToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum BirthTimeStatusEnum {
  @JsonValue(r'known')
  known(r'known'),
  @JsonValue(r'unknown')
  unknown(r'unknown');

  const BirthTimeStatusEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
