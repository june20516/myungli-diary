//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:myungli_diary/core/api/gen/model/evidence_access.dart';
import 'package:myungli_diary/core/api/gen/model/fortune.dart';
import 'package:myungli_diary/core/api/gen/model/notice.dart';
import 'package:myungli_diary/core/api/gen/model/day_kind.dart';
import 'package:myungli_diary/core/api/gen/model/tag.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'preview.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class Preview {
  /// Returns a new [Preview] instance.
  Preview({
    required this.date,

    required this.evidenceAccess,

    required this.dayKind,

    required this.fortune,

    required this.featuredTags,

    required this.notices,
  });

  @JsonKey(name: r'date', required: true, includeIfNull: false)
  final String date;

  @JsonKey(name: r'evidenceAccess', required: true, includeIfNull: false)
  final EvidenceAccess evidenceAccess;

  @JsonKey(name: r'dayKind', required: true, includeIfNull: false)
  final DayKind dayKind;

  @JsonKey(name: r'fortune', required: true, includeIfNull: false)
  final Fortune fortune;

  @JsonKey(name: r'featuredTags', required: true, includeIfNull: false)
  final List<Tag> featuredTags;

  @JsonKey(name: r'notices', required: true, includeIfNull: false)
  final List<Notice> notices;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Preview &&
          other.date == date &&
          other.evidenceAccess == evidenceAccess &&
          other.dayKind == dayKind &&
          other.fortune == fortune &&
          other.featuredTags == featuredTags &&
          other.notices == notices;

  @override
  int get hashCode =>
      date.hashCode +
      evidenceAccess.hashCode +
      dayKind.hashCode +
      fortune.hashCode +
      featuredTags.hashCode +
      notices.hashCode;

  factory Preview.fromJson(Map<String, dynamic> json) =>
      _$PreviewFromJson(json);

  Map<String, dynamic> toJson() => _$PreviewToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
