import 'package:flutter/material.dart';
import 'package:myungli_diary/core/api/gen/model/rendered_text.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/ia/ia_lookup.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/component_spec.dart';
import 'package:myungli_diary/design/components/sentence/depth_link.dart';
import 'package:myungli_diary/design/components/sentence/rendered_text_view.dart';
import 'package:myungli_diary/design/elements/lock_veil.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';

/// 콘텐츠 문장 덩어리의 변형.
enum SentenceBlockVariant {
  /// 오늘 카드·공유 이미지·질문 카드의 큰 문장(`type.sentence.card`).
  card,

  /// 풀이·일기·설명 본문(`type.sentence.body`).
  body,

  /// 일기 목록 미리보기: 본문 글자를 14.5px로, 두 줄 말줄임.
  preview,
}

/// 콘텐츠 문장 덩어리(`sentence-block`). 조각 배열은 [RenderedTextView]가 그립니다.
///
/// 용어 조각(V28): [termStyle]을 주지 않으면 [slotId]의 화면(첫 마디)이 IA에서
/// `term-token`을 쓰는 화면일 때만 칩, 그 밖과 [slotId]가 없을 때는 일반 글자입니다.
/// [SentenceBlockVariant.preview](`diary-row`)는 항상 일반 글자입니다.
/// 공유 이미지처럼 화면과 관계없이 일반 글자여야 하면 [TermStyle.plain]을 줍니다.
///
/// 호칭은 server가 문장 안에 넣어 보내므로 굵게 하거나 색을 바꾸지 않고 그대로 그립니다.
/// [locked]면 근거·해석 열람 권한이 없는 문장(D60)이라 본문을 그리지 않고, 흐린 한 줄
/// (`lock.veil`)과 오른쪽 끝 "열기 ›"만 둡니다. 잠긴 내용은 server가 보내지 않으므로
/// [text]는 트리에도 스크린리더에도 들어가지 않습니다.
class SentenceBlock extends StatelessWidget {
  /// 문장 덩어리를 만듭니다.
  const new({
    required this.variant,
    required this.text,
    this.locked = false,
    this.slotId,
    this.termStyle,
    this.onTerm,
    this.onOpenLocked,
    this.trailing,
    this.color,
    this.maxLines,
    super.key,
  }) : assert(
         variant != SentenceBlockVariant.preview ||
             (onTerm == null && termStyle != TermStyle.chip),
         'preview는 카드 전체가 버튼인 곳(diary-row)에 놓이므로 용어를 누를 수 없습니다.',
       );

  /// 명세 대조용 요약.
  static const ComponentSpec spec = ComponentSpec(
    'sentence-block',
    {'card', 'body', 'preview'},
    {'locked'},
  );

  /// 잠김 라벨 앞부분(구역 이름) 슬롯(`a11y.lockedNameSlot`, 컴포넌트 2.2.0).
  /// 잠긴 문장은 지금 사주 표 용신 판정 근거에만 쓰여 이름이 하나입니다.
  static const String lockedNameSlotId = SlotIds.sajuChartYongsinTitle;

  /// 잠김 라벨 뒷부분("잠김") 슬롯(`a11y.lockedLabelSlot`).
  static const String lockedLabelSlotId = SlotIds.evidenceSheetA11yLocked;

  /// 잠김 라벨 슬롯의 문구(슬롯 id → ARB getter). 라벨은 이 순서로 잇습니다.
  ///
  /// 대조 테스트가 각 getter가 그 슬롯의 ARB 키(`iaKey`) 문구를 내는지 확인하므로,
  /// 명세의 슬롯이 바뀌어 상수를 고치면 여기 getter도 함께 고쳐야 통과합니다.
  static final Map<String, String Function(AppLocalizations)> lockedLabelTexts =
      {
        lockedNameSlotId: (l10n) => l10n.sajuChartYongsinTitle,
        lockedLabelSlotId: (l10n) => l10n.evidenceSheetA11yLocked,
      };

  /// 변형.
  final SentenceBlockVariant variant;

