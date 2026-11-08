import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsRole;
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/action/breathing_dots.dart';
import 'package:myungli_diary/design/components/component_spec.dart';
import 'package:myungli_diary/design/components/feedback/live_announcement.dart';
import 'package:myungli_diary/design/elements/app_icon.dart';
import 'package:myungli_diary/design/interaction/motion_prefs.dart';
import 'package:myungli_diary/design/interaction/patterns.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:phosphor_glyphs/phosphor_glyphs.dart';

/// [DraftIndicator] 상태(`draft-indicator` `states`).
enum DraftIndicatorState {
  /// 기기에 초안 저장됨(cloud).
  local,

  /// 보내는 중(점 숨쉬기, 아이콘 없음).
  saving,

  /// 서버에 저장됨(check).
  saved,
}

const AppGlyph _cloud = AppGlyph(
  light: PhosphorIconsLight.cloud,
  regular: PhosphorIconsRegular.cloud,
);

const AppGlyph _check = AppGlyph(
  light: PhosphorIconsLight.check,
  regular: PhosphorIconsRegular.check,
);

/// 초안 저장 상태(`draft-indicator`): app-bar 오른쪽(동작 왼쪽) 작은 글자 + 아이콘 16 Light.
///
/// 상태가 바뀔 때만 `appear.seep`으로 바꿔 그리고, 같은 상태가 다시 오면 움직이지 않습니다.
/// 스크린리더에는 상태 글자([label], writing 문구 3종)를 `status`로 알립니다.
class DraftIndicator extends StatefulWidget {
  /// [state]와 그 글자 [label]로 만듭니다.
  const new({required this.state, required this.label, this.length, super.key});

  /// 명세 대조용 요약.
  static const ComponentSpec spec = ComponentSpec('draft-indicator', {}, {
    'local',
    'saving',
    'saved',
  });

  static const double _gap = 4;
  static const double _countGap = 8;
  static const double _dotSize = 3;
  static const double _dotGap = 2;

  /// 상태.
  final DraftIndicatorState state;

  /// 상태 글자.
  final String label;

  /// 본문 글자 수. 있으면 상태 글자 뒤에 `space.8`을 두고 `diary-edit.length.count`로
  /// 그립니다. 칠 때마다 바뀌어도 고정폭 숫자라 상태 글자가 움직이지 않고, 스크린리더는
  /// 상태 글자만 읽습니다.
  final int? length;

  @override
  State<DraftIndicator> createState() => _DraftIndicatorState();
}

class _DraftIndicatorState extends State<DraftIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _seep = AnimationController(
    vsync: this,
    duration: InteractionPattern.appearSeep.duration,
    value: 1,
  );

  @override
  void didUpdateWidget(DraftIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state != oldWidget.state) {
      _seep.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _seep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final color = tokens.colors.textSecondary;
    final style = tokens.typography.captionMd.copyWith(color: color);
    final length = widget.length;
    final lead = switch (widget.state) {
      DraftIndicatorState.local => AppIcon(
        _cloud,
        size: AppIconSize.s16,
        color: color,
      ),
      DraftIndicatorState.saving => BreathingDots(
        color: color,
        animated: true,
        count: BreathingDots.standardCount,
        size: DraftIndicator._dotSize,
        gap: DraftIndicator._dotGap,
      ),
      DraftIndicatorState.saved => AppIcon(
        _check,
        size: AppIconSize.s16,
        color: color,
      ),
    };
    return LiveAnnouncement(
      label: widget.label,
      role: SemanticsRole.status,
      child: animate(
        InteractionPattern.appearSeep,
        t: _seep,
        prefs: MotionPrefs.of(context),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            lead,
            const SizedBox(width: DraftIndicator._gap),
            // 가운데 폭이 좁으면 상태 글자 끝을 말줄임하고 글자 수는 지킵니다.
            Flexible(
              child: Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: style,
              ),
            ),
            if (length != null) ...[
              const SizedBox(width: DraftIndicator._countGap),
              Text(
                AppLocalizations.of(context).diaryEditLengthCount(length),
                maxLines: 1,
                style: style.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
