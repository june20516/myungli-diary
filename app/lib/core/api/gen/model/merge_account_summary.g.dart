// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'merge_account_summary.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$MergeAccountSummaryCWProxy {
  MergeAccountSummary honorific(String? honorific);

  MergeAccountSummary saju(MergeSaju saju);

  MergeAccountSummary diaryCount(int diaryCount);

  MergeAccountSummary providers(List<LoginProvider> providers);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `MergeAccountSummary(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// MergeAccountSummary(...).copyWith(id: 12, name: "My name")
  /// ```
  MergeAccountSummary call({
    String? honorific,
    MergeSaju saju,
    int diaryCount,
    List<LoginProvider> providers,
  });
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfMergeAccountSummary.copyWith(...)` or call `instanceOfMergeAccountSummary.copyWith.fieldName(value)` for a single field.
class _$MergeAccountSummaryCWProxyImpl implements _$MergeAccountSummaryCWProxy {
  const _$MergeAccountSummaryCWProxyImpl(this._value);

  final MergeAccountSummary _value;

  @override
  MergeAccountSummary honorific(String? honorific) =>
      call(honorific: honorific);

  @override
  MergeAccountSummary saju(MergeSaju saju) => call(saju: saju);

  @override
  MergeAccountSummary diaryCount(int diaryCount) =>
      call(diaryCount: diaryCount);

  @override
  MergeAccountSummary providers(List<LoginProvider> providers) =>
      call(providers: providers);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `MergeAccountSummary(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// MergeAccountSummary(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  MergeAccountSummary call({
    Object? honorific = const $CopyWithPlaceholder(),
    Object? saju = const $CopyWithPlaceholder(),
    Object? diaryCount = const $CopyWithPlaceholder(),
    Object? providers = const $CopyWithPlaceholder(),
  }) {
    return MergeAccountSummary(
      honorific: honorific == const $CopyWithPlaceholder()
          ? _value.honorific
          // ignore: cast_nullable_to_non_nullable
          : honorific as String?,
      saju: saju == const $CopyWithPlaceholder() || saju == null
          ? _value.saju
          // ignore: cast_nullable_to_non_nullable
          : saju as MergeSaju,
      diaryCount:
          diaryCount == const $CopyWithPlaceholder() || diaryCount == null
          ? _value.diaryCount
          // ignore: cast_nullable_to_non_nullable
          : diaryCount as int,
      providers: providers == const $CopyWithPlaceholder() || providers == null
          ? _value.providers
          // ignore: cast_nullable_to_non_nullable
          : providers as List<LoginProvider>,
    );
  }
}

extension $MergeAccountSummaryCopyWith on MergeAccountSummary {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfMergeAccountSummary.copyWith(...)` or `instanceOfMergeAccountSummary.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$MergeAccountSummaryCWProxy get copyWith =>
      _$MergeAccountSummaryCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MergeAccountSummary _$MergeAccountSummaryFromJson(Map<String, dynamic> json) =>
    $checkedCreate('MergeAccountSummary', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['saju', 'diaryCount', 'providers']);
      final val = MergeAccountSummary(
        honorific: $checkedConvert('honorific', (v) => v as String?),
        saju: $checkedConvert(
          'saju',
          (v) => MergeSaju.fromJson(v as Map<String, dynamic>),
        ),
        diaryCount: $checkedConvert('diaryCount', (v) => (v as num).toInt()),
        providers: $checkedConvert(
          'providers',
          (v) => (v as List<dynamic>)
              .map(
                (e) => $enumDecode(
                  _$LoginProviderEnumMap,
                  e,
                  unknownValue: LoginProvider.unknownDefaultOpenApi,
                ),
              )
              .toList(),
        ),
      );
      return val;
    });

Map<String, dynamic> _$MergeAccountSummaryToJson(
  MergeAccountSummary instance,
) => <String, dynamic>{
  'honorific': ?instance.honorific,
  'saju': instance.saju.toJson(),
  'diaryCount': instance.diaryCount,
  'providers': instance.providers
      .map((e) => _$LoginProviderEnumMap[e]!)
      .toList(),
};

const _$LoginProviderEnumMap = {
  LoginProvider.kakao: 'kakao',
  LoginProvider.apple: 'apple',
  LoginProvider.line: 'line',
  LoginProvider.google: 'google',
  LoginProvider.unknownDefaultOpenApi: 'unknown_default_open_api',
};
