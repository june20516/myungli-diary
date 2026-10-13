// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_input.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$DeviceInputCWProxy {
  DeviceInput fcmToken(String fcmToken);

  DeviceInput platform(DevicePlatform platform);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `DeviceInput(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// DeviceInput(...).copyWith(id: 12, name: "My name")
  /// ```
  DeviceInput call({String fcmToken, DevicePlatform platform});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfDeviceInput.copyWith(...)` or call `instanceOfDeviceInput.copyWith.fieldName(value)` for a single field.
class _$DeviceInputCWProxyImpl implements _$DeviceInputCWProxy {
  const _$DeviceInputCWProxyImpl(this._value);

  final DeviceInput _value;

  @override
  DeviceInput fcmToken(String fcmToken) => call(fcmToken: fcmToken);

  @override
  DeviceInput platform(DevicePlatform platform) => call(platform: platform);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `DeviceInput(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// DeviceInput(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  DeviceInput call({
    Object? fcmToken = const $CopyWithPlaceholder(),
    Object? platform = const $CopyWithPlaceholder(),
  }) {
    return DeviceInput(
      fcmToken: fcmToken == const $CopyWithPlaceholder() || fcmToken == null
          ? _value.fcmToken
          // ignore: cast_nullable_to_non_nullable
          : fcmToken as String,
      platform: platform == const $CopyWithPlaceholder() || platform == null
          ? _value.platform
          // ignore: cast_nullable_to_non_nullable
          : platform as DevicePlatform,
    );
  }
}

extension $DeviceInputCopyWith on DeviceInput {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfDeviceInput.copyWith(...)` or `instanceOfDeviceInput.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$DeviceInputCWProxy get copyWith => _$DeviceInputCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DeviceInput _$DeviceInputFromJson(Map<String, dynamic> json) =>
    $checkedCreate('DeviceInput', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['fcmToken', 'platform']);
      final val = DeviceInput(
        fcmToken: $checkedConvert('fcmToken', (v) => v as String),
        platform: $checkedConvert(
          'platform',
          (v) => $enumDecode(_$DevicePlatformEnumMap, v),
        ),
      );
      return val;
    });

Map<String, dynamic> _$DeviceInputToJson(DeviceInput instance) =>
    <String, dynamic>{
      'fcmToken': instance.fcmToken,
      'platform': _$DevicePlatformEnumMap[instance.platform]!,
    };

const _$DevicePlatformEnumMap = {
  DevicePlatform.ios: 'ios',
  DevicePlatform.android: 'android',
};
