// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'inquiry_input.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$InquiryInputCWProxy {
  InquiryInput message(String message);

  InquiryInput replyEmail(String replyEmail);

  InquiryInput appVersion(String appVersion);

  InquiryInput os(String os);

  InquiryInput deviceModel(String deviceModel);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `InquiryInput(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// InquiryInput(...).copyWith(id: 12, name: "My name")
  /// ```
  InquiryInput call({
    String message,
    String replyEmail,
    String appVersion,
    String os,
    String deviceModel,
  });
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfInquiryInput.copyWith(...)` or call `instanceOfInquiryInput.copyWith.fieldName(value)` for a single field.
class _$InquiryInputCWProxyImpl implements _$InquiryInputCWProxy {
  const _$InquiryInputCWProxyImpl(this._value);

  final InquiryInput _value;

  @override
  InquiryInput message(String message) => call(message: message);

  @override
  InquiryInput replyEmail(String replyEmail) => call(replyEmail: replyEmail);

  @override
  InquiryInput appVersion(String appVersion) => call(appVersion: appVersion);

  @override
  InquiryInput os(String os) => call(os: os);

  @override
  InquiryInput deviceModel(String deviceModel) =>
      call(deviceModel: deviceModel);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `InquiryInput(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// InquiryInput(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  InquiryInput call({
    Object? message = const $CopyWithPlaceholder(),
    Object? replyEmail = const $CopyWithPlaceholder(),
    Object? appVersion = const $CopyWithPlaceholder(),
    Object? os = const $CopyWithPlaceholder(),
    Object? deviceModel = const $CopyWithPlaceholder(),
  }) {
    return InquiryInput(
      message: message == const $CopyWithPlaceholder() || message == null
          ? _value.message
          // ignore: cast_nullable_to_non_nullable
          : message as String,
      replyEmail:
          replyEmail == const $CopyWithPlaceholder() || replyEmail == null
          ? _value.replyEmail
          // ignore: cast_nullable_to_non_nullable
          : replyEmail as String,
      appVersion:
          appVersion == const $CopyWithPlaceholder() || appVersion == null
          ? _value.appVersion
          // ignore: cast_nullable_to_non_nullable
          : appVersion as String,
      os: os == const $CopyWithPlaceholder() || os == null
          ? _value.os
          // ignore: cast_nullable_to_non_nullable
          : os as String,
      deviceModel:
          deviceModel == const $CopyWithPlaceholder() || deviceModel == null
          ? _value.deviceModel
          // ignore: cast_nullable_to_non_nullable
          : deviceModel as String,
    );
  }
}

extension $InquiryInputCopyWith on InquiryInput {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfInquiryInput.copyWith(...)` or `instanceOfInquiryInput.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$InquiryInputCWProxy get copyWith => _$InquiryInputCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

InquiryInput _$InquiryInputFromJson(Map<String, dynamic> json) =>
    $checkedCreate('InquiryInput', json, ($checkedConvert) {
      $checkKeys(
        json,
        requiredKeys: const [
          'message',
          'replyEmail',
          'appVersion',
          'os',
          'deviceModel',
        ],
      );
      final val = InquiryInput(
        message: $checkedConvert('message', (v) => v as String),
        replyEmail: $checkedConvert('replyEmail', (v) => v as String),
        appVersion: $checkedConvert('appVersion', (v) => v as String),
        os: $checkedConvert('os', (v) => v as String),
        deviceModel: $checkedConvert('deviceModel', (v) => v as String),
      );
      return val;
    });

Map<String, dynamic> _$InquiryInputToJson(InquiryInput instance) =>
    <String, dynamic>{
      'message': instance.message,
      'replyEmail': instance.replyEmail,
      'appVersion': instance.appVersion,
      'os': instance.os,
      'deviceModel': instance.deviceModel,
    };
