import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/api/gen/model/diary_stats.dart';
import 'package:myungli_diary/features/me/data/diary_stats_repository.dart';

/// 일기 회고 집계 저장소. 로그인한 계정에서만 읽을 수 있습니다.
final diaryStatsRepositoryProvider = Provider<DiaryStatsRepository>(
  (ref) => DiaryStatsRepository(ref.watch(restClientProvider)),
);

/// 나 탭 명리일기 회고 집계(A119). 캐시 없이 화면에 들어올 때마다 새로 받습니다.
///
/// 일기를 저장하거나 지우면 `invalidateDiaryViews`가 무효화합니다(본문만 고쳐도 집계는 같아
/// 그 경우는 무효화하지 않습니다). 자동 재시도는 끄고 화면의 다시 시도로만 다시 받습니다.
final FutureProvider<DiaryStats> diaryStatsProvider =
    FutureProvider.autoDispose<DiaryStats>(
      (ref) => ref.watch(diaryStatsRepositoryProvider).fetch(),
      retry: (_, _) => null,
    );
