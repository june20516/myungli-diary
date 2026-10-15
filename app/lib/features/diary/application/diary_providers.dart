import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/clock/clock.dart';
import 'package:myungli_diary/features/diary/data/diary_repository.dart';

/// 일기 저장소. 로그인한 계정에서만 읽을 수 있습니다.
final diaryRepositoryProvider = Provider<DiaryRepository>(
  (ref) => DiaryRepository(ref.watch(restClientProvider)),
);

/// 오늘(`todayProvider`) 일기를 썼는지. 가이드 질문 카드의 쓰기 전·후를 정합니다.
///
/// 404면 false, 그 밖의 실패도 false(쓰기 전)로 그립니다. 일기를 쓰고 돌아온 화면은
/// 이 provider를 invalidate해 다시 묻고, 자정이 지나면 새 날짜로 다시 묻습니다.
final todayDiaryExistsProvider = FutureProvider<bool>((ref) async {
  final date = ref.watch(todayProvider);
  final repository = ref.watch(diaryRepositoryProvider);
  try {
    return await repository.existsOn(date);
  } on Object {
    return false;
  }
});
