//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:myungli_diary/core/api/gen/model/rendered_text.dart';
import 'package:myungli_diary/core/api/gen/model/notice_code.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'notice.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class Notice {
  /// Returns a new [Notice] instance.
  Notice({required this.code, required this.text});

  @JsonKey(name: r'code', required: true, includeIfNull: false)
  final NoticeCode code;

  @JsonKey(name: r'text', required: true, includeIfNull: false)
  final RenderedText text;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Notice && other.code == code && other.text == text;

  @override
  int get hashCode => code.hashCode + text.hashCode;

  factory Notice.fromJson(Map<String, dynamic> json) => _$NoticeFromJson(json);

  Map<String, dynamic> toJson() => _$NoticeToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