  /// server가 렌더한 문장 조각.
  final RenderedText text;

  /// 근거·해석 열람 권한이 없는 잠긴 문장인지.
  final bool locked;

  /// 이 문장이 채우는 IA 슬롯 id(`SlotIds`). 있으면 Key와 Semantics `identifier`로 붙습니다.
  final String? slotId;

  /// `term` 조각 표시를 직접 정합니다. null이면 IA로 정합니다(클래스 설명).
  final TermStyle? termStyle;

  /// 용어 칩을 눌렀을 때. 칩으로 그려질 때(term-token 화면 슬롯의 문장에 `term` 조각이
  /// 있을 때) 필요합니다. 용어가 없는 문장에는 주지 않아도 됩니다.
  final ValueChanged<String>? onTerm;

  /// 잠긴 문장의 "열기 ›"를 눌렀을 때(근거 시트를 잠김 상태로 엽니다).
  final VoidCallback? onOpenLocked;

  /// 문장 끝에 붙는 위젯(`depth-link` `inline-end`).
  final Widget? trailing;

  /// 글자색. 없으면 `text.primary`입니다(질문 카드의 쓴 뒤 상태가 `text.secondary`로 바꿉니다).
  final Color? color;

  /// 최대 줄 수. 넘치면 말줄임합니다(공유 이미지 feed의 두 줄). null이면 제한이 없고,
  /// [SentenceBlockVariant.preview]는 항상 두 줄입니다.
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final content = locked ? _buildLocked(context) : _buildText(context);
    final id = slotId;
    if (id == null) return content;
    return KeyedSubtree(
      key: ValueKey(id),
      child: Semantics(identifier: id, container: true, child: content),
    );
  }

  Widget _buildText(BuildContext context) {
    final typography = context.tokens.typography;
    final base = switch (variant) {
      SentenceBlockVariant.card => typography.sentenceCard,
      SentenceBlockVariant.body ||
      SentenceBlockVariant.preview => typography.sentenceBody,
    };
    final preview = variant == SentenceBlockVariant.preview;
    final terms = _resolveTermStyle();
    assert(
      terms == TermStyle.plain ||
          onTerm != null ||
          !text.segments.any((segment) => segment.term != null),
      '$slotId는 term-token 화면의 용어 문장이라 칩으로 그립니다. onTerm을 주세요.',
    );
    return RenderedTextView(
      text: text,
      style: base.copyWith(
        color: color ?? context.tokens.colors.textPrimary,
        fontSize: preview ? _previewFontSize : null,
      ),
      termStyle: onTerm == null ? TermStyle.plain : terms,
      onTerm: onTerm,
      trailing: trailing,
      maxLines: preview ? _previewMaxLines : maxLines,
      overflow: preview || maxLines != null
          ? TextOverflow.ellipsis
          : TextOverflow.clip,
    );
  }

  TermStyle _resolveTermStyle() {
    if (variant == SentenceBlockVariant.preview) return TermStyle.plain;
    final explicit = termStyle;
    if (explicit != null) return explicit;
    final id = slotId;
    if (id == null) return TermStyle.plain;
    return screenHasComponent(screenIdOfSlot(id), _termTokenComponent)
        ? TermStyle.chip
        : TermStyle.plain;
  }

  Widget _buildLocked(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: LockVeil.line(
            // 구역 이름 + "잠김"(컴포넌트 2.2.0).
            semanticLabel: [
              for (final textOf in lockedLabelTexts.values) textOf(l10n),
            ].join(', '),
            a11ySlotId: lockedLabelSlotId,
          ),
        ),
        if (onOpenLocked != null)
          DepthLink(
            variant: DepthLinkVariant.inlineEnd,
            label: l10n.sajuChartYongsinOpen,
            slotId: SlotIds.sajuChartYongsinOpen,
            onTap: onOpenLocked!,
          ),
      ],
    );
  }

  static const String _termTokenComponent = 'term-token';
  static const double _previewFontSize = 14.5;
  static const int _previewMaxLines = 2;
}
