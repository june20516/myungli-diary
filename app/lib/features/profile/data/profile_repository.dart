import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/gen/api/default_api.dart';
import 'package:myungli_diary/core/api/gen/model/birth.dart';
import 'package:myungli_diary/core/api/gen/model/evidence_access.dart';
import 'package:myungli_diary/core/api/gen/model/profile.dart';
import 'package:myungli_diary/core/api/gen/model/profile_input.dart';
import 'package:myungli_diary/core/api/gen/model/profile_patch.dart';
import 'package:myungli_diary/core/api/gen/model/profile_response.dart';
import 'package:myungli_diary/core/storage/cache_store.dart';
import 'package:myungli_diary/core/storage/saju_fingerprint.dart';

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
/// 저장 응답의 `profile`을 계정 범위 캐시에 사본으로 둡니다. 사본이 없으면 [fetch]로
/// server의 프로필을 받아 사본으로 둡니다.
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

  /// 출생 정보를 [birth]로 바꾸고(PATCH, `birth`만) 바뀌기 전 사주의 캐시를 지웁니다(A62).
  ///
  /// 사주 기반 캐시(달력·나의 사주·그날)는 키에 사주 지문이 들어 있어(spec §4.4) 바뀌기 전
  /// 사본의 지문으로 만든 줄을 모두 지웁니다. 저장이 실패하면 사본도 캐시도 그대로라 이전
  /// 풀이가 보입니다(Review Focus 1).
  Future<ProfileResponse> changeBirth(Birth birth) async {
    final previous = await cached();
    final response = await update(ProfilePatch(birth: birth));
    if (previous != null) {
      final before = sajuFingerprint(previous);
      if (before != sajuFingerprint(response.profile)) {
        await _cache.dropFingerprint(before);
      }
    }
    return response;
  }

  /// 사본을 읽습니다. 없으면 null입니다.
  Future<Profile?> cached() => readCachedProfile(_cache);

  /// server의 프로필(`getProfile`)을 받아 사본으로 둡니다. 사본이 없을 때(새 기기·재설치,
  /// #312) 씁니다.
  Future<Profile> fetch() async {
    final Profile? profile;
    try {
      profile = (await _api.getProfile()).data;
    } on DioException catch (e) {
      throw appErrorFrom(e);
    }
    if (profile == null) {
      throw UnexpectedError(StateError('빈 응답'));
    }
    await _keep(profile);
    return profile;
  }

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
    await _keep(data.profile);
    return data;
  }

  Future<void> _keep(Profile profile) async {
    await _cache.write(
      CacheKind.profile,
      profileCacheKey,
      jsonEncode(profile.toJson()),
      // 근거 잠금과 무관한 값입니다. `CacheStore.write`의 필수 인자라 채웁니다.
      access: EvidenceAccess.unlocked,
    );
    onCacheChanged?.call();
  }
}
