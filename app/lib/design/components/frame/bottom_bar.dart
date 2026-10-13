import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:myungli_diary/design/components/frame/ad_banner.dart';
import 'package:myungli_diary/design/components/frame/frame_surface.dart';
import 'package:myungli_diary/design/components/frame/tab_bar.dart';

/// 하단 틀: 탭 바와 (탭 첫 화면에서는) 광고 배너를 한 바탕으로 묶습니다.
///
/// 바탕과 뒤 흐림은 하나이고, 위 0.5px 선은 배너가 실제로 보이면 배너 위, 아니면 탭 바 위에
/// 하나만 놓입니다. 전체 높이(탭 바 + 안전 영역 + 배너)가 바뀌면 [onHeightChanged]가 불려
/// 화면 셸이 맨 아래 여백과 스크롤 위치를 맞출 수 있습니다.
class MyungliBottomBar extends StatefulWidget {
  /// 하단 틀을 만듭니다. [showAd]는 탭 루트 화면(today·calendar·diary-list·my-saju)만 true.
  const new({
    required this.index,
    required this.onSelect,
    required this.showAd,
    required this.adFree,
    required this.consentGiven,
    this.onScrollToTop,
    this.onHeightChanged,
    super.key,
  });

  /// 선택된 탭.
  final int index;

  /// 선택이 바뀔 때.
  final ValueChanged<int> onSelect;

  /// 선택된 탭을 다시 눌렀을 때.
  final VoidCallback? onScrollToTop;

  /// 배너 자리를 둘지(탭 루트 화면만).
  final bool showAd;

  /// 광고 제거 기간인지.
  final bool adFree;

  /// 광고 동의를 받았는지.
  final bool consentGiven;

  /// 전체 높이가 바뀔 때(프레임이 끝난 뒤, 안전 영역 포함).
  final ValueChanged<double>? onHeightChanged;

  @override
  State<MyungliBottomBar> createState() => _MyungliBottomBarState();
}

class _MyungliBottomBarState extends State<MyungliBottomBar> {
  bool _adVisible = false;

  @override
  Widget build(BuildContext context) {
    return _HeightReporter(
      onHeight: widget.onHeightChanged,
      child: FrameSurface(
        surfaceKey: const ValueKey('bottom-bar.surface'),
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewPaddingOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.showAd)
                AdBanner(
                  adFree: widget.adFree,
                  consentGiven: widget.consentGiven,
                  ownSurface: false,
                  onVisibleChanged: (visible) =>
                      setState(() => _adVisible = visible),
                ),
              TabBarRow(
                index: widget.index,
                onSelect: widget.onSelect,
                onScrollToTop: widget.onScrollToTop,
                topBorder: !(widget.showAd && _adVisible),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 자식 높이가 바뀌면 프레임이 끝난 뒤 알립니다.
class _HeightReporter extends SingleChildRenderObjectWidget {
  const new({required this.onHeight, required super.child});

  final ValueChanged<double>? onHeight;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderHeightReporter(onHeight);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderHeightReporter renderObject,
  ) => renderObject.onHeight = onHeight;
}

class _RenderHeightReporter extends RenderProxyBox {
  new(this.onHeight);

  ValueChanged<double>? onHeight;
  double? _last;

  @override
  void performLayout() {
    super.performLayout();
    final height = size.height;
    if (height == _last) return;
    _last = height;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (attached) onHeight?.call(height);
    });
  }
}
