// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'element_weight.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ElementWeightCWProxy {
  ElementWeight element(FiveElement element);

  ElementWeight weight(num weight);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `ElementWeight(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// ElementWeight(...).copyWith(id: 12, name: "My name")
  /// ```
  ElementWeight call({FiveElement element, num weight});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfElementWeight.copyWith(...)` or call `instanceOfElementWeight.copyWith.fieldName(value)` for a single field.
class _$ElementWeightCWProxyImpl implements _$ElementWeightCWProxy {
  const _$ElementWeightCWProxyImpl(this._value);

  final ElementWeight _value;

  @override
  ElementWeight element(FiveElement element) => call(element: element);

  @override
  ElementWeight weight(num weight) => call(weight: weight);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `ElementWeight(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// ElementWeight(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  ElementWeight call({
    Object? element = const $CopyWithPlaceholder(),
    Object? weight = const $CopyWithPlaceholder(),
  }) {
    return ElementWeight(
      element: element == const $CopyWithPlaceholder() || element == null
          ? _value.element
          // ignore: cast_nullable_to_non_nullable
          : element as FiveElement,
      weight: weight == const $CopyWithPlaceholder() || weight == null
          ? _value.weight
          // ignore: cast_nullable_to_non_nullable
          : weight as num,
    );
  }
}

extension $ElementWeightCopyWith on ElementWeight {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfElementWeight.copyWith(...)` or `instanceOfElementWeight.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ElementWeightCWProxy get copyWith => _$ElementWeightCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ElementWeight _$ElementWeightFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ElementWeight', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['element', 'weight']);
      final val = ElementWeight(
        element: $checkedConvert(
          'element',
          (v) => $enumDecode(_$FiveElementEnumMap, v),
        ),
        weight: $checkedConvert('weight', (v) => v as num),
      );
      return val;
    });

Map<String, dynamic> _$ElementWeightToJson(ElementWeight instance) =>
    <String, dynamic>{
      'element': _$FiveElementEnumMap[instance.element]!,
      'weight': instance.weight,
    };

const _$FiveElementEnumMap = {
  FiveElement.wood: 'wood',
  FiveElement.fire: 'fire',
  FiveElement.earth: 'earth',
  FiveElement.metal: 'metal',
  FiveElement.water: 'water',
};
