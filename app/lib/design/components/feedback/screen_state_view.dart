import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/feedback/empty_state.dart';
import 'package:myungli_diary/design/components/feedback/error_state.dart';
import 'package:myungli_diary/design/components/feedback/notice_banner.dart';
import 'package:myungli_diary/design/components/feedback/seep_presence.dart';
import 'package:myungli_diary/design/components/feedback/skeleton.dart';

/// 화면 상태를 명세 `stateMap`대로 보이는 공용 뷰.
///
/// | 값 | 보이는 것 |
/// | --- | --- |
/// | 처음 불러오는 중(값 없음), 다시 시도 중 | skeleton (스피너 없음) |
/// | 값이 있고 갱신 중 | 데이터 그대로 (skeleton으로 바꾸지 않음) |
/// | 값 없음 + [OfflineError] | error-state `offline` |
/// | 값 없음 + 그 밖의 오류 | error-state `generic` |
/// | 값이 있고 오류가 [OfflineError] | 데이터 + notice-banner `offline` |
/// | 값이 있고 `isEmpty` | empty-state |
class ScreenStateView<T> extends StatelessWidget {
  /// 상태 뷰를 만듭니다.
  ///
  /// 오프라인 배너는 기본적으로 [data] 위에 한 줄로 놓입니다. 배너가 내용과 함께
  /// 스크롤되어야 하는 화면은 [dataWithNotice]를 주고 받은 `notice`를 스크롤 목록의
  /// 첫 항목으로 놓습니다(이때 [data]는 쓰지 않습니다).
  const new({
    required this.value,
    required this.onRetry,
    this.data,
    this.dataWithNotice,
    this.skeleton,
    this.isEmpty,
    this.empty,
    this.skeletonDelay = SkeletonBlock.defaultDelay,
    super.key,
  }) : assert(
         (data == null) != (dataWithNotice == null),
         'data와 dataWithNotice 중 하나만 줍니다.',
       );

  /// 화면의 비동기 값.
  final AsyncValue<T> value;

  /// 오류 화면의 다시 시도. 호출하는 쪽이 provider를 다시 불러 같은 자리에 skeleton이 나오게 합니다.
  final VoidCallback onRetry;

  /// 값이 있을 때의 내용.
  final Widget Function(T value)? data;

  /// 값이 있을 때의 내용. `notice`를 내용의 첫 줄에 놓습니다.
  final Widget Function(T value, Widget notice)? dataWithNotice;

  /// 실제 올 요소와 같은 모양의 skeleton. 없으면 글줄 skeleton.
  final Widget? skeleton;

  /// 값이 비었는지.
  final bool Function(T value)? isEmpty;

  /// 빈 상태 화면. 없으면 기본 문구의 [EmptyState].
  final Widget? empty;

  /// skeleton을 보이기 전 대기(기본 300ms). golden·테스트에서 줄입니다.
  final Duration skeletonDelay;

  @override
  Widget build(BuildContext context) {
    final current = value;
    if (current.hasValue) {
      return _withValue(context, current.requireValue, current.error);
    }
    if (current.isLoading) {
      return KeyedSubtree(
        key: const ValueKey('screen-state.loading'),
        child: skeleton == null
            ? SkeletonBlock(delay: skeletonDelay)
            : SkeletonBlock(delay: skeletonDelay, child: skeleton),
      );
    }
    final error = current.error;
    return SeepPresence(
      key: const ValueKey('screen-state.error'),
      present: true,
      child: ErrorState(
        error: error is AppError ? error : UnexpectedError(error ?? 'unknown'),
        onRetry: onRetry,
      ),
    );
  }

  Widget _withValue(BuildContext context, T current, Object? error) {
    final l10n = AppLocalizations.of(context);
    final offline = error is OfflineError;
    final notice = NoticeBanner(
      variant: NoticeBannerVariant.offline,
      message: l10n.noticeOffline,
      present: offline,
    );
    if (isEmpty?.call(current) ?? false) {
      return SeepPresence(
        key: const ValueKey('screen-state.empty'),
        present: true,
        child: Column(
          children: [
            notice,
            Expanded(child: empty ?? EmptyState(body: l10n.emptyStateDefault)),
          ],
        ),
      );
    }
    final withNotice = dataWithNotice;
    if (withNotice != null) {
      return SeepPresence(
        key: const ValueKey('screen-state.data'),
        present: true,
        child: withNotice(current, notice),
      );
    }
    return SeepPresence(
      key: const ValueKey('screen-state.data'),
      present: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          notice,
          Expanded(child: data!(current)),
        ],
      ),
    );
  }
}
