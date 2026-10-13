// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$DeviceCWProxy {
  Device id(String id);

  Device platform(DevicePlatform platform);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `Device(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// Device(...).copyWith(id: 12, name: "My name")
  /// ```
  Device call({String id, DevicePlatform platform});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfDevice.copyWith(...)` or call `instanceOfDevice.copyWith.fieldName(value)` for a single field.
class _$DeviceCWProxyImpl implements _$DeviceCWProxy {
  const _$DeviceCWProxyImpl(this._value);

  final Device _value;

  @override
  Device id(String id) => call(id: id);

  @override
  Device platform(DevicePlatform platform) => call(platform: platform);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `Device(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// Device(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  Device call({
    Object? id = const $CopyWithPlaceholder(),
    Object? platform = const $CopyWithPlaceholder(),
  }) {
    return Device(
      id: id == const $CopyWithPlaceholder() || id == null
          ? _value.id
          // ignore: cast_nullable_to_non_nullable
          : id as String,
      platform: platform == const $CopyWithPlaceholder() || platform == null
          ? _value.platform
          // ignore: cast_nullable_to_non_nullable
          : platform as DevicePlatform,
    );
  }
}

extension $DeviceCopyWith on Device {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfDevice.copyWith(...)` or `instanceOfDevice.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$DeviceCWProxy get copyWith => _$DeviceCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Device _$DeviceFromJson(Map<String, dynamic> json) =>
    $checkedCreate('Device', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['id', 'platform']);
      final val = Device(
        id: $checkedConvert('id', (v) => v as String),
        platform: $checkedConvert(
          'platform',
          (v) => $enumDecode(_$DevicePlatformEnumMap, v),
        ),
      );
      return val;
    });

Map<String, dynamic> _$DeviceToJson(Device instance) => <String, dynamic>{
  'id': instance.id,
  'platform': _$DevicePlatformEnumMap[instance.platform]!,
};

const _$DevicePlatformEnumMap = {
  DevicePlatform.ios: 'ios',
  DevicePlatform.android: 'android',
};
