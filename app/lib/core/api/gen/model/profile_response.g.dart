// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ProfileResponseCWProxy {
  ProfileResponse profile(Profile profile);

  ProfileResponse warnings(List<FieldError> warnings);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `ProfileResponse(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// ProfileResponse(...).copyWith(id: 12, name: "My name")
  /// ```
  ProfileResponse call({Profile profile, List<FieldError> warnings});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfProfileResponse.copyWith(...)` or call `instanceOfProfileResponse.copyWith.fieldName(value)` for a single field.
class _$ProfileResponseCWProxyImpl implements _$ProfileResponseCWProxy {
  const _$ProfileResponseCWProxyImpl(this._value);

  final ProfileResponse _value;

  @override
  ProfileResponse profile(Profile profile) => call(profile: profile);

  @override
  ProfileResponse warnings(List<FieldError> warnings) =>
      call(warnings: warnings);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `ProfileResponse(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// ProfileResponse(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  ProfileResponse call({
    Object? profile = const $CopyWithPlaceholder(),
    Object? warnings = const $CopyWithPlaceholder(),
  }) {
    return ProfileResponse(
      profile: profile == const $CopyWithPlaceholder() || profile == null
          ? _value.profile
          // ignore: cast_nullable_to_non_nullable
          : profile as Profile,
      warnings: warnings == const $CopyWithPlaceholder() || warnings == null
          ? _value.warnings
          // ignore: cast_nullable_to_non_nullable
          : warnings as List<FieldError>,
    );
  }
}

extension $ProfileResponseCopyWith on ProfileResponse {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfProfileResponse.copyWith(...)` or `instanceOfProfileResponse.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ProfileResponseCWProxy get copyWith => _$ProfileResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ProfileResponse _$ProfileResponseFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ProfileResponse', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['profile', 'warnings']);
      final val = ProfileResponse(
        profile: $checkedConvert(
          'profile',
          (v) => Profile.fromJson(v as Map<String, dynamic>),
        ),
        warnings: $checkedConvert(
          'warnings',
          (v) => (v as List<dynamic>)
              .map((e) => FieldError.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
      );
      return val;
    });

Map<String, dynamic> _$ProfileResponseToJson(ProfileResponse instance) =>
    <String, dynamic>{
      'profile': instance.profile.toJson(),
      'warnings': instance.warnings.map((e) => e.toJson()).toList(),
    };
