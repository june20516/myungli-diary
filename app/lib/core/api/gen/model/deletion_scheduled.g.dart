// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'deletion_scheduled.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$DeletionScheduledCWProxy {
  DeletionScheduled deletionScheduledAt(DateTime deletionScheduledAt);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `DeletionScheduled(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// DeletionScheduled(...).copyWith(id: 12, name: "My name")
  /// ```
  DeletionScheduled call({DateTime deletionScheduledAt});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfDeletionScheduled.copyWith(...)` or call `instanceOfDeletionScheduled.copyWith.fieldName(value)` for a single field.
class _$DeletionScheduledCWProxyImpl implements _$DeletionScheduledCWProxy {
  const _$DeletionScheduledCWProxyImpl(this._value);

  final DeletionScheduled _value;

  @override
  DeletionScheduled deletionScheduledAt(DateTime deletionScheduledAt) =>
      call(deletionScheduledAt: deletionScheduledAt);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `DeletionScheduled(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// DeletionScheduled(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  DeletionScheduled call({
    Object? deletionScheduledAt = const $CopyWithPlaceholder(),
  }) {
    return DeletionScheduled(
      deletionScheduledAt:
          deletionScheduledAt == const $CopyWithPlaceholder() ||
              deletionScheduledAt == null
          ? _value.deletionScheduledAt
          // ignore: cast_nullable_to_non_nullable
          : deletionScheduledAt as DateTime,
    );
  }
}

extension $DeletionScheduledCopyWith on DeletionScheduled {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfDeletionScheduled.copyWith(...)` or `instanceOfDeletionScheduled.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$DeletionScheduledCWProxy get copyWith =>
      _$DeletionScheduledCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DeletionScheduled _$DeletionScheduledFromJson(Map<String, dynamic> json) =>
    $checkedCreate('DeletionScheduled', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['deletionScheduledAt']);
      final val = DeletionScheduled(
        deletionScheduledAt: $checkedConvert(
          'deletionScheduledAt',
          (v) => DateTime.parse(v as String),
        ),
      );
      return val;
    });

Map<String, dynamic> _$DeletionScheduledToJson(DeletionScheduled instance) =>
    <String, dynamic>{
      'deletionScheduledAt': instance.deletionScheduledAt.toIso8601String(),
    };
