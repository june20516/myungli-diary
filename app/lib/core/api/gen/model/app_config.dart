//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:myungli_diary/core/api/gen/model/legal_links.dart';
import 'package:myungli_diary/core/api/gen/model/minimum_version.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'app_config.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class AppConfig {
  /// Returns a new [AppConfig] instance.
  AppConfig({required this.minimumVersion, required this.legal});

  @JsonKey(name: r'minimumVersion', required: true, includeIfNull: false)
  final MinimumVersion minimumVersion;

  @JsonKey(name: r'legal', required: true, includeIfNull: false)
  final LegalLinks legal;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppConfig &&
          other.minimumVersion == minimumVersion &&
          other.legal == legal;

  @override
  int get hashCode => minimumVersion.hashCode + legal.hashCode;

  factory AppConfig.fromJson(Map<String, dynamic> json) =>
      _$AppConfigFromJson(json);

  Map<String, dynamic> toJson() => _$AppConfigToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
