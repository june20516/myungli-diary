import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/gen/api/default_api.dart';
import 'package:myungli_diary/core/api/gen/model/evidence_access.dart';
import 'package:myungli_diary/core/api/gen/model/profile.dart';
import 'package:myungli_diary/core/api/gen/model/profile_input.dart';
import 'package:myungli_diary/core/api/gen/model/profile_patch.dart';
import 'package:myungli_diary/core/api/gen/model/profile_response.dart';
import 'package:myungli_diary/core/storage/cache_store.dart';

/// 프로필 사본을 두는 [CacheKind.profile] 캐시 키.
const profileCacheKey = 'profile';

/// `cache`의 프로필 사본을 읽습니다. 없으면 null입니다.
Future<Profile?> readCachedProfile(CacheStore cache) async {
  final json = await cache.read(CacheKind.profile, profileCacheKey);
  if (json == null) {
    return null;
  }
  return Profile.fromJson(jsonDecode(json) as Map<String, dynamic>);
}

/// 프로필 저장과 사본 캐시(결정 A18).
///
/// 프로필을 읽는 GET이 없어, 저장 응답의 `profile`을 계정 범위 캐시에 사본으로 둡니다.
final class ProfileRepository {
  /// `api`로 저장하고 `cache`에 사본을 둡니다. 사본이 바뀌면 `onCacheChanged`를 부릅니다.
  const new(this._api, this._cache, {this.onCacheChanged});

  final DefaultApi _api;
  final CacheStore _cache;

  /// 사본을 새로 썼을 때 부릅니다.
  final void Function()? onCacheChanged;

  /// 프로필을 처음 등록하고 응답을 사본으로 둡니다.
  Future<ProfileResponse> create(ProfileInput input) =>
      _save(() => _api.createProfile(profileInput: input));

  /// 보낸 필드만 바꾸고 응답을 사본으로 둡니다.
  Future<ProfileResponse> update(ProfilePatch patch) =>
      _save(() => _api.updateProfile(profilePatch: patch));

  /// 사본을 읽습니다. 없으면 null입니다.
  Future<Profile?> cached() => readCachedProfile(_cache);

  Future<ProfileResponse> _save(
    Future<Response<ProfileResponse>> Function() request,
  ) async {
    final ProfileResponse? data;
    try {
      data = (await request()).data;
    } on DioException catch (e) {
      throw appErrorFrom(e);
    }
    if (data == null) {
      throw UnexpectedError(StateError('빈 응답'));
    }
    await _cache.write(
      CacheKind.profile,
      profileCacheKey,
      jsonEncode(data.profile.toJson()),
      // 근거 잠금과 무관한 값입니다. `CacheStore.write`의 필수 인자라 채웁니다.
      access: EvidenceAccess.unlocked,
    );
    onCacheChanged?.call();
    return data;
  }
}
