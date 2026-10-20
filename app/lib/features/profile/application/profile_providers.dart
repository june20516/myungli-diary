import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myungli_diary/app/entry/entry_providers.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/gen/model/profile.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';
import 'package:myungli_diary/core/storage/cache_store.dart';
import 'package:myungli_diary/features/profile/data/profile_repository.dart';

/// 프로필 저장소. 로그인한 계정에서만 읽을 수 있습니다.
final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(
    ref.watch(restClientProvider),
    ref.watch(cacheStoreProvider),
    ref.watch(crashReporterProvider),
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

/// 화면에 보일 프로필: 사본, 사본이 없으면(새 기기·재설치) server에서 받아 사본으로 둔 값입니다
/// (A18, #312). 로그아웃 상태면 null입니다.
///
/// 보는 화면(설정·정보 수정)이 있는 동안만 둡니다(autoDispose). 받지 못하면 그 [AppError]가
/// 오류 값이고 자동으로 다시 받지 않습니다. 화면을 다시 열거나(새로 만들어짐) invalidate하면
/// 다시 받습니다. 받아 둔 사본이 바뀌면(저장 응답) 그 값을 다시 냅니다.
final FutureProvider<Profile?> profileProvider =
    FutureProvider.autoDispose<Profile?>((ref) async {
      final cached = await ref.watch(cachedProfileProvider.future);
      if (cached != null || ref.watch(meProvider) == null) {
        return cached;
      }
      return await ref.read(profileRepositoryProvider).fetch();
    }, retry: (_, _) => null);
