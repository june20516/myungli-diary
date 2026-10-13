import 'package:flutter/material.dart';
import 'package:myungli_diary/core/api/gen/model/rendered_text.dart';
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
    this.onTerm,
    this.onOpenLocked,
    this.trailing,
    super.key,
  });

  /// 명세 대조용 요약.
  static const ComponentSpec spec = ComponentSpec(
    'sentence-block',
    {'card', 'body', 'preview'},
    {'locked'},
  );

  /// 변형.
  final SentenceBlockVariant variant;

  /// server가 렌더한 문장 조각.
  final RenderedText text;

  /// 근거·해석 열람 권한이 없는 잠긴 문장인지.
  final bool locked;

  /// 이 문장이 채우는 IA 슬롯 id(`SlotIds`). 있으면 Key와 Semantics `identifier`로 붙습니다.
  final String? slotId;

  /// 용어 조각을 눌렀을 때. `term-token`이 있는 화면에서만 줍니다. 없으면 일반 글자입니다.
  final ValueChanged<String>? onTerm;

  /// 잠긴 문장의 "열기 ›"를 눌렀을 때(근거 시트를 잠김 상태로 엽니다).
  final VoidCallback? onOpenLocked;

  /// 문장 끝에 붙는 위젯(`depth-link` `inline-end`).
  final Widget? trailing;

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
    return RenderedTextView(
      text: text,
      style: base.copyWith(
        color: context.tokens.colors.textPrimary,
        fontSize: preview ? _previewFontSize : null,
      ),
      onTerm: onTerm,
      trailing: trailing,
      maxLines: preview ? _previewMaxLines : null,
      overflow: preview ? TextOverflow.ellipsis : TextOverflow.clip,
    );
  }

  Widget _buildLocked(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: LockVeil.line(semanticLabel: l10n.evidenceSheetA11yLocked),
        ),
        if (onOpenLocked != null)
          DepthLink(
            variant: DepthLinkVariant.inlineEnd,
            label: l10n.sajuChartYongsinOpen,
            onTap: onOpenLocked!,
          ),
      ],
    );
  }

  static const double _previewFontSize = 14.5;
  static const int _previewMaxLines = 2;
}
