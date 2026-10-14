import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/core/platform/crash_reporter.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';
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
/// | 값이 있고 오프라인이 아닌 오류(예 500) | 데이터 그대로, 화면 안 표시 없음. `onStaleError`로 알림 |
/// | 값이 있고 `isEmpty` | empty-state |
///
/// 값 없는 오류가 [AppError]가 아니면 [UnexpectedError]로 감싸 보이고, 비정상 종료 보고
/// (`crashReporterProvider`)에 [CrashSummary] 형태로 한 번 기록합니다. 사용자 눈에는
/// 일반 오류 화면뿐이라 개발자가 알 길이 이것뿐이기 때문입니다([AppError]는 이미 분류된
/// 통신 실패라 기록하지 않습니다).
///
/// 기본 `data` 경로는 높이가 정해진 부모(화면 본문)를 전제로 합니다(`Expanded`를 씁니다).
/// 스크롤·sliver 안에서 쓰거나 배너를 내용과 함께 스크롤시키려면 `dataWithNotice`를 씁니다.
class ScreenStateView<T> extends ConsumerStatefulWidget {
  /// 상태 뷰를 만듭니다.
  ///
  /// 오프라인 배너는 기본적으로 `data` 위에 한 줄로 놓입니다. 배너가 내용과 함께
  /// 스크롤되어야 하는 화면은 `dataWithNotice`를 주고 받은 `notice`를 스크롤 목록의
  /// 첫 항목으로 놓습니다(이때 `data`는 쓰지 않습니다).
  const new({
    required this.value,
    required this.onRetry,
    this.data,
    this.dataWithNotice,
    this.skeleton,
    this.isEmpty,
    this.empty,
    this.onStaleError,
    this.skeletonDelay = SkeletonBlock.defaultDelay,
    super.key,
  }) : assert(
         (data == null) != (dataWithNotice == null),
         'data와 dataWithNotice 중 하나만 줍니다.',
       );

  /// 화면의 비동기 값.
  final AsyncValue<T> value;

  /// 오류 화면의 다시 시도. 호출하는 쪽이 provider를 다시 불러 같은 자리에 skeleton이 나오게 합니다.
  /// null이면 오류 화면에 다시 시도를 그리지 않습니다.
  final VoidCallback? onRetry;

  /// 값이 있을 때의 내용(높이가 정해진 부모 전제).
  final Widget Function(T value)? data;

  /// 값이 있을 때의 내용. `notice`를 내용의 첫 줄에 놓습니다.
  final Widget Function(T value, Widget notice)? dataWithNotice;

  /// 실제 올 요소와 같은 모양의 skeleton. 없으면 글줄 skeleton.
  final Widget? skeleton;

  /// 값이 비었는지.
  final bool Function(T value)? isEmpty;

  /// 빈 상태 화면. 없으면 기본 문구의 [EmptyState].
  final Widget? empty;

  /// 값이 있는데 오프라인이 아닌 오류가 났을 때 오류마다 한 번 불립니다.
  /// 화면이 toast 등으로 알립니다. 없으면 조용히 데이터를 유지합니다.
  final void Function(AppError error)? onStaleError;

  /// skeleton을 보이기 전 대기(기본 300ms). golden·테스트에서 줄입니다.
  final Duration skeletonDelay;

  @override
  ConsumerState<ScreenStateView<T>> createState() => _ScreenStateViewState<T>();
}

AppError _asAppError(Object? error) =>
    error is AppError ? error : UnexpectedError(error ?? 'unknown');

class _ScreenStateViewState<T> extends ConsumerState<ScreenStateView<T>> {
  Object? _handledError;

  @override
  void initState() {
    super.initState();
    _handle(widget.value);
  }

  @override
  void didUpdateWidget(ScreenStateView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    _handle(widget.value);
  }

  /// 같은 오류는 한 번만 처리합니다(로딩·갱신으로 같은 오류가 이어져도 반복하지 않음).
  void _handle(AsyncValue<T> current) {
    if (!current.hasError) {
      _handledError = null;
      return;
    }
    final error = current.error;
    if (identical(error, _handledError)) return;
    _handledError = error;
    if (error is! AppError) {
      ref
          .read(crashReporterProvider)
          .record(
            CrashSummary.from(_asAppError(error)),
            current.stackTrace ?? StackTrace.current,
          );
    }
    final callback = widget.onStaleError;
    final appError = _asAppError(error);
    if (current.hasValue && appError is! OfflineError && callback != null) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) callback(appError);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.value;
    if (current.hasValue) {
      return _withValue(context, current.requireValue, current.error);
    }
    if (current.isLoading) {
      return KeyedSubtree(
        key: const ValueKey('screen-state.loading'),
        child: SkeletonBlock(
          delay: widget.skeletonDelay,
          child: widget.skeleton,
        ),
      );
    }
    return SeepPresence(
      key: const ValueKey('screen-state.error'),
      present: true,
      child: ErrorState(
        error: _asAppError(current.error),
        onRetry: widget.onRetry,
      ),
    );
  }

  Widget _withValue(BuildContext context, T current, Object? error) {
    final l10n = AppLocalizations.of(context);
    final notice = NoticeBanner(
      variant: NoticeBannerVariant.offline,
      message: l10n.noticeOffline,
      present: error is OfflineError,
    );
    if (widget.isEmpty?.call(current) ?? false) {
      return SeepPresence(
        key: const ValueKey('screen-state.empty'),
        present: true,
        child: Column(
          children: [
            notice,
            Expanded(
              child: widget.empty ?? EmptyState(body: l10n.emptyStateDefault),
            ),
          ],
        ),
      );
    }
    final withNotice = widget.dataWithNotice;
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
          Expanded(child: widget.data!(current)),
        ],
      ),
    );
  }
}
