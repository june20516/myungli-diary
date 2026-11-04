import 'dart:async';

import 'package:flutter/material.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/platform/ads.dart';
import 'package:myungli_diary/design/elements/app_icon.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';
import 'package:phosphor_glyphs/phosphor_glyphs.dart';

/// 이 빌드가 staging 환경(`config/env/staging.json`의 `STAGING_ADS`)인지(D101 ①).
///
/// staging이면 광고를 받지 못할 때 모의 광고로 넘어가고(③), 보상형 광고를 끝까지 본 뒤 staging
/// 전용 경로로 보상을 보냅니다(④). prod 환경 파일에는 이 값이 없어 false이고, 상수 접힘으로
/// staging 분기가 prod 바이너리에서 빠집니다(②).
const bool stagingAdsBuild = bool.fromEnvironment('STAGING_ADS');

/// 모의 보상형 광고를 끝까지 보는 시간(기본값). 이만큼 지나야 보상이 생깁니다.
const Duration mockRewardedLength = Duration(seconds: 15);

/// 모의 광고 표시 글자(언어별). staging 전용 화면이라 원고 대상이 아니고 prod 바이너리에
/// 없습니다(D101 ③).
String _mockAdLabel(Locale locale) => switch (locale.languageCode) {
  'ko' => '모의 광고',
  'ja' => 'モック広告',
  _ => 'Mock ad',
};

const AppGlyph _closeGlyph = AppGlyph(
  light: PhosphorIconsLight.x,
  regular: PhosphorIconsRegular.x,
);

/// staging 광고(D101 ③). [real](AdMob)을 먼저 불러오고, 광고를 받지 못하면(채울 광고 없음,
/// 앱 검토 전, 그 밖의 불러오기 실패) 같은 자리, 같은 크기, 같은 상태 흐름의 모의 광고를 줍니다.
///
/// 오프라인([OfflineError])은 실제 광고처럼 그대로 실패로 둡니다. 동의 전이나 지원하지 않는
/// 플랫폼처럼 [real]이 광고 요청 자체를 하지 않을 때도 null이 와 모의 광고로 넘어가므로, 모의
/// 광고는 staging에서만 씁니다.
final class StagingAds implements Ads {
  /// staging 광고를 만듭니다. [navigator]는 모의 보상형 광고를 띄울 Navigator를 찾습니다.
  new({
    required this.real,
    required this.navigator,
    required this.bannerSize,
    this.rewardedLength = mockRewardedLength,
  });

  /// 먼저 부르는 실제 광고.
  final Ads real;

  /// 모의 보상형 광고를 띄울 Navigator. 없으면 모의 광고를 보이지 못합니다.
  final NavigatorState? Function() navigator;

  /// 너비를 받아 적응형 배너의 크기(실제 광고와 같은 크기)를 줍니다. 정하지 못하면 null입니다.
  final Future<Size?> Function(int width) bannerSize;

  /// 모의 보상형 광고를 끝까지 보는 시간.
  final Duration rewardedLength;

  @override
  Future<BannerAdHandle?> loadBanner({required int width}) async {
    final loaded = await _orNull(() => real.loadBanner(width: width));
    if (loaded != null) return loaded;
    final size = await bannerSize(width);
    return MockBannerHandle(size ?? Size(width.toDouble(), 60));
  }

  @override
  Future<RewardedAdHandle?> loadRewarded({required String userId}) async {
    final loaded = await _orNull(() => real.loadRewarded(userId: userId));
    return loaded ??
        MockRewardedHandle(navigator: navigator, length: rewardedLength);
  }

  /// [load]의 결과. 오프라인은 그대로 던지고, 다른 실패는 null(모의 광고로 넘어감)입니다.
  Future<T?> _orNull<T>(Future<T?> Function() load) async {
    try {
      return await load();
    } on OfflineError {
      rethrow;
    } on AppError {
      return null;
    }
  }
}

