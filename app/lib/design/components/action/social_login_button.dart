import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/action/breathing_dots.dart';
import 'package:myungli_diary/design/components/component_spec.dart';
import 'package:myungli_diary/design/components/sentence/press_ink_target.dart';
import 'package:myungli_diary/design/components/sentence/vertical_hit_slop.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

/// 소셜 로그인 제공자(`social-login-button` `variants`).
enum SocialProvider {
  /// 카카오 로그인. 목록에서 위입니다.
  kakao,

  /// Apple로 로그인. 목록에서 아래입니다(iOS·Android 모두, Android는 웹 흐름).
  apple,
}

/// 소셜 로그인 버튼(`social-login-button`).
///
/// 색·로고·문구는 각 제공자의 공식 가이드와 공식 자산(`assets/brand/`)을 따르고
/// 아이콘 세트를 쓰지 않습니다. 이 명세가 정하는 것은 반경(`radius.md`)·높이(52, 최소값이라
/// 큰 글자에서 면이 커짐)·너비(채움)뿐입니다. 순서(카카오 위, Apple 아래)와 두 버튼의 같은
/// 크기는 화면이 정합니다. Apple은 라이트에서 검정, 다크에서 흰색입니다.
///
/// [onPressed]가 null이면 눌리지 않고 흐리게 보이며, [loading]이면 글자 자리에 점 세 개가
/// 숨 쉬고(`loading.breathe`) 다시 눌리지 않습니다. 눌림은 `press.ink`입니다.
class SocialLoginButton extends StatelessWidget {
  /// 버튼을 만듭니다. [label]은 제공자 공식 문구("카카오 로그인", "Apple로 로그인")입니다.
  /// [animated]가 false면 점이 정지 상태로 그려집니다(golden).
  const new({
    required this.provider,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.identifier,
    this.animated = true,
    super.key,
  });

  /// 명세 대조용 요약.
  static const ComponentSpec spec = ComponentSpec(
    'social-login-button',
    {'kakao', 'apple'},
    {'pressed', 'loading'},
  );

  /// 버튼 면을 찾는 테스트용 키.
  static const Key faceKey = ValueKey('social-login-button-face');

  /// 처리 중 점을 찾는 테스트용 키.
  static const Key dotsKey = ValueKey('social-login-button-dots');

  // 카카오 로그인 디자인 가이드: 컨테이너 #FEE500, 레이블 #000000 85%.
  static const Color _kakaoContainer = Color(0xFFFEE500);
  static const Color _kakaoLabel = Color(0xD9000000);
  // Sign in with Apple HIG: 검정 버튼은 흰 로고·글자, 흰 버튼은 검정 로고·글자.
  static const Color _appleBlack = Color(0xFF000000);
  static const Color _appleWhite = Color(0xFFFFFFFF);

  static const String _kakaoSymbol = 'assets/brand/kakao/kakao_symbol.svg';
  static const String _appleLogoBlack =
      'assets/brand/apple/apple_logo_black.svg';
  static const String _appleLogoWhite =
      'assets/brand/apple/apple_logo_white.svg';

  static const double _minHeight = 52;
  static const double _minTarget = 48;
  static const double _logoSize = 20;
  static const double _dotSize = 6;
  static const double _dotGap = 6;
  static const double _disabledOpacity = 0.4;

  /// 제공자.
  final SocialProvider provider;

  /// 제공자 공식 문구.
  final String label;

  /// 눌렀을 때. null이면 꺼짐입니다.
  final VoidCallback? onPressed;

  /// 처리 중. 글자를 숨기고 점을 보이며 누름을 무시합니다.
  final bool loading;

  /// IA 슬롯 id. 있으면 Semantics `identifier`로 붙입니다.
  final String? identifier;

  /// false면 점이 숨 쉬지 않고 정지 상태로 그립니다.
  final bool animated;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final (bg, fg, logo) = switch (provider) {
      SocialProvider.kakao => (_kakaoContainer, _kakaoLabel, _kakaoSymbol),
      SocialProvider.apple when dark => (
        _appleWhite,
        _appleBlack,
        _appleLogoBlack,
      ),
      SocialProvider.apple => (_appleBlack, _appleWhite, _appleLogoWhite),
    };
    const radius = BorderRadius.all(Radius.circular(Radii.md));
    final labelStyle = context.tokens.typography.labelLg.copyWith(color: fg);

    final face = DecoratedBox(
      key: faceKey,
      decoration: BoxDecoration(color: bg, borderRadius: radius),
      child: ConstrainedBox(
        // 명세 높이는 최소값입니다. 글자 배율이 크면 잘리지 않고 면이 커집니다.
        constraints: const BoxConstraints(minHeight: _minHeight),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Space.s20,
            vertical: Space.s8,
          ),
          child: Center(
            heightFactor: 1,
            child: loading
                ? BreathingDots(
                    key: dotsKey,
                    color: fg,
                    animated: animated,
                    count: 3,
                    size: _dotSize,
                    gap: _dotGap,
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: Space.s8,
                    children: [
                      SvgPicture.asset(
                        logo,
                        width: _logoSize,
                        height: _logoSize,
                      ),
                      Flexible(
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          style: labelStyle,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
    final wide = SizedBox(width: double.infinity, child: face);

    if (onPressed == null || loading) {
      final busyText = AppLocalizations.of(context).actionBusy;
      return Semantics(
        container: true,
        button: true,
        enabled: false,
        identifier: identifier,
        label: loading ? busyText : label,
        child: ExcludeSemantics(
          child: loading
              ? wide
              : Opacity(opacity: _disabledOpacity, child: wide),
        ),
      );
    }
    return VerticalHitSlop(
      minHeight: _minTarget,
      child: PressInkTarget(
        semanticLabel: label,
        identifier: identifier,
        onTap: onPressed!,
        borderRadius: radius,
        inkColor: fg,
        child: wide,
      ),
    );
  }
}
