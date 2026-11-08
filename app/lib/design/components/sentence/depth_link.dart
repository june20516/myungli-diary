import 'package:flutter/material.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/component_spec.dart';
import 'package:myungli_diary/design/components/sentence/link_label.dart';
import 'package:myungli_diary/design/components/sentence/press_ink_target.dart';
import 'package:myungli_diary/design/components/sentence/vertical_hit_slop.dart';
import 'package:myungli_diary/design/elements/app_icon.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';
import 'package:phosphor_glyphs/phosphor_glyphs.dart';

/// `depth-link` 변형.
enum DepthLinkVariant {
  /// 이유 문장 끝에 붙는 근거 진입점 아이콘.
  inlineEnd('inline-end'),

  /// 나 탭·풀이 시트처럼 문단 아래 따로 놓이는 근거 진입점 아이콘(위 `space.12`).
  block('block'),

  /// 다른 페이지로 이동(출생지 → 계산 기준, 결정 V32). 배치는 [block]과 같고, 시트를 열지
  /// 않고 플랫폼 기본 페이지 전환으로 이동합니다(`sheet.enter`·`sheet.stack` 없음).
  navigate('navigate');

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

/// 근거 진입점 아이콘이 놓이는 자리(`depth-link` 변형 `inline-end`, `block`).
enum DepthLinkPlacement {
  /// 이유 문장 끝에 붙임.
  inlineEnd(DepthLinkVariant.inlineEnd),

  /// 문단 아래 따로 놓임(위 `space.12`).
  block(DepthLinkVariant.block);

  new(this.variant);

  /// 같은 자리를 가리키는 `depth-link` 변형.
  final DepthLinkVariant variant;
}

/// 한 단계 깊이로 가는 근거 진입점([DepthLink.evidence])과, 다른 페이지로 가는 글자 링크
/// ([DepthLinkVariant.navigate], 기본 생성자).
///
/// 근거 진입점은 글자 없이 `book-open-text` Regular 20 `action.primary` 아이콘 하나입니다
/// (결정 V63). 줄에 차지하는 폭은 그림 20이고, 터치 48은 배치 밖으로 넓힙니다(이웃 줄과
/// 겹쳐도 됩니다). 스크린리더는 버튼으로 읽고 이름은 `depthLinkEvidence(subject)`입니다.
/// [DepthLinkVariant.inlineEnd]는 문장 끝 `WidgetSpan` 하나에 담겨 마지막 낱말과 함께 줄을
/// 바꾸고, 터치는 물리적 왼쪽으로만 넓혀 오른쪽 부모 경계를 넘지 않습니다.
///
/// 글자 링크는 `action.primary` `type.label.lg`이고 눌림은 글자 둘레에서만 번지는
/// `press.ink`입니다. 끝 화살표(`caret-right`)는 원고가 아니라 [LinkLabel]이 그립니다
/// (결정 V29). 길면 감기고 화살표는 마지막 줄 끝에 붙으며, 스크린리더 role은 `link`입니다.
/// `sentence-block`의 잠김 "열기"도 글자 링크로 [DepthLinkVariant.inlineEnd] 기본 생성자를
/// 씁니다(한 줄, 감기지 않음).
///
/// 누른 뒤 어디로 가는지는 [onTap]을 주는 쪽이 정합니다. 근거 진입점은 근거 시트를 열고,
/// [DepthLinkVariant.navigate]는 페이지를 쌓습니다(`context.push`).
class DepthLink extends StatelessWidget {
  /// 글자 링크를 만듭니다. 근거 진입점은 [DepthLink.evidence]를 씁니다.
  const new({
    required this.variant,
    required String this.label,
    required this.onTap,
    this.slotId,
    this.marginTop = Space.s12,
    super.key,
  }) : subject = null,
       assert(
         variant != DepthLinkVariant.block,
         '근거 진입점(block)은 DepthLink.evidence를 씁니다',
       );

  /// 근거 진입점 아이콘을 만듭니다. [subject]는 스크린리더가 읽을 항목 이름입니다
  /// (`inline-end`면 앞 문장이 속한 항목, `block`이면 시트 제목이나 구역 이름).
  const new evidence({
    required String this.subject,
    required this.onTap,
    DepthLinkPlacement placement = DepthLinkPlacement.block,
    this.slotId,
    super.key,
  }) : variant = placement == DepthLinkPlacement.block
           ? DepthLinkVariant.block
           : DepthLinkVariant.inlineEnd,
       label = null,
       marginTop = Space.s12;

