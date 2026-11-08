import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:myungli_diary/core/api/gen/model/tag.dart';
import 'package:myungli_diary/design/components/diary/tag_chip.dart';
import 'package:myungli_diary/design/components/sentence/hanja_glyphs.dart';
import 'package:myungli_diary/design/components/sentence/hanja_tag.dart';
import 'package:myungli_diary/features/depth/application/depth_sheets.dart';
import 'package:myungli_diary/features/depth/application/explain_content.dart';
import 'package:myungli_diary/features/glossary/model/glossary_names.dart';

/// [tag]의 칩(`tag-chip`): 이름은 용어 사전 [names](`Glossary.values.tag`), 톤은 길흉, 누르면
/// 뜻 시트(`explain-sheet`)입니다. 시트 본문 아래 꺾쇠 링크가 그 태그의 `tag-diary`로 이어집니다
/// (V73, [linked]가 false면 누를 수 없는 표시). 사전에 이름이 없으면
/// (사전을 아직 받지 못함 포함) 키를 그대로 보이지 않도록 null입니다. 쓰는 쪽은 build에서
/// `glossaryProvider`를 구독해 넘깁니다.
///
/// 목록 줄(`diary-row`)·보기·저장 순간이 같은 칩을 씁니다(`tag-chip` 규칙).
TagChip? diaryTagChipOf(
  BuildContext context,
  DepthSheets sheets,
  GlossaryNames? names,
  Tag tag, {
  bool linked = true,
}) {
  final name = names?.valueName('tag', tag.key);
  if (name == null) {
    return null;
  }
  return TagChip(
    name: name,
    variant: TagChipVariant.ofPolarity(tag.polarity),
    onTap: linked
        ? () => unawaited(_openTagExplain(context, sheets, tag.key, name))
        : null,
  );
}

/// [tags] 중 이름이 있는 태그의 칩들(순서 그대로).
List<TagChip> diaryTagChipsOf(
  BuildContext context,
  DepthSheets sheets,
  GlossaryNames? names,
  List<Tag> tags,
) => [for (final tag in tags) ?diaryTagChipOf(context, sheets, names, tag)];

/// 태그 [key]의 뜻 시트를 엽니다. 머리는 한자 글자표(A112)에 있을 때만 누를 수 없는
/// `hanja-tag`로 놓습니다.
Future<void> _openTagExplain(
  BuildContext context,
  DepthSheets sheets,
  String key,
  String name,
) {
  final glyph = HanjaGlyphs.forTagKey(key);
  return sheets.openExplain(
    context,
    ExplainTerm('tag.$key'),
    head: glyph == null ? null : HanjaTag(glyph: glyph, label: name),
    diaryLinkTag: key,
  );
}
