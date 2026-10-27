import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/core/platform/social_provider.dart';
import 'package:myungli_diary/design/components/action/breathing_dots.dart';
import 'package:myungli_diary/design/components/component_spec.dart';
import 'package:myungli_diary/design/components/sentence/press_ink_target.dart';
import 'package:myungli_diary/design/components/sentence/vertical_hit_slop.dart';
import 'package:myungli_diary/design/elements/breathing.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';
import 'package:phosphor_glyphs/phosphor_glyphs.dart';

/// `SocialProvider`는 플랫폼 계층이 소유하고, 기존 import가 그대로 동작하도록 다시 내보냅니다.
export 'package:myungli_diary/core/platform/social_provider.dart';

/// Google 버튼 테마 한 벌(Google Sign-In branding의 light·dark 테마).
@immutable
final class GoogleButtonTheme {
  /// 바탕·안쪽 테두리·글자 색으로 만듭니다.
  const new({
    required this.background,
    required this.border,
    required this.foreground,
  });

  /// 바탕.
  final Color background;

  /// 안쪽 1px 테두리.
  final Color border;

  /// 글자.
  final Color foreground;
}

/// 소셜 로그인 버튼(`social-login-button`).
///
/// 색·로고·문구는 각 제공자의 공식 가이드와 공식 자산(`assets/brand/`)을 따르고 아이콘 세트를
/// 쓰지 않습니다. 이 명세가 정하는 것은 반경(`radius.md`)·높이(52, 최소값이라 큰 글자에서 면이
/// 커짐)·너비(채움)와 로고 자리(왼쪽 안쪽 16에 20px 고정, 글자는 가운데)입니다. 순서와 네 버튼의
/// 같은 크기는 화면이 정합니다.
///
/// * `kakao`: 카카오 로그인 디자인 가이드.
/// * `line`: LINE Login button 가이드. 로고와 글자 사이 세로 구분선, 눌림은 검정 30% 덮개,
///   꺼짐은 가이드의 흰 바탕·테두리·글자색입니다(버튼 전체를 흐리지 않음).
/// * `google`: Google Sign-In branding. 라이트 화면은 light 테마, 다크 화면은 dark 테마이고
///   글자는 Google Sans Medium 14/20 대신 시스템 글꼴입니다(앱에 Google Sans가 없음).
/// * `apple`: Sign in with Apple HIG. 라이트에서 검정, 다크에서 흰색이고 글자는 시스템 글꼴 +
///   `type.label.lg`입니다.
///
/// [onPressed]가 null이면 `disabled`(다른 버튼이 처리 중)라 눌리지 않고, `line` 밖의 제공자는
/// 색을 바꿀 수 없으므로 버튼 전체를 `opacity 0.4`로 흐립니다. [loading]이면 글자 자리에 점 세
/// 개가 숨 쉬고(`loading.breathe`) 다시 눌리지 않습니다. 눌림은 `press.ink`입니다.
///
/// [connected]면 로그인 수단 화면(`login-methods`)의 연결됨 줄입니다(결정 V39). 제공자 색 없이
/// `bg.sheet` 바탕 + `line` 테두리에 제공자 색 배지 로고, 제공자 이름([label]), 끝에 `check`와
/// [connectedLabel]을 둡니다. 누르면 떼기 확인을 여는 것은 화면의 몫입니다. 이때 [onPressed]가
/// null이면 마지막 남은 수단이라 누를 수 없고 모양은 그대로이며(버튼 역할·힌트 없음), 다른 버튼이
/// 처리 중일 때 흐리는 것은 [disabled]입니다. [loading]이면 줄 전체가 숨쉽니다(떼는 중).
class SocialLoginButton extends StatelessWidget {
  /// 버튼을 만듭니다. [label]은 제공자 공식 문구("카카오 로그인", "LINE으로 로그인")이고,
  /// [connected]면 제공자 이름("카카오")입니다. [animated]가 false면 점·숨쉬기가 정지 상태로
  /// 그려집니다(golden).
  const new({
    required this.provider,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.connected = false,
    this.connectedLabel,
    this.unlinkHint,
    this.disabled = false,
    this.identifier,
    this.animated = true,
    this.systemFontFamily,
    super.key,
  }) : assert(
         !connected || connectedLabel != null,
         'connected 줄에는 connectedLabel("연결됨")이 있어야 합니다.',
       );

