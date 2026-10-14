import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myungli_diary/app/entry/entry_providers.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/api/gen/model/profile.dart';
import 'package:myungli_diary/core/storage/cache_store.dart';
import 'package:myungli_diary/features/profile/data/profile_repository.dart';

/// 프로필 저장소. 로그인한 계정에서만 읽을 수 있습니다.
final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(
    ref.watch(restClientProvider),
    ref.watch(cacheStoreProvider),
    onCacheChanged: () => ref.invalidate(cachedProfileProvider),
  ),
);

/// 프로필 사본. 로그아웃 상태이거나 저장한 적이 없으면 null입니다.
final cachedProfileProvider = FutureProvider<Profile?>((ref) {
  if (ref.watch(meProvider) == null) {
    return null;
  }
  return readCachedProfile(ref.watch(cacheStoreProvider));
});
