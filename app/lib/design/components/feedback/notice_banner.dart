import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:myungli_diary/design/components/component_spec.dart';
import 'package:myungli_diary/design/components/feedback/seep_presence.dart';
import 'package:myungli_diary/design/elements/app_icon.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';
import 'package:phosphor_glyphs/phosphor_glyphs.dart';

/// 안내 배너 변형(`notice-banner` `variants`).
enum NoticeBannerVariant {
  /// 연결 없음, 받아둔 내용을 보여 줄 때.
  offline(
    AppGlyph(
      light: PhosphorIconsLight.wifiSlash,
      regular: PhosphorIconsRegular.wifiSlash,
    ),
  ),

  /// 출생 시간을 모름(`time-unknown`, 시주 없음).
  timeUnknown(
    AppGlyph(
      light: PhosphorIconsLight.clock,
      regular: PhosphorIconsRegular.clock,
    ),
  ),

  /// 이어 쓸 초안이 있음.
  draft(
    AppGlyph(
      light: PhosphorIconsLight.notePencil,
      regular: PhosphorIconsRegular.notePencil,
    ),
  );

  new(this.glyph);

  /// 변형의 아이콘.
  final AppGlyph glyph;
}

/// 화면 내용 첫 줄의 안내. 떠 있지 않고 내용과 함께 스크롤되며 닫기 버튼이 없습니다.
///
/// [present]가 true가 되면 `appear.seep`으로 나타나고, 상태가 풀려 false가 되면
/// `disappear.seep`으로 저절로 사라집니다.
class NoticeBanner extends StatelessWidget {
  /// 안내 배너를 만듭니다. 문구는 호출하는 쪽이 ARB로 넘깁니다.
  const new({
    required this.variant,
    required this.message,
    this.present = true,
    super.key,
  });

  /// 명세 대조용 요약.
  static const ComponentSpec spec = ComponentSpec(
    'notice-banner',
    {'offline', 'time-unknown', 'draft'},
    {'showing', 'resolved'},
  );

  /// 변형.
  final NoticeBannerVariant variant;

  /// 안내 문구(스크린리더가 글자 그대로 읽음).
  final String message;

  /// 보이는지. false가 되면 사라지는 움직임 뒤 자리가 비워집니다.
  final bool present;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    return SeepPresence(
      present: present,
      // role status는 정중한(polite) 알림을 뜻하므로 liveRegion을 따로 켜지 않습니다.
      child: Semantics(
        role: SemanticsRole.status,
        label: message,
        child: ExcludeSemantics(
          child: Padding(
            padding: const EdgeInsets.only(bottom: Space.s16),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.bgSheet,
                borderRadius: BorderRadius.circular(Radii.md),
              ),
              child: Padding(
                padding: const EdgeInsets.all(Space.s12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      // 아이콘 16px을 글줄 첫 줄 가운데에 맞춥니다.
                      padding: const EdgeInsets.only(top: 1),
                      child: AppIcon(
                        variant.glyph,
                        size: AppIconSize.inline,
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: Space.s8),
                    Expanded(
                      child: Text(
                        message,
                        style: tokens.typography.captionLg.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
