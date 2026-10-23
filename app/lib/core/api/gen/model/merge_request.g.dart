// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'merge_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$MergeRequestCWProxy {
  MergeRequest mergeToken(String mergeToken);

  MergeRequest profile(MergeProfile profile);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `MergeRequest(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// MergeRequest(...).copyWith(id: 12, name: "My name")
  /// ```
  MergeRequest call({String mergeToken, MergeProfile profile});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfMergeRequest.copyWith(...)` or call `instanceOfMergeRequest.copyWith.fieldName(value)` for a single field.
class _$MergeRequestCWProxyImpl implements _$MergeRequestCWProxy {
  const _$MergeRequestCWProxyImpl(this._value);

  final MergeRequest _value;

  @override
  MergeRequest mergeToken(String mergeToken) => call(mergeToken: mergeToken);

  @override
  MergeRequest profile(MergeProfile profile) => call(profile: profile);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `MergeRequest(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// MergeRequest(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  MergeRequest call({
    Object? mergeToken = const $CopyWithPlaceholder(),
    Object? profile = const $CopyWithPlaceholder(),
  }) {
    return MergeRequest(
      mergeToken:
          mergeToken == const $CopyWithPlaceholder() || mergeToken == null
          ? _value.mergeToken
          // ignore: cast_nullable_to_non_nullable
          : mergeToken as String,
      profile: profile == const $CopyWithPlaceholder() || profile == null
          ? _value.profile
          // ignore: cast_nullable_to_non_nullable
          : profile as MergeProfile,
    );
  }
}

extension $MergeRequestCopyWith on MergeRequest {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfMergeRequest.copyWith(...)` or `instanceOfMergeRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$MergeRequestCWProxy get copyWith => _$MergeRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MergeRequest _$MergeRequestFromJson(Map<String, dynamic> json) =>
    $checkedCreate('MergeRequest', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['mergeToken', 'profile']);
      final val = MergeRequest(
        mergeToken: $checkedConvert('mergeToken', (v) => v as String),
        profile: $checkedConvert(
          'profile',
          (v) => $enumDecode(_$MergeProfileEnumMap, v),
        ),
      );
      return val;
    });

Map<String, dynamic> _$MergeRequestToJson(MergeRequest instance) =>
    <String, dynamic>{
      'mergeToken': instance.mergeToken,
      'profile': _$MergeProfileEnumMap[instance.profile]!,
    };

const _$MergeProfileEnumMap = {
  MergeProfile.current: 'current',
  MergeProfile.other: 'other',
};
