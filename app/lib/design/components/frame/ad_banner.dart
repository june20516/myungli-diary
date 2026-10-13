import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/core/platform/ads.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';
import 'package:myungli_diary/design/components/component_spec.dart';
import 'package:myungli_diary/design/components/frame/frame_surface.dart';
import 'package:myungli_diary/design/interaction/motion_prefs.dart';
import 'package:myungli_diary/design/interaction/patterns.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

/// 광고 배너의 틀(바탕 제외): 위 0.5px 선, 위아래 `space.4`, region 역할.
///
/// 광고 안은 네트워크가 그리고 그 접근성 노드는 그대로 보입니다(`content: 광고 네트워크가 제공`).
class AdBannerFrame extends StatelessWidget {
  /// 틀을 만듭니다. [child]는 광고 네트워크가 그리는 배너입니다.
  const new({required this.child, super.key});

  /// 광고.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final line = context.tokens.colors.line;
    return Semantics(
      key: const ValueKey('ad-banner.region'),
      container: true,
      explicitChildNodes: true,
      role: SemanticsRole.region,
      label: AppLocalizations.of(context).adBannerLabel,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: line, width: frameTopBorderWidth),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.only(
            top: frameTopBorderWidth + Space.s4,
            bottom: Space.s4,
          ),
          child: Center(heightFactor: 1, child: child),
        ),
      ),
    );
  }
}

/// 탭 첫 화면 하단의 적응형 배너 광고 자리(D53).
///
/// 광고 제거 기간([adFree])이나 동의 전([consentGiven] false)에는 자리를 잡지 않고,
/// 불러오는 중·광고 없음·오류도 자리를 잡지 않습니다. 광고가 오면 바탕은 그대로 두고
/// 배너 내용에만 `appear.seep`을 걸며 높이가 함께 자랍니다.
///
/// 보통은 `MyungliBottomBar`가 탭 바와 한 바탕으로 감싸 씁니다. 혼자 쓰면([ownSurface])
/// 자기 바탕을 가집니다.
///
/// 불러오기가 실패하면 자동으로 다시 시도하지 않습니다. 광고 제거·동의 상태가 바뀌어
/// 배너가 한 번 꺼졌다 켜질 때 다시 시도합니다.
class AdBanner extends ConsumerStatefulWidget {
  /// 배너를 만듭니다.
  const new({
    required this.adFree,
    required this.consentGiven,
    this.ownSurface = true,
    this.onVisibleChanged,
    super.key,
  });

  /// 명세 대조용 요약.
  static const ComponentSpec spec = ComponentSpec('ad-banner', {}, {
    'loading',
    'loaded',
    'noFill',
    'adFree',
    'noConsent',
    'reduceTransparency',
  });

  /// 광고 제거 기간인지(D53).
  final bool adFree;

  /// 광고 동의(ATT·UMP)를 받았는지.
  final bool consentGiven;

  /// true면 자기 반투명 바탕을 가집니다. 하단 틀 안에서는 false.
  final bool ownSurface;

  /// 배너가 화면에 있는지(자리를 차지하는지) 바뀔 때. 위 선이 배너 위에 있는지 정하는 데 씁니다.
  final ValueChanged<bool>? onVisibleChanged;

  @override
  ConsumerState<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends ConsumerState<AdBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _presence = AnimationController(
    vsync: this,
    duration: InteractionPattern.appearSeep.duration,
    reverseDuration: InteractionPattern.disappearSeep.duration,
  )..addStatusListener(_onPresence);
  late final Animation<double> _hide = ReverseAnimation(_presence);

  BannerAdHandle? _handle;
  bool _loading = false;
  bool _failed = false;
  bool _reportedVisible = false;

  bool get _active => !widget.adFree && widget.consentGiven;

  bool get _visible =>
      _handle != null && _presence.status != AnimationStatus.dismissed;

  void _reportVisible() {
    if (_reportedVisible == _visible) return;
    _reportedVisible = _visible;
    widget.onVisibleChanged?.call(_visible);
  }

  void _onPresence(AnimationStatus status) {
    if (status != AnimationStatus.dismissed || !mounted) return;
    // 자리째 사라졌으면 광고를 놓습니다. 다시 켜지면 새로 불러옵니다.
    if (!_active) {
      _handle?.dispose();
      _handle = null;
    }
    setState(() {});
    _reportVisible();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(AdBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    final reduce = MotionPrefs.of(context).reduceMotion;
    _presence
      ..duration = reduce
          ? Duration.zero
          : InteractionPattern.appearSeep.duration
      ..reverseDuration = reduce
          ? Duration.zero
          : InteractionPattern.disappearSeep.duration;
    if (!_active) {
      _failed = false;
      if (_presence.status != AnimationStatus.dismissed) {
        _presence.reverse();
      } else if (_handle != null) {
        _handle!.dispose();
        _handle = null;
      }
      return;
    }
    if (_handle != null) {
      _presence.forward();
    } else if (!_loading && !_failed) {
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    _loading = true;
    final width = MediaQuery.sizeOf(context).width.truncate();
    BannerAdHandle? handle;
    try {
      handle = await ref.read(adsProvider).loadBanner(width: width);
    } on AppError {
      handle = null;
    }
    _loading = false;
    if (!mounted || !_active) {
      handle?.dispose();
      return;
    }
    if (handle == null) {
      _failed = true;
      return;
    }
    setState(() => _handle = handle);
    _presence.forward();
    _reportVisible();
  }

  @override
  void dispose() {
    _presence.dispose();
    _handle?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final handle = _handle;
    if (handle == null || _presence.status == AnimationStatus.dismissed) {
      return const SizedBox.shrink();
    }
    final prefs = MotionPrefs.of(context);
    final content = AnimatedBuilder(
      animation: _presence,
      builder: (context, child) {
        final hiding = _presence.status == AnimationStatus.reverse;
        return SizeTransition(
          sizeFactor: _presence.drive(CurveTween(curve: Motion.seep)),
          alignment: Alignment.bottomCenter,
          // 바탕(흐림)은 그대로 두고 배너 내용에만 나타남·사라짐을 겁니다.
          child: animate(
            hiding
                ? InteractionPattern.disappearSeep
                : InteractionPattern.appearSeep,
            t: hiding ? _hide : _presence,
            prefs: prefs,
            child: child!,
          ),
        );
      },
      child: AdBannerFrame(
        child: SizedBox.fromSize(size: handle.size, child: handle.view),
      ),
    );
    if (!widget.ownSurface) return content;
    return FrameSurface(
      surfaceKey: const ValueKey('ad-banner.surface'),
      child: content,
    );
  }
}