  /// 명세 대조용 요약.
  static const ComponentSpec spec = ComponentSpec(
    'social-login-button',
    {'kakao', 'line', 'google', 'apple'},
    {'pressed', 'loading', 'disabled', 'connected'},
  );

  /// 버튼 면을 찾는 테스트용 키.
  static const Key faceKey = ValueKey('social-login-button-face');

  /// 처리 중 점을 찾는 테스트용 키.
  static const Key dotsKey = ValueKey('social-login-button-dots');

  /// `line` 구분선을 찾는 테스트용 키.
  static const Key separatorKey = ValueKey('social-login-button-separator');

  /// `connected` 로고 배지를 찾는 테스트용 키.
  static const Key badgeKey = ValueKey('social-login-button-badge');

  /// `connected` `loading`의 숨쉬는 줄을 찾는 테스트용 키.
  static const Key breathingKey = ValueKey('social-login-button-breathing');

  // 카카오 로그인 디자인 가이드: 컨테이너 #FEE500, 레이블 #000000 85%.
  static const Color _kakaoContainer = Color(0xFFFEE500);
  static const Color _kakaoLabel = Color(0xD9000000);
  // Sign in with Apple HIG: 검정 버튼은 흰 로고·글자, 흰 버튼은 검정 로고·글자.
  static const Color _appleBlack = Color(0xFF000000);
  static const Color _appleWhite = Color(0xFFFFFFFF);

  /// `connected` 카카오 배지 바탕(`badge.kakao.bg`).
  static const Color kakaoBadge = _kakaoContainer;

  /// `connected` 카카오 배지 안 심볼 색(`badge.kakao.symbol`). 공식 심볼 자산
  /// (`assets/brand/kakao/kakao_symbol.svg`)의 색과 같습니다.
  static const Color kakaoBadgeSymbol = Color(0xFF191919);

  /// LINE 바탕(`variants.line.parts.container.bg`). `connected` 배지 바탕도 같습니다.
  static const Color lineBackground = Color(0xFF06C755);

  /// LINE 글자·로고.
  static const Color lineForeground = Color(0xFFFFFFFF);

  /// LINE 로고와 글자 사이 세로 구분선(검정 8%).
  static const Color lineSeparator = Color.from(
    alpha: 0.08,
    red: 0,
    green: 0,
    blue: 0,
  );

  /// LINE 눌림 덮개(검정 30%).
  static const Color linePressedOverlay = Color.from(
    alpha: 0.3,
    red: 0,
    green: 0,
    blue: 0,
  );

  /// LINE 꺼짐 바탕.
  static const Color lineDisabledBackground = Color(0xFFFFFFFF);

  /// LINE 꺼짐 테두리·구분선(#E5E5E5 60%).
  static const Color lineDisabledBorder = Color.from(
    alpha: 0.6,
    red: 0xE5 / 255,
    green: 0xE5 / 255,
    blue: 0xE5 / 255,
  );

  /// LINE 꺼짐 글자·로고(#1E1E1E 20%).
  static const Color lineDisabledForeground = Color.from(
    alpha: 0.2,
    red: 0x1E / 255,
    green: 0x1E / 255,
    blue: 0x1E / 255,
  );

  /// Google light 테마(라이트 화면).
  static const GoogleButtonTheme googleLight = GoogleButtonTheme(
    background: Color(0xFFFFFFFF),
    border: Color(0xFF747775),
    foreground: Color(0xFF1F1F1F),
  );

  /// Google dark 테마(다크 화면).
  static const GoogleButtonTheme googleDark = GoogleButtonTheme(
    background: Color(0xFF131314),
    border: Color(0xFF8E918F),
    foreground: Color(0xFFE3E3E3),
  );

