import 'package:myungli_diary/core/api/gen/model/day_kind.dart';
import 'package:myungli_diary/design/components/sentence/hanja_glyphs.dart';
import 'package:myungli_diary/design/components/sentence/hanja_tag.dart';
import 'package:myungli_diary/design/elements/open_ring.dart';

/// 날의 성격 [kind]의 `hanja-tag`: 한자 글자표와 길흉 톤은 [kind]에서 정하고 글자는 [label]입니다.
///
/// 오늘, 그날 시트, 일기 줄이 같은 모양을 함께 씁니다. 누르면 뜻 시트를 여는 화면(누를 수 있음,
/// [onTap])과 그 시트의 머리(누를 수 없음)에 [variant]만 달리해 같은 태그를 그립니다.
HanjaTag dayKindHanjaTag({
  required DayKind kind,
  required String label,
  HanjaTagVariant variant = HanjaTagVariant.normal,
  SheetTap? onTap,
}) => HanjaTag(
  glyph: HanjaGlyphs.forDayKind(kind),
  label: label,
  tone: HanjaGlyphs.toneOfDayKind(kind),
  variant: variant,
  onTap: onTap,
);
