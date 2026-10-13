//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:myungli_diary/core/api/gen/model/diary_summary.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'diary_list.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class DiaryList {
  /// Returns a new [DiaryList] instance.
  DiaryList({required this.items, this.nextCursor});

  @JsonKey(name: r'items', required: true, includeIfNull: false)
  final List<DiarySummary> items;

  @JsonKey(name: r'nextCursor', required: false, includeIfNull: false)
  final String? nextCursor;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiaryList &&
          other.items == items &&
          other.nextCursor == nextCursor;

  @override
  int get hashCode => items.hashCode + nextCursor.hashCode;

  factory DiaryList.fromJson(Map<String, dynamic> json) =>
      _$DiaryListFromJson(json);

  Map<String, dynamic> toJson() => _$DiaryListToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
