// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_patch.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ProfilePatchCWProxy {
  ProfilePatch honorific(String? honorific);

  ProfilePatch language(Language? language);

  ProfilePatch currentTimezone(String? currentTimezone);

  ProfilePatch birth(Birth? birth);

  ProfilePatch notification(NotificationSetting? notification);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `ProfilePatch(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// ProfilePatch(...).copyWith(id: 12, name: "My name")
  /// ```
  ProfilePatch call({
    String? honorific,
    Language? language,
    String? currentTimezone,
    Birth? birth,
    NotificationSetting? notification,
  });
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfProfilePatch.copyWith(...)` or call `instanceOfProfilePatch.copyWith.fieldName(value)` for a single field.
class _$ProfilePatchCWProxyImpl implements _$ProfilePatchCWProxy {
  const _$ProfilePatchCWProxyImpl(this._value);

  final ProfilePatch _value;

  @override
  ProfilePatch honorific(String? honorific) => call(honorific: honorific);

  @override
  ProfilePatch language(Language? language) => call(language: language);

  @override
  ProfilePatch currentTimezone(String? currentTimezone) =>
      call(currentTimezone: currentTimezone);

  @override
  ProfilePatch birth(Birth? birth) => call(birth: birth);

  @override
  ProfilePatch notification(NotificationSetting? notification) =>
      call(notification: notification);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `ProfilePatch(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// ProfilePatch(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  ProfilePatch call({
    Object? honorific = const $CopyWithPlaceholder(),
    Object? language = const $CopyWithPlaceholder(),
    Object? currentTimezone = const $CopyWithPlaceholder(),
    Object? birth = const $CopyWithPlaceholder(),
    Object? notification = const $CopyWithPlaceholder(),
  }) {
    return ProfilePatch(
      honorific: honorific == const $CopyWithPlaceholder()
          ? _value.honorific
          // ignore: cast_nullable_to_non_nullable
          : honorific as String?,
      language: language == const $CopyWithPlaceholder()
          ? _value.language
          // ignore: cast_nullable_to_non_nullable
          : language as Language?,
      currentTimezone: currentTimezone == const $CopyWithPlaceholder()
          ? _value.currentTimezone
          // ignore: cast_nullable_to_non_nullable
          : currentTimezone as String?,
      birth: birth == const $CopyWithPlaceholder()
          ? _value.birth
          // ignore: cast_nullable_to_non_nullable
          : birth as Birth?,
      notification: notification == const $CopyWithPlaceholder()
          ? _value.notification
          // ignore: cast_nullable_to_non_nullable
          : notification as NotificationSetting?,
    );
  }
}

extension $ProfilePatchCopyWith on ProfilePatch {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfProfilePatch.copyWith(...)` or `instanceOfProfilePatch.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ProfilePatchCWProxy get copyWith => _$ProfilePatchCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ProfilePatch _$ProfilePatchFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ProfilePatch', json, ($checkedConvert) {
      final val = ProfilePatch(
        honorific: $checkedConvert('honorific', (v) => v as String?),
        language: $checkedConvert(
          'language',
          (v) => $enumDecodeNullable(
            _$LanguageEnumMap,
            v,
            unknownValue: Language.unknownDefaultOpenApi,
          ),
        ),
        currentTimezone: $checkedConvert(
          'currentTimezone',
          (v) => v as String?,
        ),
        birth: $checkedConvert(
          'birth',
          (v) => v == null ? null : Birth.fromJson(v as Map<String, dynamic>),
        ),
        notification: $checkedConvert(
          'notification',
          (v) => v == null
              ? null
              : NotificationSetting.fromJson(v as Map<String, dynamic>),
        ),
      );
      return val;
    });

Map<String, dynamic> _$ProfilePatchToJson(ProfilePatch instance) =>
    <String, dynamic>{
      'honorific': ?instance.honorific,
      'language': ?_$LanguageEnumMap[instance.language],
      'currentTimezone': ?instance.currentTimezone,
      'birth': ?instance.birth?.toJson(),
      'notification': ?instance.notification?.toJson(),
    };

const _$LanguageEnumMap = {
  Language.ko: 'ko',
  Language.en: 'en',
  Language.ja: 'ja',
  Language.unknownDefaultOpenApi: 'unknown_default_open_api',
};
