import 'package:flutter/material.dart';
import 'package:myungli_diary/design/components/component_spec.dart';
import 'package:myungli_diary/design/components/sentence/press_ink_target.dart';
import 'package:myungli_diary/design/components/sentence/vertical_hit_slop.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

/// 근거 링크 변형.
enum DepthLinkVariant {
  /// 이유 문장 끝에 붙임. 링크 전체가 한 덩어리입니다.
  inlineEnd('inline-end'),

  /// 나 탭·풀이 시트처럼 문단 아래 따로 놓임(위 `space.12`).
  block('block');

  new(this.id);

  /// 명세 변형 id.
  final String id;
}

/// 근거 시트(`depth-link.evidenceSheet`)의 열람 상태(D60, 시안 B).
///
/// 링크 자체의 모습이 아니라, 링크가 여는 시트의 상태입니다. 시트의 잠김 안내 영역과
/// 세 구역을 `EvidenceSheetBody`가 이 상태대로 그립니다.
enum DepthLinkState {
  /// 권한 없음, 보상형 광고 준비됨. 세 구역을 `lock.veil`로, 아래에 안내 영역.
  locked,

  /// 권한 없음, 광고 준비 안 됨. 버튼이 꺼지고 안내 문구가 붙습니다.
  lockedNoAd,

  /// 광고를 끝까지 보고 돌아와 server 확인(SSV)을 기다림. 버튼 점 숨쉬기.
  unlocking,

  /// 권한 있음. 안내 영역 없이 세 구역 본문.
  unlocked,
}

/// 한 단계 깊이로 가는 링크("근거 보기 ›", `depth-link`).
///
/// `action.primary` `type.label.lg`이고 눌림은 글자 둘레에서만 번지는 `press.ink`입니다.
/// 링크 전체가 한 덩어리라 글자 안에서 줄이 바뀌지 않습니다(`link.inline-nowrap`).
/// 구현은 줄바꿈 없는 글자 하나를 위젯으로 문장에 끼우는 방식이라 U+00A0·U+2060 대신
/// 한 위젯으로 묶습니다. 스크린리더 초점은 링크에 따로 주고 라벨은 글자 그대로입니다.
class DepthLink extends StatelessWidget {
  /// 링크를 만듭니다.
  const new({
    required this.variant,
    required this.label,
    required this.onTap,
    this.slotId,
    super.key,
  });

  /// 명세 대조용 요약. `locked` 이하 네 상태는 링크가 여는 근거 시트의 상태입니다
  /// (`DepthLinkState`, 그리는 쪽은 `EvidenceSheetBody`). 링크 자신의 상태는 `pressed`뿐입니다.
  static const ComponentSpec spec = ComponentSpec(
    'depth-link',
    {'inline-end', 'block'},
    {'pressed', 'locked', 'lockedNoAd', 'unlocking', 'unlocked'},
  );

  /// 변형.
  final DepthLinkVariant variant;

  /// 링크 글자(ARB 문구). 화살표 "›"는 덧붙여 그립니다.
  final String label;

  /// 눌렀을 때(한 단계 깊은 시트 열기).
  final VoidCallback onTap;

  /// 이 링크가 그리는 IA 슬롯 id(`SlotIds`). 있으면 Key와 Semantics `identifier`로 붙습니다.
  final String? slotId;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    const radius = BorderRadius.all(Radius.circular(Radii.xs));
    final link = VerticalHitSlop(
      child: PressInkTarget(
        link: true,
        semanticLabel: label,
        identifier: slotId,
        onTap: onTap,
        borderRadius: radius,
        inkColor: tokens.colors.actionPrimary,
        child: Text(
          '$label ›',
          softWrap: false,
          style: tokens.typography.labelLg.copyWith(
            color: tokens.colors.actionPrimary,
          ),
        ),
      ),
    );
    final id = slotId;
    final keyed = id == null
        ? link
        : KeyedSubtree(key: ValueKey(id), child: link);
    return switch (variant) {
      DepthLinkVariant.inlineEnd => keyed,
      DepthLinkVariant.block => Padding(
        padding: const EdgeInsets.only(top: Space.s12),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          heightFactor: 1,
          child: keyed,
        ),
      ),
    };
  }
}
