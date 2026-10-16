import 'dart:async';

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

  /// 하단 틀(탭 바·배너) 또는 안전 영역 위로 띄우는 간격(px).
  static const double gapAbove = 16;

  /// 화면 좌우로 남기는 여백 합(px). 최대 너비는 `100% - 40px`입니다.
  static const double sideGutter = 40;
}

_ToastSession? _activeToast;

/// 토스트를 보입니다. 한 번에 하나만 보이며, 새 토스트가 오면 이전 것은 바로 사라집니다.
///
/// 위치는 [BottomBarInsetScope]의 하단 틀 높이 위 16px이고, 범위가 없으면 아래 안전 영역
/// 위 16px입니다. [icon]은 선택이며 누르는 동작은 담지 않습니다. 부른 화면([context])이
/// 바로 닫혀도 토스트는 끝까지 보입니다.
void showMyungliToast(BuildContext context, String message, {AppGlyph? icon}) {
  final overlay = Overlay.of(context, rootOverlay: true);
  final barHeight = BottomBarInsetScope.of(context);
  final bottom =
      (barHeight > 0 ? barHeight : MediaQuery.viewPaddingOf(context).bottom) +
      MyungliToast.gapAbove;
  // 부른 화면이 곧 닫혀도(저장 실패 뒤 닫기 등) 토스트가 남도록, [context]는 여기서만 읽고
  // overlay builder에서는 쓰지 않습니다.
  final prefs = MotionPrefs.of(context);
  _activeToast?.dismiss();
  final session = _ToastSession();
  session.entry = OverlayEntry(
    builder: (_) => MotionPrefsScope(
      prefs: prefs,
      child: Positioned(
        left: MyungliToast.sideGutter / 2,
        right: MyungliToast.sideGutter / 2,
        bottom: bottom,
        child: ValueListenableBuilder<bool>(
          valueListenable: session.present,
          builder: (context, present, _) => SeepPresence(
            present: present,
            onGone: session.remove,
            // root overlay는 화면의 Material 밖이므로, 글자가 MaterialApp의 오류
            // 스타일(노란 이중 밑줄)을 받지 않게 그리지 않는 Material 조상을 둡니다.
            child: Align(
              child: Material(
                type: MaterialType.transparency,
                child: ToastPill(message: message, icon: icon),
              ),
            ),
          ),
        ),
      ),
    ),
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
  const new({required this.message, this.icon, super.key});

  /// 문구. 스크린리더가 글자 그대로 읽습니다.
  final String message;

  /// 앞 아이콘(16px Regular, 선택).
  final AppGlyph? icon;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    return LiveAnnouncement(
      label: message,
      role: SemanticsRole.status,
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
