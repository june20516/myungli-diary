import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:myungli_diary/design/components/component_spec.dart';
import 'package:myungli_diary/design/components/feedback/live_announcement.dart';
import 'package:myungli_diary/design/components/feedback/seep_presence.dart';
import 'package:myungli_diary/design/components/frame/bottom_bar_inset_scope.dart';
import 'package:myungli_diary/design/elements/app_icon.dart';
import 'package:myungli_diary/design/interaction/motion_prefs.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

/// 짧은 알림(`toast`)의 명세 요약.
abstract final class MyungliToast {
  /// 명세 대조용 요약.
  static const ComponentSpec spec = ComponentSpec('toast', {}, {
    'showing',
    'hiding',
  });

  /// 기준(아래 고정 버튼·광고 배너·탭 바·안전 영역) 위로 띄우는 간격(px).
  static const double gapAbove = 16;

  /// 화면 좌우로 남기는 여백 합(px). 최대 너비는 `100% - 40px`입니다.
  static const double sideGutter = 40;
}

/// 경로(화면·시트)마다 등록된 아래 고정 버튼 자리. 한 경로에 하나입니다.
final Expando<_ToastAnchorState> _anchors = Expando('toast anchor');

/// 화면 아래에 고정된 버튼 자리(`primary-button`, `input-step` 주 버튼 등, V51).
///
/// 이 자리가 있는 화면에서 부른 토스트는 그 위 16px에 뜨고, 키보드가 올라와 버튼이 움직이면
/// 함께 움직입니다. 자기 경로([ModalRoute])에 등록되므로 화면이나 시트마다 하나만 둡니다.
class ToastAnchor extends StatefulWidget {
  /// [child](아래 고정 버튼 묶음)를 토스트 기준 자리로 둡니다.
  const new({required this.child, super.key});

  /// 아래 고정 버튼 묶음.
  final Widget child;

  @override
  State<ToastAnchor> createState() => _ToastAnchorState();
}

class _ToastAnchorState extends State<ToastAnchor> {
  final LayerLink link = LayerLink();
  ModalRoute<Object?>? _route;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (identical(route, _route)) return;
    _release();
    _route = route;
    if (route != null) _anchors[route] = this;
  }

  @override
  void dispose() {
    _release();
    super.dispose();
  }

  void _release() {
    final route = _route;
    if (route != null && identical(_anchors[route], this)) {
      _anchors[route] = null;
    }
  }

  /// 높이 [screenHeight]인 화면 아래에서 이 자리 위끝까지의 거리. 그려지지 않았으면 null.
  double? distanceFromBottom(double screenHeight) {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    return screenHeight - box.localToGlobal(Offset.zero).dy;
  }

  @override
  Widget build(BuildContext context) =>
      CompositedTransformTarget(link: link, child: widget.child);
}

_ToastSession? _activeToast;