  /// 명세 대조용 요약. `locked` 이하 네 상태는 링크가 여는 근거 시트의 상태입니다
  /// (`DepthLinkState`, 그리는 쪽은 `EvidenceSheetBody`). 링크 자신의 상태는 `pressed`뿐입니다.
  static const ComponentSpec spec = ComponentSpec(
    'depth-link',
    {'inline-end', 'block', 'navigate'},
    {'pressed', 'locked', 'lockedNoAd', 'unlocking', 'unlocked'},
  );

  /// 근거 진입점 아이콘 크기. 계약 `depth-link.parts.icon.size`(`size.icon.20`). 글자 배율을
  /// 따르지 않는 고정 크기이고, 줄에 차지하는 폭(`layoutWidth`)도 같습니다.
  static const AppIconSize iconSize = AppIconSize.s20;

  /// 근거 진입점의 터치 크기(px). 계약 `depth-link.parts.icon.minTarget`.
  static const double minTarget = 48;

  /// 근거 진입점 아이콘 글리프(`book-open-text`).
  static const AppGlyph evidenceGlyph = AppGlyph(
    light: PhosphorIconsLight.bookOpenText,
    regular: PhosphorIconsRegular.bookOpenText,
  );

  /// 변형.
  final DepthLinkVariant variant;

  /// 링크 글자(ARB 문구). 화살표는 [LinkLabel]이 덧붙여 그립니다. 근거 진입점은 null입니다.
  final String? label;

  /// 근거 진입점이 스크린리더에 알릴 항목 이름. 글자 링크는 null입니다.
  final String? subject;

  /// 눌렀을 때(한 단계 깊은 시트 열기, [DepthLinkVariant.navigate]는 페이지 이동).
  final VoidCallback onTap;

  /// 이 링크가 그리는 IA 슬롯 id(`SlotIds`). 있으면 Key와 Semantics `identifier`로 붙습니다.
  final String? slotId;

  /// 글자 링크가 block·navigate일 때 위 여백(기본 `space.12`).
  final double marginTop;

  @override
  Widget build(BuildContext context) {
    final subject = this.subject;
    final link = subject == null
        ? _textLink(context)
        : _evidenceIcon(context, subject);
    final id = slotId;
    final keyed = id == null
        ? link
        : KeyedSubtree(key: ValueKey(id), child: link);
    return switch (variant) {
      DepthLinkVariant.inlineEnd => keyed,
      DepthLinkVariant.block || DepthLinkVariant.navigate => Padding(
        padding: EdgeInsets.only(top: marginTop),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          heightFactor: 1,
          child: keyed,
        ),
      ),
    };
  }

  Widget _evidenceIcon(BuildContext context, String subject) {
    final tokens = context.tokens;
    const radius = BorderRadius.all(Radius.circular(Radii.xs));
    final size = iconSize.logical;
    return VerticalHitSlop(
      minHeight: minTarget,
      minWidth: minTarget,
      // 문장 끝 아이콘은 오른쪽이 부모 경계라 왼쪽으로만 넓힙니다.
      widenLeftOnly: variant == DepthLinkVariant.inlineEnd,
      child: PressInkTarget(
        semanticLabel: AppLocalizations.of(context).depthLinkEvidence(subject),
        identifier: slotId,
        onTap: onTap,
        borderRadius: radius,
        inkColor: tokens.colors.actionPrimary,
        child: SizedBox(
          width: size,
          height: size,
          child: AppIcon(
            evidenceGlyph,
            size: iconSize,
            weight: AppIconWeight.regular,
            color: tokens.colors.actionPrimary,
          ),
        ),
      ),
    );
  }

  Widget _textLink(BuildContext context) {
    final tokens = context.tokens;
    const radius = BorderRadius.all(Radius.circular(Radii.xs));
    final label = this.label!;
    return VerticalHitSlop(
      child: PressInkTarget(
        link: true,
        semanticLabel: label,
        identifier: slotId,
        onTap: onTap,
        borderRadius: radius,
        inkColor: tokens.colors.actionPrimary,
        child: LinkLabel(
          label: label,
          // inline-end는 문장 끝에 붙는 한 덩어리라 감기지 않습니다.
          softWrap: variant != DepthLinkVariant.inlineEnd,
          style: tokens.typography.labelLg.copyWith(
            color: tokens.colors.actionPrimary,
          ),
        ),
      ),
    );
  }
}
