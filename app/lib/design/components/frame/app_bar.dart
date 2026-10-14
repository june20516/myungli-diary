import 'package:flutter/material.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/component_spec.dart';
import 'package:myungli_diary/design/elements/app_icon.dart';
import 'package:myungli_diary/design/interaction/motion_prefs.dart';
import 'package:myungli_diary/design/interaction/patterns.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';
import 'package:phosphor_glyphs/phosphor_glyphs.dart';

/// 앱 바 높이(px).
const double appBarHeight = 44;

/// 앱 바 동작·뒤로 터치 영역 한 변(px).
const double appBarTarget = 44;

/// 오른쪽 동작 최대 개수.
const int appBarMaxActions = 2;

const AppGlyph _caretLeft = AppGlyph(
  light: PhosphorIconsLight.caretLeft,
  regular: PhosphorIconsRegular.caretLeft,
);

/// 화면 위 제목·뒤로·동작 아이콘. 바탕을 칠하지 않고, 스크롤해도 선·그림자를 더하지 않습니다.
class MyungliAppBar extends StatelessWidget {
  /// 탭 첫 화면용: 왼쪽 작은 제목, 오른쪽 동작 최대 2개.
  const new tabRoot({required this.title, this.actions = const [], super.key})
    : onBack = null,
      status = null,
      showBack = false,
      _inner = false;

  /// 안쪽 화면용: 뒤로(caret-left) + 제목 왼쪽 정렬, 동작과 초안 상태.
  ///
  /// [onBack]이 없으면 `Navigator.maybePop`입니다. [status]는 동작 왼쪽에 놓입니다.
  /// [showBack]이 false면 뒤로 버튼을 두지 않습니다(돌아갈 곳이 없는 진입 갈래의 첫 화면).
  const new inner({
    required this.title,
    this.onBack,
    this.actions = const [],
    this.status,
    this.showBack = true,
    super.key,
  }) : _inner = true;

  /// 명세 대조용 요약.
  static const ComponentSpec spec = ComponentSpec(
    'app-bar',
    {'tab-root', 'inner'},
    {'pressed'},
  );

  /// 화면 제목(한 줄, 넘치면 …).
  final String title;

  /// 안쪽 화면 뒤로 동작.
  final VoidCallback? onBack;

  /// 뒤로 버튼을 그리는지. `inner`에서만 true일 수 있습니다.
  final bool showBack;

  /// 오른쪽 동작([AppBarAction]) 최대 2개.
  final List<Widget> actions;

  /// 초안 상태(draft-indicator) 같은 동작 왼쪽 표시.
  final Widget? status;

  final bool _inner;

  @override
  Widget build(BuildContext context) {
    assert(actions.length <= appBarMaxActions, '동작은 두 개까지입니다.');
    final tokens = context.tokens;
    return SizedBox(
      height: appBarHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.s16),
        child: Row(
          children: [
            if (_inner && showBack)
              AppBarAction(
                key: const ValueKey('app-bar.back'),
                icon: _caretLeft,
                semanticLabel: AppLocalizations.of(context).appBarBack,
                onPressed: onBack ?? () => Navigator.maybePop(context),
              ),
            Expanded(
              // 제목이 비면(IA에 제목 슬롯이 없는 입력 화면) 빈 header를 만들지 않습니다.
              child: Semantics(
                header: title.isNotEmpty,
                excludeSemantics: title.isEmpty,
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tokens.typography.subtitle.copyWith(
                    color: tokens.colors.textPrimary,
                  ),
                ),
              ),
            ),
            ?status,
            ...actions,
          ],
        ),
      ),
    );
  }
}

/// 앱 바의 동작 아이콘 하나: 44px 터치 영역, 눌림은 그 안의 `press.ink`.
class AppBarAction extends StatefulWidget {
  /// 동작을 만듭니다. [semanticLabel]은 스크린리더가 읽는 동작 이름입니다.
  const new({
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
    super.key,
  });

  /// 아이콘(Light 24px, `text.primary`).
  final AppGlyph icon;

  /// 스크린리더 라벨.
  final String semanticLabel;

  /// 눌렀을 때.
  final VoidCallback onPressed;

  @override
  State<AppBarAction> createState() => _AppBarActionState();
}

class _AppBarActionState extends State<AppBarAction>
    with TickerProviderStateMixin {
  late final AnimationController _press = AnimationController(
    vsync: this,
    duration: InteractionPattern.pressInk.duration,
  );
  late final AnimationController _release = AnimationController(
    vsync: this,
    duration: pressInkReleaseDuration,
  )..addStatusListener(_onReleased);

  Alignment _origin = Alignment.center;

  void _onReleased(AnimationStatus status) {
    if (status == AnimationStatus.completed) _press.value = 0;
  }

  @override
  void dispose() {
    _press.dispose();
    _release.dispose();
    super.dispose();
  }

  void _down(TapDownDetails details) {
    _origin = Alignment(
      details.localPosition.dx / appBarTarget * 2 - 1,
      details.localPosition.dy / appBarTarget * 2 - 1,
    );
    _release.value = 0;
    _press.forward(from: 0);
  }

  void _up() => _release.forward(from: 0);

  @override
  Widget build(BuildContext context) {
    final colors = context.tokens.colors;
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      onTap: widget.onPressed,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: _down,
          onTapUp: (_) {
            _up();
            widget.onPressed();
          },
          onTapCancel: _up,
          child: SizedBox.square(
            dimension: appBarTarget,
            child: animate(
              InteractionPattern.pressInk,
              t: _press,
              prefs: MotionPrefs.of(context),
              options: PatternOptions(
                origin: _origin,
                release: _release,
                inkColor: colors.textPrimary,
                borderRadius: BorderRadius.circular(appBarTarget / 2),
              ),
              child: Center(
                child: AppIcon(widget.icon, color: colors.textPrimary),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
