// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_input.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ProfileInputCWProxy {
  ProfileInput honorific(String honorific);

  ProfileInput language(Language language);

  ProfileInput currentTimezone(String currentTimezone);

  ProfileInput birth(Birth birth);

  ProfileInput notification(NotificationSetting notification);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `ProfileInput(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// ProfileInput(...).copyWith(id: 12, name: "My name")
  /// ```
  ProfileInput call({
    String honorific,
    Language language,
    String currentTimezone,
    Birth birth,
    NotificationSetting notification,
  });
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfProfileInput.copyWith(...)` or call `instanceOfProfileInput.copyWith.fieldName(value)` for a single field.
class _$ProfileInputCWProxyImpl implements _$ProfileInputCWProxy {
  const _$ProfileInputCWProxyImpl(this._value);

  final ProfileInput _value;

  @override
  ProfileInput honorific(String honorific) => call(honorific: honorific);

  @override
  ProfileInput language(Language language) => call(language: language);

  @override
  ProfileInput currentTimezone(String currentTimezone) =>
      call(currentTimezone: currentTimezone);

  @override
  ProfileInput birth(Birth birth) => call(birth: birth);

  @override
  ProfileInput notification(NotificationSetting notification) =>
      call(notification: notification);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `ProfileInput(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// ProfileInput(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  ProfileInput call({
    Object? honorific = const $CopyWithPlaceholder(),
    Object? language = const $CopyWithPlaceholder(),
    Object? currentTimezone = const $CopyWithPlaceholder(),
    Object? birth = const $CopyWithPlaceholder(),
    Object? notification = const $CopyWithPlaceholder(),
  }) {
    return ProfileInput(
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

extension $ProfileInputCopyWith on ProfileInput {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfProfileInput.copyWith(...)` or `instanceOfProfileInput.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ProfileInputCWProxy get copyWith => _$ProfileInputCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ProfileInput _$ProfileInputFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ProfileInput', json, ($checkedConvert) {
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
      final val = ProfileInput(
        honorific: $checkedConvert('honorific', (v) => v as String),
        language: $checkedConvert(
          'language',
          (v) => $enumDecode(
            _$LanguageEnumMap,
            v,
            unknownValue: Language.unknownDefaultOpenApi,
          ),
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

Map<String, dynamic> _$ProfileInputToJson(ProfileInput instance) =>
    <String, dynamic>{
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
  Language.unknownDefaultOpenApi: 'unknown_default_open_api',
};
