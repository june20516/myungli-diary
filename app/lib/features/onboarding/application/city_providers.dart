import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/features/onboarding/data/city_repository.dart';

/// 도시 검색 저장소. 앱이 켜져 있는 동안 `ETag` 사본을 메모리에 둡니다.
final cityRepositoryProvider = Provider<CityRepository>(
  (ref) => CityRepository(ref.watch(restClientProvider)),
);
