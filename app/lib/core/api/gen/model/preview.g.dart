// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'preview.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$PreviewCWProxy {
  Preview date(String date);

  Preview evidenceAccess(EvidenceAccess evidenceAccess);

  Preview dayKind(DayKind dayKind);

  Preview fortune(Fortune fortune);

  Preview featuredTags(List<Tag> featuredTags);

  Preview notices(List<Notice> notices);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `Preview(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// Preview(...).copyWith(id: 12, name: "My name")
  /// ```
  Preview call({
    String date,
    EvidenceAccess evidenceAccess,
    DayKind dayKind,
    Fortune fortune,
    List<Tag> featuredTags,
    List<Notice> notices,
  });
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfPreview.copyWith(...)` or call `instanceOfPreview.copyWith.fieldName(value)` for a single field.
class _$PreviewCWProxyImpl implements _$PreviewCWProxy {
  const _$PreviewCWProxyImpl(this._value);

  final Preview _value;

  @override
  Preview date(String date) => call(date: date);

  @override
  Preview evidenceAccess(EvidenceAccess evidenceAccess) =>
      call(evidenceAccess: evidenceAccess);

  @override
  Preview dayKind(DayKind dayKind) => call(dayKind: dayKind);

  @override
  Preview fortune(Fortune fortune) => call(fortune: fortune);

  @override
  Preview featuredTags(List<Tag> featuredTags) =>
      call(featuredTags: featuredTags);

  @override
  Preview notices(List<Notice> notices) => call(notices: notices);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `Preview(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// Preview(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  Preview call({
    Object? date = const $CopyWithPlaceholder(),
    Object? evidenceAccess = const $CopyWithPlaceholder(),
    Object? dayKind = const $CopyWithPlaceholder(),
    Object? fortune = const $CopyWithPlaceholder(),
    Object? featuredTags = const $CopyWithPlaceholder(),
    Object? notices = const $CopyWithPlaceholder(),
  }) {
    return Preview(
      date: date == const $CopyWithPlaceholder() || date == null
          ? _value.date
          // ignore: cast_nullable_to_non_nullable
          : date as String,
      evidenceAccess:
          evidenceAccess == const $CopyWithPlaceholder() ||
              evidenceAccess == null
          ? _value.evidenceAccess
          // ignore: cast_nullable_to_non_nullable
          : evidenceAccess as EvidenceAccess,
      dayKind: dayKind == const $CopyWithPlaceholder() || dayKind == null
          ? _value.dayKind
          // ignore: cast_nullable_to_non_nullable
          : dayKind as DayKind,
      fortune: fortune == const $CopyWithPlaceholder() || fortune == null
          ? _value.fortune
          // ignore: cast_nullable_to_non_nullable
          : fortune as Fortune,
      featuredTags:
          featuredTags == const $CopyWithPlaceholder() || featuredTags == null
          ? _value.featuredTags
          // ignore: cast_nullable_to_non_nullable
          : featuredTags as List<Tag>,
      notices: notices == const $CopyWithPlaceholder() || notices == null
          ? _value.notices
          // ignore: cast_nullable_to_non_nullable
          : notices as List<Notice>,
    );
  }
}

extension $PreviewCopyWith on Preview {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfPreview.copyWith(...)` or `instanceOfPreview.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$PreviewCWProxy get copyWith => _$PreviewCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Preview _$PreviewFromJson(Map<String, dynamic> json) =>
    $checkedCreate('Preview', json, ($checkedConvert) {
      $checkKeys(
        json,
        requiredKeys: const [
          'date',
          'evidenceAccess',
          'dayKind',
          'fortune',
          'featuredTags',
          'notices',
        ],
      );
      final val = Preview(
        date: $checkedConvert('date', (v) => v as String),
        evidenceAccess: $checkedConvert(
          'evidenceAccess',
          (v) => $enumDecode(_$EvidenceAccessEnumMap, v),
        ),
        dayKind: $checkedConvert(
          'dayKind',
          (v) => $enumDecode(_$DayKindEnumMap, v),
        ),
        fortune: $checkedConvert(
          'fortune',
          (v) => Fortune.fromJson(v as Map<String, dynamic>),
        ),
        featuredTags: $checkedConvert(
          'featuredTags',
          (v) => (v as List<dynamic>)
              .map((e) => Tag.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
        notices: $checkedConvert(
          'notices',
          (v) => (v as List<dynamic>)
              .map((e) => Notice.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
      );
      return val;
    });

Map<String, dynamic> _$PreviewToJson(Preview instance) => <String, dynamic>{
  'date': instance.date,
  'evidenceAccess': _$EvidenceAccessEnumMap[instance.evidenceAccess]!,
  'dayKind': _$DayKindEnumMap[instance.dayKind]!,
  'fortune': instance.fortune.toJson(),
  'featuredTags': instance.featuredTags.map((e) => e.toJson()).toList(),
  'notices': instance.notices.map((e) => e.toJson()).toList(),
};

const _$EvidenceAccessEnumMap = {
  EvidenceAccess.unlocked: 'unlocked',
  EvidenceAccess.locked: 'locked',
};

const _$DayKindEnumMap = {
  DayKind.gwiinDay: 'gwiin_day',
  DayKind.yongsinDay: 'yongsin_day',
  DayKind.gisinDay: 'gisin_day',
  DayKind.ordinaryDay: 'ordinary_day',
};
