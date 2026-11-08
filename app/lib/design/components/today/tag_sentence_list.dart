import 'package:flutter/material.dart';
import 'package:myungli_diary/core/api/gen/model/rendered_text.dart';
import 'package:myungli_diary/design/components/component_spec.dart';
import 'package:myungli_diary/design/components/sentence/rendered_text_view.dart';
import 'package:myungli_diary/design/components/sentence/sentence_block.dart';
import 'package:myungli_diary/design/elements/list_divider.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

/// 사주 기운 시트 목록의 문장 한 줄: 왼쪽 이름 칸 글자와 오늘 문장.
@immutable
final class TagSentence {
  /// 이름 칸 글자 [kindLabel]("보조 문장", "오늘의 질문")과 문장 [text]로 만듭니다.
  const new({required this.kindLabel, required this.text});

  /// 이름 칸 글자.
  final String kindLabel;

  /// server가 렌더한 오늘 문장.
  final RenderedText text;
}

/// "이 기운에서 나온 오늘 문장" 목록(`tag-sentence-list`, D108, V79).
///
/// 줄마다 왼쪽 이름 칸([labelWidth], 폭 고정)과 [SentenceBlock] 본문이고, 줄 사이는
/// `list.divider`입니다(첫 줄 위와 끝 줄 아래에는 선이 없음). 이름이 넘치면 칸 안에서 줄바꿈하고
/// 문장 칸 폭은 줄이지 않습니다. 문장 줄은 누를 수 없고, 시트 안이라 용어 조각도 일반 글자입니다.
/// [items]가 비면 줄 없이 [emptyText] 안내 한 줄만 둡니다.
class TagSentenceList extends StatelessWidget {
  /// 목록을 만듭니다. [title]은 머리 글자, [emptyText]는 문장이 없을 때의 안내입니다.
  const new({
    required this.title,
    required this.items,
    required this.emptyText,
    super.key,
  });

  /// 명세 대조용 요약.
  static const ComponentSpec spec = ComponentSpec('tag-sentence-list', {}, {
    'empty',
    'pressed',
  });

  /// 이름 칸 폭(`parts.row.label.width` 52px).
  static const double labelWidth = 52;

  /// 머리 글자와 목록 사이 간격(`parts.head.marginBottom`).
  static const double headGap = Space.s8;

  /// 줄 위아래 안쪽 여백(`parts.row.paddingTop`, `paddingBottom`).
  static const double rowPadding = Space.s12;

  /// 이름 칸과 문장 사이 간격(`parts.row.sentence.marginStart`).
  static const double sentenceGap = Space.s8;

  /// 안내 한 줄을 찾는 테스트용 키.
  static const Key emptyKey = ValueKey('tag-sentence-list-empty');

  /// 이름 칸을 찾는 테스트용 키.
  static const Key labelKey = ValueKey('tag-sentence-list-label');

  /// 머리 글자.
  final String title;

  /// 문장 줄(화면 순서대로). 비면 [emptyText]만 보입니다.
  final List<TagSentence> items;

  /// 문장이 없을 때 안내 한 줄.
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          header: true,
          child: Text(
            title,
            style: tokens.typography.labelMd.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ),
        const SizedBox(height: headGap),
        if (items.isEmpty)
          Text(
            emptyText,
            key: emptyKey,
            style: tokens.typography.bodyUi.copyWith(
              color: colors.textSecondary,
            ),
          )
        else
          for (final (index, item) in items.indexed) ...[
            if (index > 0) const ListDivider(indentStart: 0, indentEnd: 0),
            _Row(item: item),
          ],
      ],
    );
  }
}

/// 문장 한 줄. 이름 칸과 문장을 한 덩어리로 읽습니다(`a11y.rowLabel`).
class _Row extends StatelessWidget {
  const new({required this.item});

  final TagSentence item;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: TagSentenceList.rowPadding,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            SizedBox(
              width: TagSentenceList.labelWidth,
              child: Text(
                item.kindLabel,
                key: TagSentenceList.labelKey,
                style: tokens.typography.captionMd.copyWith(
                  color: tokens.colors.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: TagSentenceList.sentenceGap),
            Expanded(
              child: SentenceBlock(
                variant: SentenceBlockVariant.body,
                text: item.text,
                termStyle: TermStyle.plain,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