  /// Google 안쪽 테두리 두께.
  static const double googleBorderWidth = 1;

  /// Google 글자 크기(Google Sans Medium 14/20).
  static const double googleFontSize = 14;

  /// Google 글자 줄 높이.
  static const double googleLineHeight = 20;

  /// 로고 크기(`parts.logo.size`).
  static const double logoSize = 20;

  /// 로고의 왼쪽 안쪽 여백(`parts.logo.inset`, `space.16`).
  static const double logoInset = Space.s16;

  /// `connected` 로고 배지 크기.
  static const double badgeSize = 20;

  /// `connected` 배지 안 심볼 크기.
  static const double badgeSymbolSize = 14;

  /// `connected` 끝의 `check` 아이콘 크기.
  static const double connectedIconSize = 14;

  /// `connected` `check`와 "연결됨" 사이(`state.gap`, `space.4`).
  static const double connectedStateGap = Space.s4;

  /// `connected` 줄 끝 안쪽 여백(`state.inset`, `space.16`).
  static const double connectedEndInset = Space.s16;

  /// `connected` 배지 바탕(`badge.<제공자>.bg`). Apple만 밝기에 따라 바뀝니다.
  static Color badgeColor(SocialProvider provider, {required bool dark}) =>
      switch (provider) {
        SocialProvider.kakao => kakaoBadge,
        SocialProvider.line => lineBackground,
        SocialProvider.google => googleLight.background,
        SocialProvider.apple => dark ? _appleWhite : _appleBlack,
      };

  /// `connected` 배지가 원(`radius.full`)인지. Google만 흰 원이고 나머지는 `radius.xs`입니다.
  static bool badgeIsCircle(SocialProvider provider) =>
      provider == SocialProvider.google;

  /// `disabled` 버튼 전체 투명도(명세 `states.disabled.parts.container.opacity`).
  static const double disabledOpacity = 0.4;

  static const String _kakaoSymbol = 'assets/brand/kakao/kakao_symbol.svg';
  static const String _appleLogoBlack =
      'assets/brand/apple/apple_logo_black.svg';
  static const String _appleLogoWhite =
      'assets/brand/apple/apple_logo_white.svg';
  static const String _lineIcon = 'assets/brand/line/line_icon.png';
  static const String _googleLogoLight = 'assets/brand/google/g_logo_light.png';
  static const String _googleLogoDark = 'assets/brand/google/g_logo_dark.png';

  static const double _minHeight = 52;
  static const double _minTarget = 48;

  /// 글자 양옆에 비우는 폭. 로고가 왼쪽에 고정돼 있어 글자가 가운데에 오도록 양쪽을 같이
  /// 비웁니다(로고 안쪽 16 + 로고 20 + 간격 8, 글자 수 상한 232px의 근거).
  static const double labelInset = logoInset + logoSize + Space.s8;

  /// LINE 구분선 자리. 공식 자산(`btn_login_base`)은 버튼 높이만 한 정사각 칸 가운데에 아이콘을
  /// 두고 그 칸 오른쪽 끝에 1px 구분선을 긋습니다. 높이 52에서 로고(16~36)가 가운데인 칸의 끝이
  /// 52입니다.
  static const double _lineSeparatorStart = _minHeight;

  /// LINE 글자 양옆 폭. 글자가 구분선에 닿지 않게 구분선 뒤 `space.8`까지 비웁니다.
  static const double lineLabelInset = _lineSeparatorStart + 1 + Space.s8;

  /// 명세가 글자 자리를 재는 버튼 폭(`parts.label.width`의 기준).
  static const double referenceWidth = 320;

  /// [provider] 버튼의 글자 자리 폭(`parts.label.width`): LINE 198, 나머지 232.
  static double labelWidth(
    SocialProvider provider, {
    double buttonWidth = referenceWidth,
  }) =>
      buttonWidth -
      2 * (provider == SocialProvider.line ? lineLabelInset : labelInset);

  /// 제공자.
  final SocialProvider provider;

