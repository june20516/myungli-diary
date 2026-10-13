// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'preview_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$PreviewRequestCWProxy {
  PreviewRequest installationId(String installationId);

  PreviewRequest currentTimezone(String currentTimezone);

  PreviewRequest birth(Birth birth);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `PreviewRequest(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// PreviewRequest(...).copyWith(id: 12, name: "My name")
  /// ```
  PreviewRequest call({
    String installationId,
    String currentTimezone,
    Birth birth,
  });
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfPreviewRequest.copyWith(...)` or call `instanceOfPreviewRequest.copyWith.fieldName(value)` for a single field.
class _$PreviewRequestCWProxyImpl implements _$PreviewRequestCWProxy {
  const _$PreviewRequestCWProxyImpl(this._value);

  final PreviewRequest _value;

  @override
  PreviewRequest installationId(String installationId) =>
      call(installationId: installationId);

  @override
  PreviewRequest currentTimezone(String currentTimezone) =>
      call(currentTimezone: currentTimezone);

  @override
  PreviewRequest birth(Birth birth) => call(birth: birth);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `PreviewRequest(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// PreviewRequest(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  PreviewRequest call({
    Object? installationId = const $CopyWithPlaceholder(),
    Object? currentTimezone = const $CopyWithPlaceholder(),
    Object? birth = const $CopyWithPlaceholder(),
  }) {
    return PreviewRequest(
      installationId:
          installationId == const $CopyWithPlaceholder() ||
              installationId == null
          ? _value.installationId
          // ignore: cast_nullable_to_non_nullable
          : installationId as String,
      currentTimezone:
          currentTimezone == const $CopyWithPlaceholder() ||
              currentTimezone == null
          ? _value.currentTimezone
          // ignore: cast_nullable_to_non_nullable
          : currentTimezone as String,
      birth: birth == const $CopyWithPlaceholder() || birth == null
          ? _value.birth
          // ignore: cast_nullable_to_non_nullable
          : birth as Birth,
    );
  }
}

extension $PreviewRequestCopyWith on PreviewRequest {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfPreviewRequest.copyWith(...)` or `instanceOfPreviewRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$PreviewRequestCWProxy get copyWith => _$PreviewRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PreviewRequest _$PreviewRequestFromJson(Map<String, dynamic> json) =>
    $checkedCreate('PreviewRequest', json, ($checkedConvert) {
      $checkKeys(
        json,
        requiredKeys: const ['installationId', 'currentTimezone', 'birth'],
      );
      final val = PreviewRequest(
        installationId: $checkedConvert('installationId', (v) => v as String),
        currentTimezone: $checkedConvert('currentTimezone', (v) => v as String),
        birth: $checkedConvert(
          'birth',
          (v) => Birth.fromJson(v as Map<String, dynamic>),
        ),
      );
      return val;
    });

Map<String, dynamic> _$PreviewRequestToJson(PreviewRequest instance) =>
    <String, dynamic>{
      'installationId': instance.installationId,
      'currentTimezone': instance.currentTimezone,
      'birth': instance.birth.toJson(),
    };
