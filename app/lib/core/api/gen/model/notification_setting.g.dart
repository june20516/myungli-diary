// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_setting.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$NotificationSettingCWProxy {
  NotificationSetting status(NotificationSettingStatusEnum status);

  NotificationSetting time(String? time);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `NotificationSetting(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// NotificationSetting(...).copyWith(id: 12, name: "My name")
  /// ```
  NotificationSetting call({
    NotificationSettingStatusEnum status,
    String? time,
  });
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfNotificationSetting.copyWith(...)` or call `instanceOfNotificationSetting.copyWith.fieldName(value)` for a single field.
class _$NotificationSettingCWProxyImpl implements _$NotificationSettingCWProxy {
  const _$NotificationSettingCWProxyImpl(this._value);

  final NotificationSetting _value;

  @override
  NotificationSetting status(NotificationSettingStatusEnum status) =>
      call(status: status);

  @override
  NotificationSetting time(String? time) => call(time: time);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `NotificationSetting(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// NotificationSetting(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  NotificationSetting call({
    Object? status = const $CopyWithPlaceholder(),
    Object? time = const $CopyWithPlaceholder(),
  }) {
    return NotificationSetting(
      status: status == const $CopyWithPlaceholder() || status == null
          ? _value.status
          // ignore: cast_nullable_to_non_nullable
          : status as NotificationSettingStatusEnum,
      time: time == const $CopyWithPlaceholder()
          ? _value.time
          // ignore: cast_nullable_to_non_nullable
          : time as String?,
    );
  }
}

extension $NotificationSettingCopyWith on NotificationSetting {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfNotificationSetting.copyWith(...)` or `instanceOfNotificationSetting.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$NotificationSettingCWProxy get copyWith =>
      _$NotificationSettingCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

NotificationSetting _$NotificationSettingFromJson(Map<String, dynamic> json) =>
    $checkedCreate('NotificationSetting', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['status']);
      final val = NotificationSetting(
        status: $checkedConvert(
          'status',
          (v) => $enumDecode(_$NotificationSettingStatusEnumEnumMap, v),
        ),
        time: $checkedConvert('time', (v) => v as String?),
      );
      return val;
    });

Map<String, dynamic> _$NotificationSettingToJson(
  NotificationSetting instance,
) => <String, dynamic>{
  'status': _$NotificationSettingStatusEnumEnumMap[instance.status]!,
  'time': ?instance.time,
};

const _$NotificationSettingStatusEnumEnumMap = {
  NotificationSettingStatusEnum.notAsked: 'not_asked',
  NotificationSettingStatusEnum.enabled: 'enabled',
  NotificationSettingStatusEnum.disabled: 'disabled',
};
