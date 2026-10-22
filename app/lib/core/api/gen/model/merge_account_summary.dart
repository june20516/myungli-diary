//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:myungli_diary/core/api/gen/model/merge_saju.dart';
import 'package:myungli_diary/core/api/gen/model/login_provider.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'merge_account_summary.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class MergeAccountSummary {
  /// Returns a new [MergeAccountSummary] instance.
  MergeAccountSummary({
    this.honorific,

    required this.saju,

    required this.diaryCount,

    required this.providers,
  });

  /// 호칭. `saju.status`가 `saved`일 때만 있습니다.
  @JsonKey(name: r'honorific', required: false, includeIfNull: false)
  final String? honorific;

  @JsonKey(name: r'saju', required: true, includeIfNull: false)
  final MergeSaju saju;

  /// 살아 있는 일기 수. 그 계정이 없앨 계정이 되면 옮겨질 일기 수와 같습니다.
  // minimum: 0
  @JsonKey(name: r'diaryCount', required: true, includeIfNull: false)
  final int diaryCount;

  /// 연결된 제공자, 붙인 순서
  @JsonKey(
    name: r'providers',
    required: true,
    includeIfNull: false,
    unknownEnumValue: LoginProvider.unknownDefaultOpenApi,
  )
  final List<LoginProvider> providers;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MergeAccountSummary &&
          other.honorific == honorific &&
          other.saju == saju &&
          other.diaryCount == diaryCount &&
          other.providers == providers;

  @override
  int get hashCode =>
      honorific.hashCode +
      saju.hashCode +
      diaryCount.hashCode +
      providers.hashCode;

  factory MergeAccountSummary.fromJson(Map<String, dynamic> json) =>
      _$MergeAccountSummaryFromJson(json);

  Map<String, dynamic> toJson() => _$MergeAccountSummaryToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
