// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ProfileCWProxy {
  Profile honorific(String honorific);

  Profile language(Language language);

  Profile currentTimezone(String currentTimezone);

  Profile birth(Birth birth);

  Profile notification(NotificationSetting notification);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `Profile(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// Profile(...).copyWith(id: 12, name: "My name")
  /// ```
  Profile call({
    String honorific,
    Language language,
    String currentTimezone,
    Birth birth,
    NotificationSetting notification,
  });
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfProfile.copyWith(...)` or call `instanceOfProfile.copyWith.fieldName(value)` for a single field.
class _$ProfileCWProxyImpl implements _$ProfileCWProxy {
  const _$ProfileCWProxyImpl(this._value);

  final Profile _value;

  @override
  Profile honorific(String honorific) => call(honorific: honorific);

  @override
  Profile language(Language language) => call(language: language);

  @override
  Profile currentTimezone(String currentTimezone) =>
      call(currentTimezone: currentTimezone);

  @override
  Profile birth(Birth birth) => call(birth: birth);

  @override
  Profile notification(NotificationSetting notification) =>
      call(notification: notification);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `Profile(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// Profile(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  Profile call({
    Object? honorific = const $CopyWithPlaceholder(),
    Object? language = const $CopyWithPlaceholder(),
    Object? currentTimezone = const $CopyWithPlaceholder(),
    Object? birth = const $CopyWithPlaceholder(),
    Object? notification = const $CopyWithPlaceholder(),
  }) {
    return Profile(
      honorific: honorific == const $CopyWithPlaceholder() || honorific == null
          ? _value.honorific
          // ignore: cast_nullable_to_non_nullable
          : honorific as String,
      language: language == const $CopyWithPlaceholder() || language == null
          ? _value.language
          // ignore: cast_nullable_to_non_nullable
          : language as Language,
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
      notification:
          notification == const $CopyWithPlaceholder() || notification == null
          ? _value.notification
          // ignore: cast_nullable_to_non_nullable
          : notification as NotificationSetting,
    );
  }
}

extension $ProfileCopyWith on Profile {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfProfile.copyWith(...)` or `instanceOfProfile.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ProfileCWProxy get copyWith => _$ProfileCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Profile _$ProfileFromJson(Map<String, dynamic> json) =>
    $checkedCreate('Profile', json, ($checkedConvert) {
      $checkKeys(
        json,
        requiredKeys: const [
          'honorific',
          'language',
          'currentTimezone',
          'birth',
          'notification',
        ],
      );
      final val = Profile(
        honorific: $checkedConvert('honorific', (v) => v as String),
        language: $checkedConvert(
          'language',
          (v) => $enumDecode(_$LanguageEnumMap, v),
        ),
        currentTimezone: $checkedConvert('currentTimezone', (v) => v as String),
        birth: $checkedConvert(
          'birth',
          (v) => Birth.fromJson(v as Map<String, dynamic>),
        ),
        notification: $checkedConvert(
          'notification',
          (v) => NotificationSetting.fromJson(v as Map<String, dynamic>),
        ),
      );
      return val;
    });

Map<String, dynamic> _$ProfileToJson(Profile instance) => <String, dynamic>{
  'honorific': instance.honorific,
  'language': _$LanguageEnumMap[instance.language]!,
  'currentTimezone': instance.currentTimezone,
  'birth': instance.birth.toJson(),
  'notification': instance.notification.toJson(),
};

const _$LanguageEnumMap = {
  Language.ko: 'ko',
  Language.en: 'en',
  Language.ja: 'ja',
};