/// 토스트를 보입니다. 한 번에 하나만 보이며, 새 토스트가 오면 이전 것은 바로 사라집니다.
///
/// 위치는 화면 아래에 붙은 것 중 가장 위의 것에서 16px 위입니다(V51): 부른 화면의
/// [ToastAnchor](아래 고정 버튼) → [BottomBarInsetScope]의 하단 틀(광고 배너·탭 바) → 아래
/// 안전 영역(키보드가 있으면 키보드) 순서입니다. 버튼이 있으면 키보드로 움직일 때 따라가고,
/// 부른 화면이 닫혀 버튼이 사라지면 처음 자리에 남습니다. [icon]은 선택이며 누르는 동작은
/// 담지 않아, 누름은 아래 화면(하단 버튼 등)으로 지나갑니다. 부른 화면([context])이 바로
/// 닫혀도 토스트는 끝까지 보입니다.
void showMyungliToast(
  BuildContext context,
  String message, {
  AppGlyph? icon,
  String? identifier,
}) {
  final overlay = Overlay.of(context, rootOverlay: true);
  final route = ModalRoute.of(context);
  final anchor = route == null ? null : _anchors[route];
  final overlayBox = overlay.context.findRenderObject();
  final screenHeight = overlayBox is RenderBox && overlayBox.hasSize
      ? overlayBox.size.height
      : MediaQuery.sizeOf(context).height;
  final barHeight = BottomBarInsetScope.of(context);
  final base =
      anchor?.distanceFromBottom(screenHeight) ??
      math.max(
        barHeight > 0 ? barHeight : MediaQuery.viewPaddingOf(context).bottom,
        MediaQuery.viewInsetsOf(context).bottom,
      );
  final bottom = base + MyungliToast.gapAbove;
  final link = anchor?.link;
  // 부른 화면이 곧 닫혀도(저장 실패 뒤 닫기 등) 토스트가 남도록, [context]는 여기서만 읽고
  // overlay builder에서는 쓰지 않습니다.
  final prefs = MotionPrefs.of(context);
  _activeToast?.dismiss();
  final session = _ToastSession();
  session.entry = OverlayEntry(
    builder: (_) {
      Widget toast = ValueListenableBuilder<bool>(
        valueListenable: session.present,
        builder: (context, present, _) => SeepPresence(
          present: present,
          onGone: session.remove,
          // root overlay는 화면의 Material 밖이므로, 글자가 MaterialApp의 오류
          // 스타일(노란 이중 밑줄)을 받지 않게 그리지 않는 Material 조상을 둡니다.
          // 누르는 동작이 없으므로 누름은 아래 화면(하단 버튼 등)으로 보냅니다. 읽기(semantics)는
          // 그대로 남습니다.
          child: IgnorePointer(
            child: Align(
              child: Material(
                type: MaterialType.transparency,
                child: ToastPill(
                  message: message,
                  icon: icon,
                  identifier: identifier,
                ),
              ),
            ),
          ),
        ),
      );
      if (link != null) {
        // 버튼이 그려지는 동안은 버튼 위끝 가운데에 붙어 따라가고, 버튼이 사라지면
        // 아래 Positioned 자리(처음 버튼 위치)에 남습니다.
        toast = CompositedTransformFollower(
          link: link,
          targetAnchor: Alignment.topCenter,
          followerAnchor: Alignment.bottomCenter,
          offset: const Offset(0, -MyungliToast.gapAbove),
          child: toast,
        );
      }
      return MotionPrefsScope(
        prefs: prefs,
        child: Positioned(
          left: MyungliToast.sideGutter / 2,
          right: MyungliToast.sideGutter / 2,
          bottom: bottom,
          child: toast,
        ),
      );
    },
  );
  _activeToast = session;
  overlay.insert(session.entry);
  session.hold = Timer(Motion.toastHold, session.dismiss);
}

class _ToastSession {
  late final OverlayEntry entry;
  final ValueNotifier<bool> present = ValueNotifier<bool>(true);
  Timer? hold;
  bool _removed = false;

  void dismiss() {
    hold?.cancel();
    present.value = false;
  }

  void remove() {
    if (_removed) return;
    _removed = true;
    hold?.cancel();
    entry
      ..remove()
      ..dispose();
    present.dispose();
    if (identical(_activeToast, this)) _activeToast = null;
  }
}

/// 토스트 알약 하나. 위치와 나타남은 [showMyungliToast]가 맡습니다.
class ToastPill extends StatelessWidget {
  /// 반전색 알약을 만듭니다.
  const new({required this.message, this.icon, this.identifier, super.key});

  /// 문구. 스크린리더가 글자 그대로 읽습니다.
  final String message;

  /// 앞 아이콘(16px Regular, 선택).
  final AppGlyph? icon;

  /// IA 슬롯 id. 있으면 Key와 Semantics `identifier`로 붙입니다.
  final String? identifier;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final identifier = this.identifier;
    return LiveAnnouncement(
      key: identifier == null ? null : ValueKey<String>(identifier),
      label: message,
      role: SemanticsRole.status,
      identifier: identifier,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.inverseBg,
          borderRadius: BorderRadius.circular(Radii.full),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Space.s16,
            vertical: Space.s12,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                AppIcon(
                  icon!,
                  size: AppIconSize.inline,
                  weight: AppIconWeight.regular,
                  color: colors.inverseFg,
                ),
                const SizedBox(width: Space.s16),
              ],
              Flexible(
                child: Text(
                  message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: tokens.typography.bodyUi.copyWith(
                    color: colors.inverseFg,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