  /// 제공자 공식 문구. [connected]면 제공자 이름입니다.
  final String label;

  /// 눌렀을 때. null이면 꺼짐이고, [connected]면 마지막 남은 수단이라 누를 수 없음입니다.
  final VoidCallback? onPressed;

  /// 처리 중. 글자를 숨기고 점을 보이며 누름을 무시합니다. [connected]면 줄 전체가 숨쉽니다.
  final bool loading;

  /// 로그인 수단 화면의 연결됨 줄(`connected`).
  final bool connected;

  /// [connected] 줄 끝의 "연결됨"(`loginMethodsRowConnected`).
  final String? connectedLabel;

  /// [connected] 줄의 스크린리더 힌트("연결 끊기", `loginMethodsRowUnlink`).
  final String? unlinkHint;

  /// 다른 버튼이 처리 중이라 꺼짐(`disabled`). [connected]가 아니면 [onPressed] null과 같습니다.
  final bool disabled;

  /// IA 슬롯 id. 있으면 Semantics `identifier`로 붙입니다.
  final String? identifier;

  /// false면 점·숨쉬기가 정지 상태로 그립니다.
  final bool animated;

  /// Apple·Google 글자의 글꼴. null이면 플랫폼 기본(시스템) 글꼴입니다. 테스트·golden에는
  /// 시스템 글꼴이 없어 대신 쓸 글꼴을 줍니다.
  final String? systemFontFamily;

