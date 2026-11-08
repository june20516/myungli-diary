import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myungli_diary/core/api/gen/model/day_kind.dart';
import 'package:myungli_diary/core/api/gen/model/tag.dart';
import 'package:myungli_diary/core/l10n/day_kind_names.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/sentence/hanja_glyphs.dart';
import 'package:myungli_diary/design/components/sentence/hanja_tag.dart';
import 'package:myungli_diary/features/depth/application/depth_sheets.dart';
import 'package:myungli_diary/features/depth/application/explain_content.dart';
import 'package:myungli_diary/features/glossary/application/dictionary_gaps.dart';
import 'package:myungli_diary/features/glossary/application/glossary_providers.dart';

/// 일기 줄(`diary-row`)의 날의 성격 `hanja-tag`(길흉 톤, `default`).
///
/// 누르면 뜻만 있는 뜻 시트(`explain-sheet`, `day_kind.<값>`)이고 대표 태그와 달리 모아보기
/// 링크가 없습니다. 시트 머리는 같은 모양의 누를 수 없는 태그입니다(V81, V73).
HanjaTag diaryDayKindTagOf(BuildContext context, WidgetRef ref, DayKind kind) {
  HanjaTag tag({VoidCallback? onTap}) => HanjaTag(
    glyph: HanjaGlyphs.forDayKind(kind),
    label: dayKindName(AppLocalizations.of(context), kind),
    tone: HanjaGlyphs.toneOfDayKind(kind),
    onTap: onTap,
  );
  final sheets = ref.read(depthSheetsProvider);
  return tag(
    onTap: () => unawaited(
      sheets.openExplain(
        context,
        ExplainTerm('day_kind.${kind.value}'),
        head: tag(),
      ),
    ),
  );
}

/// 일기 줄의 대표 태그 `hanja-tag`(사주 용어 초록 `default`). 이름이 사전에 없거나 한자 글자표
/// (A112)에 없으면 그리지 않고 null이며, 사전을 받은 뒤에는 그 빈칸을 한 번만 비치명으로
/// 기록합니다.
///
/// 누르면 뜻 시트(`explain-sheet`, `tag.<키>`)이고, 시트 본문 아래에 그 태그의 모아보기
/// 링크(`tag-diary`)가 있습니다(V73). 쓰는 쪽은 build에서 `glossaryProvider`를 구독합니다.
HanjaTag? diaryFeaturedHanjaTagOf(
  BuildContext context,
  WidgetRef ref,
  Tag tag,
) {
  final names = ref.watch(glossaryProvider).value;
  final label = names?.valueName('tag', tag.key);
  final glyph = HanjaGlyphs.forTagKey(tag.key);
  if (label == null || glyph == null) {
    // 이름 사전을 받은 뒤에만 빈칸으로 셉니다(받기 전에는 모든 태그가 이름이 없어 보임).
    if (names != null) reportDictionaryGaps(ref.read, ['tag.${tag.key}']);
    return null;
  }
  final sheets = ref.read(depthSheetsProvider);
  return HanjaTag(
    glyph: glyph,
    label: label,
    onTap: () => unawaited(
      sheets.openExplain(
        context,
        ExplainTerm('tag.${tag.key}'),
        head: HanjaTag(glyph: glyph, label: label),
        diaryLinkTag: tag.key,
      ),
    ),
  );
}