/// 모의 배너 광고(D101 ③). 실제 배너와 같은 크기에 "모의 광고" 표시를 그립니다.
final class MockBannerHandle implements BannerAdHandle {
  /// [size] 크기의 모의 배너.
  new(this.size);

  @override
  final Size size;

  @override
  Widget get view => const MockBannerAd();

  @override
  void dispose() {}
}

/// 모의 배너의 그림.
class MockBannerAd extends StatelessWidget {
  /// 모의 배너를 만듭니다.
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final label = _mockAdLabel(Localizations.localeOf(context));
    return Semantics(
      container: true,
      label: label,
      child: ExcludeSemantics(
        child: ColoredBox(
          color: tokens.colors.chipBg,
          child: Center(
            child: Text(
              label,
              style: tokens.typography.captionMd.copyWith(
                color: tokens.colors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 모의 보상형 광고(D101 ③). 전체 화면으로 [length] 동안 보이고, 끝까지 보면 보상입니다.
/// 그 전에 닫으면 보상 없이 닫힙니다. 한 번 보이면 다시 쓰지 않습니다.
final class MockRewardedHandle implements RewardedAdHandle {
  /// 모의 보상형 광고를 만듭니다.
  new({required this.navigator, required this.length});

  /// 띄울 Navigator를 찾습니다.
  final NavigatorState? Function() navigator;

  /// 끝까지 보는 시간.
  final Duration length;

  @override
  Future<RewardedResult> show() async {
    final state = navigator();
    if (state == null) {
      return RewardFailed(
        UnexpectedError(StateError('모의 광고를 띄울 Navigator가 없습니다')),
      );
    }
    final earned = await state.push<bool>(
      PageRouteBuilder<bool>(
        fullscreenDialog: true,
        pageBuilder: (_, _, _) => MockRewardedAdPage(length: length),
      ),
    );
    return earned ?? false
        ? const RewardEarned(
            adUnit: RewardEarned.mockAdUnit,
            rewardItem: 'insight',
          )
        : const RewardDismissed();
  }
}

/// 모의 보상형 광고 화면. [length]가 지나면 보상이 생기고, 닫으면 그 여부(`bool`)로 끝납니다.
class MockRewardedAdPage extends StatefulWidget {
  /// 화면을 만듭니다.
  const new({required this.length, super.key});

  /// 끝까지 보는 시간.
  final Duration length;

  /// 닫기 버튼을 찾는 테스트용 키.
  static const Key closeKey = ValueKey('mock-rewarded.close');

  /// 남은 초를 찾는 테스트용 키.
  static const Key remainingKey = ValueKey('mock-rewarded.remaining');

  @override
  State<MockRewardedAdPage> createState() => _MockRewardedAdPageState();
}

class _MockRewardedAdPageState extends State<MockRewardedAdPage> {
  late int _remaining = widget.length.inSeconds;
  Timer? _tick;

  bool get _earned => _remaining <= 0;

  @override
  void initState() {
    super.initState();
    if (!_earned) {
      _tick = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() => _remaining--);
        if (_earned) timer.cancel();
      });
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  void _close() => Navigator.of(context).pop(_earned);

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final label = _mockAdLabel(Localizations.localeOf(context));
    final onSurface = tokens.colors.actionOnPrimary;
    return PopScope<bool>(
      canPop: false,
      // 뒤로 가기도 닫기와 같습니다(보았는지는 그때까지로 정함).
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        backgroundColor: tokens.colors.actionPrimary,
        body: SafeArea(
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  spacing: Space.s12,
                  children: [
                    Text(
                      label,
                      style: tokens.typography.title.copyWith(color: onSurface),
                    ),
                    Text(
                      _earned ? '✓' : '$_remaining',
                      key: MockRewardedAdPage.remainingKey,
                      style: tokens.typography.numericTable.copyWith(
                        color: onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              PositionedDirectional(
                top: Space.s8,
                end: Space.s8,
                child: IconButton(
                  key: MockRewardedAdPage.closeKey,
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  onPressed: _close,
                  icon: AppIcon(_closeGlyph, color: onSurface),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
