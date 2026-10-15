import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/features/monetization/data/entitlements_repository.dart';

/// 이용권 저장소. 로그인한 계정에서만 물을 수 있습니다.
final entitlementsRepositoryProvider = Provider<EntitlementsRepository>(
  (ref) => EntitlementsRepository(ref.watch(restClientProvider)),
);
