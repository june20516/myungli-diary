import 'package:flutter/widgets.dart';

/// 끝에 닿아 있던 세로 스크롤은 내용이 자라도 새 끝에 붙어 있게 합니다(#936).
///
/// `ScrollPosition`은 내용이 길어져도 픽셀 위치를 그대로 두어, 끝에 닿은 뒤 늦게 자라는 섹션(나중에
/// 받는 집계 등)이 하단 틀 아래로 들어가 한 번 더 내려야 보입니다. [child] 안 가장 바깥 세로
/// 스크롤이 끝에 있었고 그 뒤 끝이 늘면 다음 프레임에 새 끝으로 옮깁니다. 끝에서 떨어져 있으면
/// 아무것도 하지 않습니다.
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

  /// 끝에 닿아 있는지. 내용이 화면보다 짧아 맨 위가 곧 끝인 때는 끝으로 보지 않습니다(그 뒤
  /// 내용이 길어져도 맨 위에 둠).
  static bool _isEnd(ScrollMetrics metrics) =>
      metrics.maxScrollExtent > metrics.minScrollExtent &&
      metrics.pixels >= metrics.maxScrollExtent - StickToEndOnGrow.tolerance;

  bool _onScroll(ScrollNotification notification) {
    if (_watches(notification.depth, notification.metrics)) {
      _atEnd = _isEnd(notification.metrics);
      _lastMaxExtent = notification.metrics.maxScrollExtent;
    }
    return false;
  }

  bool _onMetrics(ScrollMetricsNotification notification) {
    final metrics = notification.metrics;
    if (!_watches(notification.depth, metrics)) return false;
    final last = _lastMaxExtent;
    final grew =
        last != null &&
        metrics.maxScrollExtent > last + StickToEndOnGrow.tolerance;
    _lastMaxExtent = metrics.maxScrollExtent;
    if (grew && _atEnd) {
      final position = Scrollable.maybeOf(notification.context)?.position;
      if (position != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && position.hasPixels && position.hasContentDimensions) {
            position.jumpTo(position.maxScrollExtent);
          }
        });
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
