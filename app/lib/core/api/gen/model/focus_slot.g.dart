// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'focus_slot.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$FocusSlotCWProxy {
  FocusSlot branch(Branch branch);

  FocusSlot start(DateTime start);

  FocusSlot end(DateTime end);

  FocusSlot huangdaoLucky(bool huangdaoLucky);

  FocusSlot reasons(List<FocusSlotReasonsEnum> reasons);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `FocusSlot(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// FocusSlot(...).copyWith(id: 12, name: "My name")
  /// ```
  FocusSlot call({
    Branch branch,
    DateTime start,
    DateTime end,
    bool huangdaoLucky,
    List<FocusSlotReasonsEnum> reasons,
  });
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfFocusSlot.copyWith(...)` or call `instanceOfFocusSlot.copyWith.fieldName(value)` for a single field.
class _$FocusSlotCWProxyImpl implements _$FocusSlotCWProxy {
  const _$FocusSlotCWProxyImpl(this._value);

  final FocusSlot _value;

  @override
  FocusSlot branch(Branch branch) => call(branch: branch);

  @override
  FocusSlot start(DateTime start) => call(start: start);

  @override
  FocusSlot end(DateTime end) => call(end: end);

  @override
  FocusSlot huangdaoLucky(bool huangdaoLucky) =>
      call(huangdaoLucky: huangdaoLucky);

  @override
  FocusSlot reasons(List<FocusSlotReasonsEnum> reasons) =>
      call(reasons: reasons);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `FocusSlot(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// FocusSlot(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  FocusSlot call({
    Object? branch = const $CopyWithPlaceholder(),
    Object? start = const $CopyWithPlaceholder(),
    Object? end = const $CopyWithPlaceholder(),
    Object? huangdaoLucky = const $CopyWithPlaceholder(),
    Object? reasons = const $CopyWithPlaceholder(),
  }) {
    return FocusSlot(
      branch: branch == const $CopyWithPlaceholder() || branch == null
          ? _value.branch
          // ignore: cast_nullable_to_non_nullable
          : branch as Branch,
      start: start == const $CopyWithPlaceholder() || start == null
          ? _value.start
          // ignore: cast_nullable_to_non_nullable
          : start as DateTime,
      end: end == const $CopyWithPlaceholder() || end == null
          ? _value.end
          // ignore: cast_nullable_to_non_nullable
          : end as DateTime,
      huangdaoLucky:
          huangdaoLucky == const $CopyWithPlaceholder() || huangdaoLucky == null
          ? _value.huangdaoLucky
          // ignore: cast_nullable_to_non_nullable
          : huangdaoLucky as bool,
      reasons: reasons == const $CopyWithPlaceholder() || reasons == null
          ? _value.reasons
          // ignore: cast_nullable_to_non_nullable
          : reasons as List<FocusSlotReasonsEnum>,
    );
  }
}

extension $FocusSlotCopyWith on FocusSlot {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfFocusSlot.copyWith(...)` or `instanceOfFocusSlot.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$FocusSlotCWProxy get copyWith => _$FocusSlotCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FocusSlot _$FocusSlotFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('FocusSlot', json, ($checkedConvert) {
  $checkKeys(
    json,
    requiredKeys: const ['branch', 'start', 'end', 'huangdaoLucky', 'reasons'],
  );
  final val = FocusSlot(
    branch: $checkedConvert('branch', (v) => $enumDecode(_$BranchEnumMap, v)),
    start: $checkedConvert('start', (v) => DateTime.parse(v as String)),
    end: $checkedConvert('end', (v) => DateTime.parse(v as String)),
    huangdaoLucky: $checkedConvert('huangdaoLucky', (v) => v as bool),
    reasons: $checkedConvert(
      'reasons',
      (v) => (v as List<dynamic>)
          .map(
            (e) => $enumDecode(
              _$FocusSlotReasonsEnumEnumMap,
              e,
              unknownValue: FocusSlotReasonsEnum.unknownDefaultOpenApi,
            ),
          )
          .toList(),
    ),
  );
  return val;
});

Map<String, dynamic> _$FocusSlotToJson(FocusSlot instance) => <String, dynamic>{
  'branch': _$BranchEnumMap[instance.branch]!,
  'start': instance.start.toIso8601String(),
  'end': instance.end.toIso8601String(),
  'huangdaoLucky': instance.huangdaoLucky,
  'reasons': instance.reasons
      .map((e) => _$FocusSlotReasonsEnumEnumMap[e]!)
      .toList(),
};

const _$BranchEnumMap = {
  Branch.ja: 'ja',
  Branch.chuk: 'chuk',
  Branch.in_: 'in',
  Branch.myo: 'myo',
  Branch.jin: 'jin',
  Branch.sa: 'sa',
  Branch.o: 'o',
  Branch.mi: 'mi',
  Branch.shin: 'shin',
  Branch.yu: 'yu',
  Branch.sul: 'sul',
  Branch.hae: 'hae',
};

const _$FocusSlotReasonsEnumEnumMap = {
  FocusSlotReasonsEnum.gwiin: 'gwiin',
  FocusSlotReasonsEnum.yongsin: 'yongsin',
  FocusSlotReasonsEnum.huisin: 'huisin',
  FocusSlotReasonsEnum.hap: 'hap',
  FocusSlotReasonsEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};
