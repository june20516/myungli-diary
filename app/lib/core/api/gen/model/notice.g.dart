// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notice.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$NoticeCWProxy {
  Notice code(NoticeCode code);

  Notice text(RenderedText text);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `Notice(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// Notice(...).copyWith(id: 12, name: "My name")
  /// ```
  Notice call({NoticeCode code, RenderedText text});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfNotice.copyWith(...)` or call `instanceOfNotice.copyWith.fieldName(value)` for a single field.
class _$NoticeCWProxyImpl implements _$NoticeCWProxy {
  const _$NoticeCWProxyImpl(this._value);

  final Notice _value;

  @override
  Notice code(NoticeCode code) => call(code: code);

  @override
  Notice text(RenderedText text) => call(text: text);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `Notice(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// Notice(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  Notice call({
    Object? code = const $CopyWithPlaceholder(),
    Object? text = const $CopyWithPlaceholder(),
  }) {
    return Notice(
      code: code == const $CopyWithPlaceholder() || code == null
          ? _value.code
          // ignore: cast_nullable_to_non_nullable
          : code as NoticeCode,
      text: text == const $CopyWithPlaceholder() || text == null
          ? _value.text
          // ignore: cast_nullable_to_non_nullable
          : text as RenderedText,
    );
  }
}

extension $NoticeCopyWith on Notice {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfNotice.copyWith(...)` or `instanceOfNotice.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$NoticeCWProxy get copyWith => _$NoticeCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Notice _$NoticeFromJson(Map<String, dynamic> json) =>
    $checkedCreate('Notice', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['code', 'text']);
      final val = Notice(
        code: $checkedConvert(
          'code',
          (v) => $enumDecode(
            _$NoticeCodeEnumMap,
            v,
            unknownValue: NoticeCode.unknownDefaultOpenApi,
          ),
        ),
        text: $checkedConvert(
          'text',
          (v) => RenderedText.fromJson(v as Map<String, dynamic>),
        ),
      );
      return val;
    });

Map<String, dynamic> _$NoticeToJson(Notice instance) => <String, dynamic>{
  'code': _$NoticeCodeEnumMap[instance.code]!,
  'text': instance.text.toJson(),
};

const _$NoticeCodeEnumMap = {
  NoticeCode.ambiguousLocalTime: 'ambiguous_local_time',
  NoticeCode.nonexistentLocalTime: 'nonexistent_local_time',
  NoticeCode.ziHourNextDay: 'zi_hour_next_day',
  NoticeCode.timeUnknown: 'time_unknown',
  NoticeCode.nearSolarTerm: 'near_solar_term',
  NoticeCode.dayunStartApproximate: 'dayun_start_approximate',
  NoticeCode.focusTimeFallback: 'focus_time_fallback',
  NoticeCode.unknownDefaultOpenApi: 'unknown_default_open_api',
};
