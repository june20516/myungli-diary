import 'package:flutter/material.dart';
import 'package:myungli_diary/design/components/action/primary_button.dart';
import 'package:myungli_diary/design/components/component_spec.dart';
import 'package:myungli_diary/design/components/feedback/state_layout.dart';
import 'package:myungli_diary/design/elements/app_icon.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';
import 'package:phosphor_glyphs/phosphor_glyphs.dart';

/// 비어 있을 때: sage 원 안 아이콘 + 문장 + (있으면) 주 버튼. 화면 세로 40% 자리.
class EmptyState extends StatelessWidget {
  /// 빈 상태를 만듭니다. [action]은 주 버튼(`primary-button` filled)입니다.
  const new({
    required this.body,
    this.action,
    this.icon = _defaultIcon,
    super.key,
  });

  /// 명세 대조용 요약.
  static const ComponentSpec spec = ComponentSpec('empty-state', {}, {});

  static const AppGlyph _defaultIcon = AppGlyph(
    light: PhosphorIconsLight.tray,
    regular: PhosphorIconsRegular.tray,
  );

  /// 문장(문구는 호출하는 쪽이 ARB로 넘김).
  final String body;

  /// 주 버튼. 없으면 문장만.
  final PrimaryButton? action;

  /// 원 안 아이콘. 화면 성격에 맞게 고릅니다.
  final AppGlyph icon;

  @override
  Widget build(BuildContext context) {
    return StateLayout(
      icon: icon,
      sentence: body,
      alert: false,
      children: [
        if (action != null) ...[const SizedBox(height: Space.s24), action!],
      ],
    );
  }
}
