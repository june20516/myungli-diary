import 'package:flutter/foundation.dart' show precisionErrorTolerance;
import 'package:flutter/widgets.dart';

/// 끝에 닿아 있던 세로 스크롤은 내용이 자라도 새 끝에 붙어 있게 합니다(#936).
///
/// `ScrollPosition`은 내용이 길어져도 픽셀 위치를 그대로 두어, 끝에 닿은 뒤 늦게 자라는 섹션(나중에
/// 받는 집계 등)이 하단 틀 아래로 들어가 한 번 더 내려야 보입니다. [child] 안 가장 바깥 세로
/// 스크롤이 끝에 있었고 그 뒤 끝이 늘면 다음 프레임에 새 끝으로 옮깁니다. 끝에서 떨어져 있으면
/// 아무것도 하지 않습니다. 사용자가 끌거나 튕기는 중이면 그 움직임을 끊지 않고, 움직임이 끝났을 때
/// 아직 예전 끝 근처에 있으면 그때 새 끝으로 옮깁니다.
///
/// 끝에서 다음 쪽을 붙이는 무한 스크롤(일기 목록)에는 쓰지 않습니다. 새 끝으로 옮기면 다시 끝에
/// 닿아 다음 쪽을 연달아 받는 고리가 생깁니다.
class StickToEndOnGrow extends StatefulWidget {
  /// [child]의 세로 스크롤을 지켜봅니다.
  const new({required this.child, super.key});

  /// 세로 스크롤을 담은 위젯.
  final Widget child;

  /// 끝으로 볼 오차(논리 픽셀).
  static const double tolerance = 1;

  @override
  State<StickToEndOnGrow> createState() => _StickToEndOnGrowState();
}

class _StickToEndOnGrowState extends State<StickToEndOnGrow> {
  /// 마지막으로 본 끝 위치.
  double? _lastMaxExtent;

  /// 마지막으로 본 위치가 끝이었는지.
  bool _atEnd = false;

  /// 사용자가 움직이는 중에 끝이 늘었으면 그때의 예전 끝. 움직임이 끝나면 맞춥니다.
  double? _endBeforeGrowth;

  /// 끝에 닿아 있는지. 내용이 화면보다 짧아 맨 위가 곧 끝인 때는 끝으로 보지 않습니다(그 뒤
  /// 내용이 길어져도 맨 위에 둠).
  static bool _isEnd(ScrollMetrics metrics) =>
      metrics.maxScrollExtent > metrics.minScrollExtent &&
      metrics.pixels >= metrics.maxScrollExtent - StickToEndOnGrow.tolerance;

  bool _onScroll(ScrollNotification notification) {
    final metrics = notification.metrics;
    if (!_watches(notification.depth, metrics)) return false;
    final before = _endBeforeGrowth;
    if (notification is ScrollEndNotification && before != null) {
      _endBeforeGrowth = null;
      final context = notification.context;
      if (context != null &&
          metrics.pixels >= before - StickToEndOnGrow.tolerance) {
        _jumpToEnd(Scrollable.maybeOf(context)?.position);
      }
    }
    _atEnd = _isEnd(metrics);
    _lastMaxExtent = metrics.maxScrollExtent;
    return false;
  }

  void _jumpToEnd(ScrollPosition? position) {
    if (position == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && position.hasPixels && position.hasContentDimensions) {
        position.jumpTo(position.maxScrollExtent);
      }
    });
  }

  bool _onMetrics(ScrollMetricsNotification notification) {
    final metrics = notification.metrics;
    if (!_watches(notification.depth, metrics)) return false;
    final last = _lastMaxExtent;
    // 배너처럼 프레임마다 조금씩 자라는 경우도 따라가도록 늘어남은 정밀 오차로만 거릅니다.
    final grew =
        last != null &&
        metrics.maxScrollExtent > last + precisionErrorTolerance;
    _lastMaxExtent = metrics.maxScrollExtent;
    if (grew && _atEnd) {
      final position = Scrollable.maybeOf(notification.context)?.position;
      if (position != null && position.isScrollingNotifier.value) {
        // 끌거나 튕기는 중이면 끊지 않고 끝난 뒤 맞춥니다.
        _endBeforeGrowth ??= last;
      } else {
        _jumpToEnd(position);
      }
      return false;
    }
    _atEnd = _isEnd(metrics);
    return false;
  }

  static bool _watches(int depth, ScrollMetrics metrics) =>
      depth == 0 && metrics.axis == Axis.vertical;

  @override
  Widget build(BuildContext context) =>
      NotificationListener<ScrollMetricsNotification>(
        onNotification: _onMetrics,
        child: NotificationListener<ScrollNotification>(
          onNotification: _onScroll,
          child: widget.child,
        ),
      );
}