  static const BorderRadius _radius = BorderRadius.all(
    Radius.circular(Radii.md),
  );

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return connected
        ? _buildConnected(context, dark: dark)
        : _buildButton(context, dark: dark);
  }

  Widget _buildButton(BuildContext context, {required bool dark}) {
    final off = onPressed == null || disabled;
    final look = _lookOf(context, dark: dark, off: off);

    Widget wide({required bool pressed}) => SizedBox(
      width: double.infinity,
      child: _face(look, dark: dark, pressed: pressed),
    );

    if (off || loading) {
      final busyText = AppLocalizations.of(context).actionBusy;
      final face = wide(pressed: false);
      return Semantics(
        container: true,
        button: true,
        enabled: false,
        identifier: identifier,
        label: loading ? busyText : label,
        child: ExcludeSemantics(
          // LINE 꺼짐은 가이드의 꺼짐 색을 쓰므로 흐리지 않습니다.
          child: loading || provider == SocialProvider.line
              ? face
              : Opacity(opacity: disabledOpacity, child: face),
        ),
      );
    }
    if (provider == SocialProvider.line) {
      return VerticalHitSlop(
        minHeight: _minTarget,
        // 눌림은 `press.ink` 대신 가이드의 덮개라 눌림 상태만 받아 면을 다시 그립니다.
        child: PressInkTarget.pressed(
          semanticLabel: label,
          identifier: identifier,
          onTap: onPressed,
          builder: wide,
        ),
      );
    }
    return VerticalHitSlop(
      minHeight: _minTarget,
      child: PressInkTarget(
        semanticLabel: label,
        identifier: identifier,
        onTap: onPressed,
        borderRadius: _radius,
        inkColor: look.foreground,
        child: wide(pressed: false),
      ),
    );
  }

  /// 제공자·밝기·꺼짐에 맞는 색과 글자 모양.
  _Look _lookOf(BuildContext context, {required bool dark, required bool off}) {
    final labelToken = context.tokens.typography.labelLg;
    // Apple HIG와 Google 가이드는 버튼 글자를 각자의 글꼴로 쓰게 합니다. 앱 글꼴을 상속하지 않고
    // (`inherit: false`) 플랫폼 기본 글꼴로 그립니다. Apple은 크기·굵기·줄 높이를 명세의
    // label.lg로, Google은 가이드의 Medium 14/20으로 둡니다.
    TextStyle system(Color color) => TextStyle(
      inherit: false,
      fontFamily: systemFontFamily,
      fontSize: labelToken.fontSize,
      fontWeight: labelToken.fontWeight,
      height: labelToken.height,
      letterSpacing: labelToken.letterSpacing,
      color: color,
    );
    switch (provider) {
      case SocialProvider.kakao:
        return _Look(
          background: _kakaoContainer,
          foreground: _kakaoLabel,
          labelStyle: labelToken.copyWith(color: _kakaoLabel),
        );
      case SocialProvider.line:
        final foreground = off ? lineDisabledForeground : lineForeground;
        return _Look(
          background: off ? lineDisabledBackground : lineBackground,
          foreground: foreground,
          border: off ? lineDisabledBorder : null,
          labelStyle: labelToken.copyWith(color: foreground),
        );
      case SocialProvider.google:
        final theme = dark ? googleDark : googleLight;
        return _Look(
          background: theme.background,
          foreground: theme.foreground,
          border: theme.border,
          labelStyle: TextStyle(
            inherit: false,
            fontFamily: systemFontFamily,
            fontSize: googleFontSize,
            fontWeight: FontWeight.w500,
            height: googleLineHeight / googleFontSize,
            color: theme.foreground,
          ),
        );
      case SocialProvider.apple:
        final foreground = dark ? _appleBlack : _appleWhite;
        return _Look(
          background: dark ? _appleWhite : _appleBlack,
          foreground: foreground,
          labelStyle: system(foreground),
        );
    }
  }

  Widget _face(_Look look, {required bool dark, required bool pressed}) {
    final line = provider == SocialProvider.line;
    final off = onPressed == null || disabled;
    // LINE 눌림 덮개는 바탕 바로 위에 얹고, 그 위에 구분선·글자·로고를 둡니다(가이드 층 순서).
    final background = pressed
        ? Color.alphaBlend(linePressedOverlay, look.background)
        : look.background;
    final border = look.border;
    return DecoratedBox(
      key: faceKey,
      decoration: BoxDecoration(
        color: background,
        borderRadius: _radius,
        // 테두리는 안쪽 1px입니다(Google `borderAlign: inside`, [googleBorderWidth]와 같은
        // `Border.all` 기본값). LINE 꺼짐 테두리도 같습니다.
        border: border == null ? null : Border.all(color: border),
      ),
      child: ConstrainedBox(
        // 명세 높이는 최소값입니다. 글자 배율이 크면 잘리지 않고 면이 커집니다.
        constraints: const BoxConstraints(minHeight: _minHeight),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: line ? lineLabelInset : labelInset,
                vertical: Space.s8,
              ),
              child: loading
                  ? BreathingDots(
                      key: dotsKey,
                      color: look.foreground,
                      animated: animated,
                      count: BreathingDots.standardCount,
                      size: BreathingDots.standardSize,
                      gap: BreathingDots.standardGap,
                    )
                  : Text(
                      label,
                      textAlign: TextAlign.center,
                      style: look.labelStyle,
                    ),
            ),
            if (!loading) ...[
              PositionedDirectional(
                start: logoInset,
                top: 0,
                bottom: 0,
                child: Center(
                  child: _logo(
                    size: logoSize,
                    dark: dark,
                    tint: line && off ? lineDisabledForeground : null,
                  ),
                ),
              ),
              if (line)
                PositionedDirectional(
                  start: _lineSeparatorStart,
                  top: 0,
                  bottom: 0,
                  width: 1,
                  child: ColoredBox(
                    key: separatorKey,
                    color: off ? lineDisabledBorder : lineSeparator,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  /// 공식 로고. [dark]는 Apple 로고 색과 Google G 바탕(dark 테마)을 고릅니다. [tint]는 LINE
  /// 꺼짐 로고색입니다.
  Widget _logo({required double size, required bool dark, Color? tint}) {
    Image png(String asset) => Image.asset(
      asset,
      width: size,
      height: size,
      color: tint,
      colorBlendMode: tint == null ? null : BlendMode.srcIn,
    );
    return switch (provider) {
      SocialProvider.kakao => SvgPicture.asset(
        _kakaoSymbol,
        width: size,
        height: size,
      ),
      SocialProvider.line => png(_lineIcon),
      SocialProvider.google => png(dark ? _googleLogoDark : _googleLogoLight),
      SocialProvider.apple => SvgPicture.asset(
        dark ? _appleLogoBlack : _appleLogoWhite,
        width: size,
        height: size,
      ),
    };
  }

  Widget _buildConnected(BuildContext context, {required bool dark}) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final l10n = AppLocalizations.of(context);
    final stateColor = colors.actionPrimary;

    final face = DecoratedBox(
      key: faceKey,
      decoration: BoxDecoration(
        color: colors.bgSheet,
        borderRadius: _radius,
        border: Border.all(color: colors.line),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: _minHeight),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            logoInset,
            Space.s8,
            connectedEndInset,
            Space.s8,
          ),
          child: Row(
            children: [
              _badge(dark: dark),
              const SizedBox(width: Space.s8),
              Expanded(
                child: Text(
                  label,
                  style: tokens.typography.labelLg.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: Space.s8),
              Icon(
                PhosphorIconsRegular.check,
                size: connectedIconSize,
                color: stateColor,
              ),
              const SizedBox(width: connectedStateGap),
              Text(
                connectedLabel!,
                style: tokens.typography.captionLg.copyWith(color: stateColor),
              ),
            ],
          ),
        ),
      ),
    );
    final wide = SizedBox(width: double.infinity, child: face);
    final semanticLabel = [label, connectedLabel!].join(l10n.a11yListSeparator);

    if (loading) {
      return Semantics(
        container: true,
        button: true,
        enabled: false,
        identifier: identifier,
        label: l10n.actionBusy,
        child: ExcludeSemantics(
          child: Breathing(key: breathingKey, animated: animated, child: wide),
        ),
      );
    }
    if (disabled) {
      return Semantics(
        container: true,
        button: true,
        enabled: false,
        identifier: identifier,
        label: semanticLabel,
        child: ExcludeSemantics(
          child: Opacity(opacity: disabledOpacity, child: wide),
        ),
      );
    }
    if (onPressed == null) {
      // 마지막 남은 수단: 누를 수 없고 모양은 그대로, 버튼 역할·힌트 없이 이름과 상태만 읽습니다.
      // 이어 읽을 안내(`login-methods.last.notice`)는 화면이 버튼 묶음 아래에 둡니다.
      return Semantics(
        container: true,
        identifier: identifier,
        label: semanticLabel,
        child: ExcludeSemantics(child: wide),
      );
    }
    return VerticalHitSlop(
      minHeight: _minTarget,
      child: PressInkTarget(
        semanticLabel: semanticLabel,
        hint: unlinkHint,
        identifier: identifier,
        onTap: onPressed,
        borderRadius: _radius,
        inkColor: colors.textPrimary,
        child: wide,
      ),
    );
  }

  /// `connected` 로고: 제공자 색 배지(20px) 안의 공식 심볼(14px). 중립 바탕에서도 보이게
  /// 합니다. Google G는 흰 원 위에만 놓습니다.
  Widget _badge({required bool dark}) {
    final color = badgeColor(provider, dark: dark);
    final circle = badgeIsCircle(provider);
    return DecoratedBox(
      key: badgeKey,
      decoration: BoxDecoration(
        color: color,
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle
            ? null
            : const BorderRadius.all(Radius.circular(Radii.xs)),
      ),
      child: SizedBox.square(
        dimension: badgeSize,
        child: Center(
          // Google 배지는 늘 흰 원이라 light 테마 G를 씁니다.
          child: _logo(
            size: badgeSymbolSize,
            dark: provider != SocialProvider.google && dark,
          ),
        ),
      ),
    );
  }
}

/// 제공자 버튼 한 벌의 색과 글자 모양.
@immutable
final class _Look {
  const new({
    required this.background,
    required this.foreground,
    required this.labelStyle,
    this.border,
  });

  final Color background;
  final Color foreground;
  final TextStyle labelStyle;

  /// 안쪽 1px 테두리. null이면 없습니다.
  final Color? border;
}
