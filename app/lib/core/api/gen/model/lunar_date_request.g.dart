// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'lunar_date_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$LunarDateRequestCWProxy {
  LunarDateRequest installationId(String installationId);

  LunarDateRequest date(LunarOrSolarDate date);

  LunarDateRequest isLeapMonth(bool isLeapMonth);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `LunarDateRequest(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// LunarDateRequest(...).copyWith(id: 12, name: "My name")
  /// ```
  LunarDateRequest call({
    String installationId,
    LunarOrSolarDate date,
    bool isLeapMonth,
  });
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfLunarDateRequest.copyWith(...)` or call `instanceOfLunarDateRequest.copyWith.fieldName(value)` for a single field.
class _$LunarDateRequestCWProxyImpl implements _$LunarDateRequestCWProxy {
  const _$LunarDateRequestCWProxyImpl(this._value);

  final LunarDateRequest _value;

  @override
  LunarDateRequest installationId(String installationId) =>
      call(installationId: installationId);

  @override
  LunarDateRequest date(LunarOrSolarDate date) => call(date: date);

  @override
  LunarDateRequest isLeapMonth(bool isLeapMonth) =>
      call(isLeapMonth: isLeapMonth);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `LunarDateRequest(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// LunarDateRequest(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  LunarDateRequest call({
    Object? installationId = const $CopyWithPlaceholder(),
    Object? date = const $CopyWithPlaceholder(),
    Object? isLeapMonth = const $CopyWithPlaceholder(),
  }) {
    return LunarDateRequest(
      installationId:
          installationId == const $CopyWithPlaceholder() ||
              installationId == null
          ? _value.installationId
          // ignore: cast_nullable_to_non_nullable
          : installationId as String,
      date: date == const $CopyWithPlaceholder() || date == null
          ? _value.date
          // ignore: cast_nullable_to_non_nullable
          : date as LunarOrSolarDate,
      isLeapMonth:
          isLeapMonth == const $CopyWithPlaceholder() || isLeapMonth == null
          ? _value.isLeapMonth
          // ignore: cast_nullable_to_non_nullable
          : isLeapMonth as bool,
    );
  }
}

extension $LunarDateRequestCopyWith on LunarDateRequest {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfLunarDateRequest.copyWith(...)` or `instanceOfLunarDateRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$LunarDateRequestCWProxy get copyWith => _$LunarDateRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LunarDateRequest _$LunarDateRequestFromJson(Map<String, dynamic> json) =>
    $checkedCreate('LunarDateRequest', json, ($checkedConvert) {
      $checkKeys(
        json,
        requiredKeys: const ['installationId', 'date', 'isLeapMonth'],
      );
      final val = LunarDateRequest(
        installationId: $checkedConvert('installationId', (v) => v as String),
        date: $checkedConvert(
          'date',
          (v) => LunarOrSolarDate.fromJson(v as Map<String, dynamic>),
        ),
        isLeapMonth: $checkedConvert('isLeapMonth', (v) => v as bool),
      );
      return val;
    });

Map<String, dynamic> _$LunarDateRequestToJson(LunarDateRequest instance) =>
    <String, dynamic>{
      'installationId': instance.installationId,
      'date': instance.date.toJson(),
      'isLeapMonth': instance.isLeapMonth,
    };
