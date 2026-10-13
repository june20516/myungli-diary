import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/core/platform/ads.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';
import 'package:myungli_diary/design/components/component_spec.dart';
import 'package:myungli_diary/design/components/frame/tab_bar.dart';
import 'package:myungli_diary/design/interaction/motion_prefs.dart';
import 'package:myungli_diary/design/interaction/patterns.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

/// 광고 배너의 틀: 탭 바와 같은 반투명 바탕·뒤 흐림, 위 0.5px 선, 위아래 `space.4`.
///
/// 광고 안은 네트워크가 그립니다. 탭 바 바로 위에 붙이고 탭 바는 `topBorder: false`로 둡니다.
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
      role: SemanticsRole.region,
      label: AppLocalizations.of(context).adBannerLabel,
      child: FrameSurface(
        surfaceKey: const ValueKey('ad-banner.surface'),
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
            child: Center(
              heightFactor: 1,
              child: ExcludeSemantics(child: child),
            ),
          ),
        ),
      ),
    );
  }
}

/// 탭 첫 화면 하단의 적응형 배너 광고 자리(D53).
///
/// 광고 제거 기간([adFree])이나 동의 전([consentGiven] false)에는 자리를 잡지 않고,
/// 불러오는 중·광고 없음·오류도 자리를 잡지 않습니다. 광고가 오면 `appear.seep`으로
/// 나타나며 높이가 함께 자랍니다.
class AdBanner extends ConsumerStatefulWidget {
  /// 배너를 만듭니다.
  const new({required this.adFree, required this.consentGiven, super.key});

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

  bool get _active => !widget.adFree && widget.consentGiven;

  void _onPresence(AnimationStatus status) {
    // 자리째 사라진 뒤에 비로소 틀을 걷어 냅니다.
    if (status == AnimationStatus.dismissed && mounted) setState(() {});
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
    if (!mounted) {
      handle?.dispose();
      return;
    }
    if (handle == null) {
      _failed = true;
      return;
    }
    setState(() => _handle = handle);
    if (_active) _presence.forward();
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
    return AnimatedBuilder(
      animation: _presence,
      builder: (context, child) {
        final hiding = _presence.status == AnimationStatus.reverse;
        return SizeTransition(
          sizeFactor: _presence.drive(CurveTween(curve: Motion.seep)),
          alignment: Alignment.bottomCenter,
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
  }
}
