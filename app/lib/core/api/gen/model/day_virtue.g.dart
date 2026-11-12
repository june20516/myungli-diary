// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'day_virtue.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$DayVirtueCWProxy {
  DayVirtue kind(DayVirtueKind kind);

  DayVirtue text(SlotText text);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `DayVirtue(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// DayVirtue(...).copyWith(id: 12, name: "My name")
  /// ```
  DayVirtue call({DayVirtueKind kind, SlotText text});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfDayVirtue.copyWith(...)` or call `instanceOfDayVirtue.copyWith.fieldName(value)` for a single field.
class _$DayVirtueCWProxyImpl implements _$DayVirtueCWProxy {
  const _$DayVirtueCWProxyImpl(this._value);

  final DayVirtue _value;

  @override
  DayVirtue kind(DayVirtueKind kind) => call(kind: kind);

  @override
  DayVirtue text(SlotText text) => call(text: text);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `DayVirtue(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// DayVirtue(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  DayVirtue call({
    Object? kind = const $CopyWithPlaceholder(),
    Object? text = const $CopyWithPlaceholder(),
  }) {
    return DayVirtue(
      kind: kind == const $CopyWithPlaceholder() || kind == null
          ? _value.kind
          // ignore: cast_nullable_to_non_nullable
          : kind as DayVirtueKind,
      text: text == const $CopyWithPlaceholder() || text == null
          ? _value.text
          // ignore: cast_nullable_to_non_nullable
          : text as SlotText,
    );
  }
}

extension $DayVirtueCopyWith on DayVirtue {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfDayVirtue.copyWith(...)` or `instanceOfDayVirtue.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$DayVirtueCWProxy get copyWith => _$DayVirtueCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DayVirtue _$DayVirtueFromJson(Map<String, dynamic> json) =>
    $checkedCreate('DayVirtue', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['kind', 'text']);
      final val = DayVirtue(
        kind: $checkedConvert(
          'kind',
          (v) => $enumDecode(
            _$DayVirtueKindEnumMap,
            v,
            unknownValue: DayVirtueKind.unknownDefaultOpenApi,
          ),
        ),
        text: $checkedConvert(
          'text',
          (v) => SlotText.fromJson(v as Map<String, dynamic>),
        ),
      );
      return val;
    });

Map<String, dynamic> _$DayVirtueToJson(DayVirtue instance) => <String, dynamic>{
  'kind': _$DayVirtueKindEnumMap[instance.kind]!,
  'text': instance.text.toJson(),
};

const _$DayVirtueKindEnumMap = {
  DayVirtueKind.cheondeokDay: 'cheondeok_day',
  DayVirtueKind.woldeokDay: 'woldeok_day',
  DayVirtueKind.unknownDefaultOpenApi: 'unknown_default_open_api',
};
