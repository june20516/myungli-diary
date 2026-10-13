// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'calendar.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CalendarCWProxy {
  Calendar year(int year);

  Calendar month(int month);

  Calendar rulesetVersion(String rulesetVersion);

  Calendar evidenceAccess(EvidenceAccess evidenceAccess);

  Calendar days(List<CalendarDay> days);

  Calendar notices(List<Notice> notices);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `Calendar(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// Calendar(...).copyWith(id: 12, name: "My name")
  /// ```
  Calendar call({
    int year,
    int month,
    String rulesetVersion,
    EvidenceAccess evidenceAccess,
    List<CalendarDay> days,
    List<Notice> notices,
  });
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfCalendar.copyWith(...)` or call `instanceOfCalendar.copyWith.fieldName(value)` for a single field.
class _$CalendarCWProxyImpl implements _$CalendarCWProxy {
  const _$CalendarCWProxyImpl(this._value);

  final Calendar _value;

  @override
  Calendar year(int year) => call(year: year);

  @override
  Calendar month(int month) => call(month: month);

  @override
  Calendar rulesetVersion(String rulesetVersion) =>
      call(rulesetVersion: rulesetVersion);

  @override
  Calendar evidenceAccess(EvidenceAccess evidenceAccess) =>
      call(evidenceAccess: evidenceAccess);

  @override
  Calendar days(List<CalendarDay> days) => call(days: days);

  @override
  Calendar notices(List<Notice> notices) => call(notices: notices);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `Calendar(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// Calendar(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  Calendar call({
    Object? year = const $CopyWithPlaceholder(),
    Object? month = const $CopyWithPlaceholder(),
    Object? rulesetVersion = const $CopyWithPlaceholder(),
    Object? evidenceAccess = const $CopyWithPlaceholder(),
    Object? days = const $CopyWithPlaceholder(),
    Object? notices = const $CopyWithPlaceholder(),
  }) {
    return Calendar(
      year: year == const $CopyWithPlaceholder() || year == null
          ? _value.year
          // ignore: cast_nullable_to_non_nullable
          : year as int,
      month: month == const $CopyWithPlaceholder() || month == null
          ? _value.month
          // ignore: cast_nullable_to_non_nullable
          : month as int,
      rulesetVersion:
          rulesetVersion == const $CopyWithPlaceholder() ||
              rulesetVersion == null
          ? _value.rulesetVersion
          // ignore: cast_nullable_to_non_nullable
          : rulesetVersion as String,
      evidenceAccess:
          evidenceAccess == const $CopyWithPlaceholder() ||
              evidenceAccess == null
          ? _value.evidenceAccess
          // ignore: cast_nullable_to_non_nullable
          : evidenceAccess as EvidenceAccess,
      days: days == const $CopyWithPlaceholder() || days == null
          ? _value.days
          // ignore: cast_nullable_to_non_nullable
          : days as List<CalendarDay>,
      notices: notices == const $CopyWithPlaceholder() || notices == null
          ? _value.notices
          // ignore: cast_nullable_to_non_nullable
          : notices as List<Notice>,
    );
  }
}

extension $CalendarCopyWith on Calendar {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfCalendar.copyWith(...)` or `instanceOfCalendar.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CalendarCWProxy get copyWith => _$CalendarCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Calendar _$CalendarFromJson(Map<String, dynamic> json) =>
    $checkedCreate('Calendar', json, ($checkedConvert) {
      $checkKeys(
        json,
        requiredKeys: const [
          'year',
          'month',
          'rulesetVersion',
          'evidenceAccess',
          'days',
          'notices',
        ],
      );
      final val = Calendar(
        year: $checkedConvert('year', (v) => (v as num).toInt()),
        month: $checkedConvert('month', (v) => (v as num).toInt()),
        rulesetVersion: $checkedConvert('rulesetVersion', (v) => v as String),
        evidenceAccess: $checkedConvert(
          'evidenceAccess',
          (v) => $enumDecode(_$EvidenceAccessEnumMap, v),
        ),
        days: $checkedConvert(
          'days',
          (v) => (v as List<dynamic>)
              .map((e) => CalendarDay.fromJson(e as Map<String, dynamic>))
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

Map<String, dynamic> _$CalendarToJson(Calendar instance) => <String, dynamic>{
  'year': instance.year,
  'month': instance.month,
  'rulesetVersion': instance.rulesetVersion,
  'evidenceAccess': _$EvidenceAccessEnumMap[instance.evidenceAccess]!,
  'days': instance.days.map((e) => e.toJson()).toList(),
  'notices': instance.notices.map((e) => e.toJson()).toList(),
};

const _$EvidenceAccessEnumMap = {
  EvidenceAccess.unlocked: 'unlocked',
  EvidenceAccess.locked: 'locked',
};
