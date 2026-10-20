import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:myungli_diary/app/router/app_router.dart';
import 'package:myungli_diary/core/api/gen/model/tag.dart';
import 'package:myungli_diary/design/components/diary/tag_chip.dart';
import 'package:myungli_diary/features/glossary/model/glossary_names.dart';

/// [tag]의 칩(`tag-chip`): 이름은 용어 사전 [names](`Glossary.values.tag`), 톤은 길흉, 누르면
/// 그 태그의 `tag-diary`입니다. 사전에 이름이 없으면(사전을 아직 받지 못함 포함) 키를 그대로
/// 보이지 않도록 null입니다. 쓰는 쪽은 build에서 `glossaryProvider`를 구독해 넘깁니다.
///
/// 목록 줄(`diary-row`)·보기·저장 순간이 같은 칩을 씁니다(`tag-chip` 규칙).
TagChip? diaryTagChipOf(BuildContext context, GlossaryNames? names, Tag tag) {
  final name = names?.valueName('tag', tag.key);
  if (name == null) {
    return null;
  }
  return TagChip(
    name: name,
    variant: TagChipVariant.ofPolarity(tag.polarity),
    onTap: () => context.push<void>(taggedPathOf(tag.key)),
  );
}

/// [tags] 중 이름이 있는 태그의 칩들(순서 그대로).
List<TagChip> diaryTagChipsOf(
  BuildContext context,
  GlossaryNames? names,
  List<Tag> tags,
) => [for (final tag in tags) ?diaryTagChipOf(context, names, tag)];
