import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart'
    show AsyncNotifierProviderFamily, KeepAliveLink;
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/api/gen/model/diary_summary.dart';
import 'package:myungli_diary/core/api/token_store.dart';
import 'package:myungli_diary/features/diary/application/diary_providers.dart';
import 'package:myungli_diary/features/diary/data/diary_repository.dart';

/// 일기 목록 한 쪽의 수. 테스트가 줄여 씁니다.
final diaryPageSizeProvider = Provider<int>((ref) => diaryPageLimit);

/// 받아 둔 일기 목록(A45): 날짜 내림차순 요약, 다음 쪽 cursor, 다음 쪽 받는 중·실패.
@immutable
final class DiaryPagesView {
  /// 목록 값을 만듭니다.
  const new({
    required this.items,
    required this.nextCursor,
    this.loadingMore = false,
    this.moreError,
  });

  /// 받아 둔 요약(날짜 내림차순).
  final List<DiarySummary> items;

  /// 다음 쪽 cursor. null이면 마지막 쪽까지 받았습니다.
  final String? nextCursor;

  /// 다음 쪽을 받는 중인지.
  final bool loadingMore;

  /// 마지막 다음 쪽 받기의 실패. 받아 둔 쪽은 그대로입니다.
  final Object? moreError;

  /// 다음 쪽이 더 있는지.
  bool get hasMore => nextCursor != null;
}

/// 로그아웃으로 버린 목록이 다시 받기 전까지 들고 있는 값. 받은 빈 목록과 구별하려고 따로
/// 만든 인스턴스이고 `identical`로만 비교합니다([heldDiaryPagesOf]).
final DiaryPagesView _forgottenPages = DiaryPagesView(
  items: List.unmodifiable(const <DiarySummary>[]),
  nextCursor: null,
);

/// [state]가 들고 있는 목록. 없거나 로그아웃으로 버린 값이면 null입니다.
///
/// 다시 받는 중(loading)이거나 다시 받기가 실패했어도(error) 받아 둔 목록이 있으면 그
/// 목록입니다. 화면은 그 목록을 그대로 보이고, 실패가 연결 오류면 오프라인 배너를 둡니다.
DiaryPagesView? heldDiaryPagesOf(AsyncValue<DiaryPagesView> state) {
  final value = state.value;
  return identical(value, _forgottenPages) ? null : value;
}

/// [state]에서 로그아웃으로 버린 값을 뺀 상태. 화면은 이 값을 그립니다.
///
/// 버린 값만 들고 다시 받는 중이면 값 없는 loading, 다시 받기가 실패했으면 값 없는 오류라,
/// 이전 계정 일기도 잠깐의 "일기 없음"도 보이지 않습니다.
AsyncValue<DiaryPagesView> visibleDiaryPagesOf(
  AsyncValue<DiaryPagesView> state,
) {
  if (!identical(state.value, _forgottenPages)) {
    return state;
  }
  final error = state.error;
  if (state.isLoading || error == null) {
    return const AsyncLoading<DiaryPagesView>();
  }
  return AsyncError<DiaryPagesView>(
    error,
    state.stackTrace ?? StackTrace.empty,
  );
}

/// 일기 목록(A45). family 값은 태그 키이고 null이면 모든 일기(`diary-list`), 있으면 그 태그
/// 일기(`tag-diary`)입니다.
///
/// 기기에 저장하지 않고 메모리에만 듭니다. 모든 일기 목록은 구독이 끝나도 버리지 않아 탭을
/// 오가도 받아 둔 쪽이 남고, 태그 목록은 화면을 닫으면 버립니다. 다시 받기
/// (`ref.invalidate`)가 실패해도 받아 둔 목록은 값으로 남습니다([heldDiaryPagesOf]).
/// 로그아웃하면 받아 둔 값을 버립니다(이전 계정 일기가 남지 않음). 자동 재시도는 끕니다.
final AsyncNotifierProviderFamily<DiaryPages, DiaryPagesView, String?>
diaryPagesProvider = AsyncNotifierProvider.autoDispose
    .family<DiaryPages, DiaryPagesView, String?>(
      DiaryPages.new,
      retry: (_, _) => null,
    );

/// [diaryPagesProvider]의 notifier.
final class DiaryPages extends AsyncNotifier<DiaryPagesView> {
  /// [tag] 목록을 듭니다(null이면 모든 일기).
  new(this.tag);

  /// 거르는 태그 키. null이면 모든 일기입니다.
  final String? tag;

  /// 첫 쪽부터 다시 받을 때마다 늘어나는 세대. 앞 세대의 다음 쪽 응답은 버립니다.
  int _generation = 0;

  @override
  Future<DiaryPagesView> build() async {
    final keepAlive = tag == null ? ref.keepAlive() : null;
    final signOuts = ref
        .watch(tokenStoreProvider)
        .events
        .where((event) => event == AuthEvent.signedOut)
        .listen((_) => _forget(keepAlive));
    ref.onDispose(() => unawaited(signOuts.cancel()));
    _generation++;
    final page = await ref
        .watch(diaryRepositoryProvider)
        .page(tag: tag, limit: ref.watch(diaryPageSizeProvider));
    return DiaryPagesView(items: page.items, nextCursor: page.nextCursor);
  }

  /// 다음 쪽을 받아 뒤에 붙입니다.
  ///
  /// 받는 중이거나 마지막 쪽이면 아무것도 하지 않습니다(같은 cursor를 두 번 묻지 않음).
  /// 실패하면 받아 둔 쪽은 그대로 두고 [DiaryPagesView.moreError]에 남깁니다.
  Future<void> loadMore() async {
    final view = heldDiaryPagesOf(state);
    if (view == null || !view.hasMore || view.loadingMore) {
      return;
    }
    final generation = _generation;
    state = AsyncData(
      DiaryPagesView(
        items: view.items,
        nextCursor: view.nextCursor,
        loadingMore: true,
      ),
    );
    try {
      final page = await ref
          .read(diaryRepositoryProvider)
          .page(
            tag: tag,
            cursor: view.nextCursor,
            limit: ref.read(diaryPageSizeProvider),
          );
      if (!ref.mounted || generation != _generation) {
        return;
      }
      state = AsyncData(
        DiaryPagesView(
          items: [...view.items, ...page.items],
          nextCursor: page.nextCursor,
        ),
      );
    } on Object catch (error) {
      if (!ref.mounted || generation != _generation) {
        return;
      }
      state = AsyncData(
        DiaryPagesView(
          items: view.items,
          nextCursor: view.nextCursor,
          moreError: error,
        ),
      );
    }
  }

  /// 로그아웃: 받아 둔 값을 버리고 붙들기를 놓습니다. 진행 중인 응답은 반영하지 않습니다.
  ///
  /// Riverpod은 새 상태에 이전 값을 옮겨 담으므로, 먼저 [_forgottenPages]로 덮어 이전 계정
  /// 일기가 다시 받는 동안에도 남지 않게 합니다.
  void _forget(KeepAliveLink? keepAlive) {
    _generation++;
    state = AsyncData(_forgottenPages);
    keepAlive?.close();
    ref.invalidateSelf();
  }
}
