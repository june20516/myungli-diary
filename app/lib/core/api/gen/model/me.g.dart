// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'me.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$MeCWProxy {
  Me accountId(String accountId);

  Me consentRequired(bool consentRequired);

  Me requiredConsents(List<ConsentDocument> requiredConsents);

  Me hasProfile(bool hasProfile);

  Me adFree(AdFree adFree);

  Me insight(Insight insight);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `Me(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// Me(...).copyWith(id: 12, name: "My name")
  /// ```
  Me call({
    String accountId,
    bool consentRequired,
    List<ConsentDocument> requiredConsents,
    bool hasProfile,
    AdFree adFree,
    Insight insight,
  });
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfMe.copyWith(...)` or call `instanceOfMe.copyWith.fieldName(value)` for a single field.
class _$MeCWProxyImpl implements _$MeCWProxy {
  const _$MeCWProxyImpl(this._value);

  final Me _value;

  @override
  Me accountId(String accountId) => call(accountId: accountId);

  @override
  Me consentRequired(bool consentRequired) =>
      call(consentRequired: consentRequired);

  @override
  Me requiredConsents(List<ConsentDocument> requiredConsents) =>
      call(requiredConsents: requiredConsents);

  @override
  Me hasProfile(bool hasProfile) => call(hasProfile: hasProfile);

  @override
  Me adFree(AdFree adFree) => call(adFree: adFree);

  @override
  Me insight(Insight insight) => call(insight: insight);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `Me(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// Me(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  Me call({
    Object? accountId = const $CopyWithPlaceholder(),
    Object? consentRequired = const $CopyWithPlaceholder(),
    Object? requiredConsents = const $CopyWithPlaceholder(),
    Object? hasProfile = const $CopyWithPlaceholder(),
    Object? adFree = const $CopyWithPlaceholder(),
    Object? insight = const $CopyWithPlaceholder(),
  }) {
    return Me(
      accountId: accountId == const $CopyWithPlaceholder() || accountId == null
          ? _value.accountId
          // ignore: cast_nullable_to_non_nullable
          : accountId as String,
      consentRequired:
          consentRequired == const $CopyWithPlaceholder() ||
              consentRequired == null
          ? _value.consentRequired
          // ignore: cast_nullable_to_non_nullable
          : consentRequired as bool,
      requiredConsents:
          requiredConsents == const $CopyWithPlaceholder() ||
              requiredConsents == null
          ? _value.requiredConsents
          // ignore: cast_nullable_to_non_nullable
          : requiredConsents as List<ConsentDocument>,
      hasProfile:
          hasProfile == const $CopyWithPlaceholder() || hasProfile == null
          ? _value.hasProfile
          // ignore: cast_nullable_to_non_nullable
          : hasProfile as bool,
      adFree: adFree == const $CopyWithPlaceholder() || adFree == null
          ? _value.adFree
          // ignore: cast_nullable_to_non_nullable
          : adFree as AdFree,
      insight: insight == const $CopyWithPlaceholder() || insight == null
          ? _value.insight
          // ignore: cast_nullable_to_non_nullable
          : insight as Insight,
    );
  }
}

extension $MeCopyWith on Me {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfMe.copyWith(...)` or `instanceOfMe.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$MeCWProxy get copyWith => _$MeCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Me _$MeFromJson(Map<String, dynamic> json) =>
    $checkedCreate('Me', json, ($checkedConvert) {
      $checkKeys(
        json,
        requiredKeys: const [
          'accountId',
          'consentRequired',
          'requiredConsents',
          'hasProfile',
          'adFree',
          'insight',
        ],
      );
      final val = Me(
        accountId: $checkedConvert('accountId', (v) => v as String),
        consentRequired: $checkedConvert('consentRequired', (v) => v as bool),
        requiredConsents: $checkedConvert(
          'requiredConsents',
          (v) => (v as List<dynamic>)
              .map((e) => ConsentDocument.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
        hasProfile: $checkedConvert('hasProfile', (v) => v as bool),
        adFree: $checkedConvert(
          'adFree',
          (v) => AdFree.fromJson(v as Map<String, dynamic>),
        ),
        insight: $checkedConvert(
          'insight',
          (v) => Insight.fromJson(v as Map<String, dynamic>),
        ),
      );
      return val;
    });

Map<String, dynamic> _$MeToJson(Me instance) => <String, dynamic>{
  'accountId': instance.accountId,
  'consentRequired': instance.consentRequired,
  'requiredConsents': instance.requiredConsents.map((e) => e.toJson()).toList(),
  'hasProfile': instance.hasProfile,
  'adFree': instance.adFree.toJson(),
  'insight': instance.insight.toJson(),
};
