//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:myungli_diary/core/api/gen/model/slot_text.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'fortune.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class Fortune {
  /// Returns a new [Fortune] instance.
  Fortune({required this.head, this.tag});

  @JsonKey(name: r'head', required: true, includeIfNull: false)
  final SlotText head;

  @JsonKey(name: r'tag', required: false, includeIfNull: false)
  final SlotText? tag;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Fortune && other.head == head && other.tag == tag;

  @override
  int get hashCode => head.hashCode + tag.hashCode;

  factory Fortune.fromJson(Map<String, dynamic> json) =>
      _$FortuneFromJson(json);

  Map<String, dynamic> toJson() => _$FortuneToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
