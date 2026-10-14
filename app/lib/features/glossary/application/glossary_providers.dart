import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/api/gen/model/profile.dart';
import 'package:myungli_diary/core/platform/device_locale.dart';
import 'package:myungli_diary/core/storage/cache_store.dart';
import 'package:myungli_diary/features/glossary/data/glossary_repository.dart';
import 'package:myungli_diary/features/profile/application/profile_providers.dart';

/// 이름 사전 저장소. 로그인한 계정에서만 읽을 수 있습니다.
final glossaryRepositoryProvider = Provider<GlossaryRepository>(
  (ref) => GlossaryRepository(
    ref.watch(restClientProvider),
    ref.watch(cacheStoreProvider),
  ),
);

/// 이름 사전. 언어는 프로필 사본의 `language`, 없으면 앱 언어입니다.
final glossaryProvider = FutureProvider<GlossaryNames>((ref) async {
  // 프로필 사본을 읽지 못해도 사전이 막히지 않게 앱 언어로 대체합니다.
  Profile? profile;
  try {
    profile = await ref.watch(cachedProfileProvider.future);
  } on Object {
    profile = null;
  }
  // 앱 언어는 항상 구독해, 프로필이 없다가 생겨도 다시 계산됩니다.
  final appLanguage = ref.watch(appLanguageProvider);
  final language = profile?.language ?? appLanguage;
  final repository = ref.watch(glossaryRepositoryProvider);
  return await repository.load(language);
});
