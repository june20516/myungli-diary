//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'deletion_scheduled.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class DeletionScheduled {
  /// Returns a new [DeletionScheduled] instance.
  DeletionScheduled({required this.deletionScheduledAt});

  @JsonKey(name: r'deletionScheduledAt', required: true, includeIfNull: false)
  final DateTime deletionScheduledAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeletionScheduled &&
          other.deletionScheduledAt == deletionScheduledAt;

  @override
  int get hashCode => deletionScheduledAt.hashCode;

  factory DeletionScheduled.fromJson(Map<String, dynamic> json) =>
      _$DeletionScheduledFromJson(json);

  Map<String, dynamic> toJson() => _$DeletionScheduledToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
