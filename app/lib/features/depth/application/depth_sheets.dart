import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:myungli_diary/core/api/gen/model/daily.dart';
import 'package:myungli_diary/core/api/gen/model/rendered_text.dart';
import 'package:myungli_diary/core/api/rendered_text_plain.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/frame/sheet.dart';
import 'package:myungli_diary/design/components/frame/sheet_screen_id.dart';
import 'package:myungli_diary/design/components/sentence/hanja_tag.dart';
import 'package:myungli_diary/features/depth/application/explain_content.dart';
import 'package:myungli_diary/features/depth/application/personal_reading_key.dart';
import 'package:myungli_diary/features/glossary/application/glossary_providers.dart';

/// 풀이 시트 본문. [content]는 풀이할 내용이고, [head]가 있으면 제목 줄 대신 머리로 놓습니다
/// (`hanja-tag`). [diaryLinkTag]가 있으면 본문 아래에 그 태그(키)의 모아보기 링크를 둡니다.
typedef ExplainBodyBuilder = Widget Function(
  ExplainContent content, {
  Widget? head,
  String? diaryLinkTag,
});

/// 근거 시트 위 대상(`depth-link.evidenceSheet.target`, D108, 결정 V80): 그 문장을 정한 태그 줄과
/// 대상 문장. 태그와 문장이 없는 자리(용어 풀이 시트, 사주 표 계열)는 [none]입니다.
@immutable
final class EvidenceTarget {
  /// 태그 줄 [tags]와 대상 문장 [sentence]로 만듭니다.
  const new({this.tags = const [], this.sentence});

  /// 대상이 없는 근거 시트.
  static const EvidenceTarget none = EvidenceTarget();

  /// 그 문장을 정한 태그(누를 수 없는 `hanja-tag` `default`). 비면 태그 줄이 없습니다.
  final List<HanjaTag> tags;

  /// 대상 문장(연 화면의 그 문장). 없으면 문장 줄이 없습니다.
  final RenderedText? sentence;
}

/// 근거 시트 본문. [slotId]는 근거를 보는 writing 슬롯 id이고, [personal]은 "내 사주에서는"에
/// 보일 원국 개인 해석의 자리입니다(사주 표 칸 용어에서 열었을 때만, A58). [target]은 시트 위
/// 대상입니다.
typedef EvidenceBodyBuilder = Widget Function(
  String slotId,
  PersonalReadingKey? personal,
  EvidenceTarget target,
);

/// 공유 미리보기 시트 본문.
typedef ShareBodyBuilder = Widget Function();

/// 사주 기운 시트(`tag-sheet`) 본문. [daily]는 그날 응답이고 [rank]는 누른 대표 태그의
/// `tags.featured` 순번(0이 1순위, A113)입니다.
typedef TagBodyBuilder = Widget Function(Daily daily, int rank);

/// 사주 기운 시트 본문이 연결되지 않았을 때. [tagBodyProvider]의 기본값과 같습니다.
Widget _unwiredTagBody(Daily daily, int rank) =>
    throw UnimplementedError(_unwired);

/// 깊이 시트(풀이·근거·공유 미리보기·사주 기운)를 어느 화면에서든 같은 호출로 여는 서비스(결정 A23).
///
/// 열고 닫는 움직임·햅틱·쌓임은 `showMyungliSheet`가 처리합니다.
/// 본문은 주입받으므로 시트를 만드는 task가 builder만 바꿔 끼웁니다.
final class DepthSheets {
  /// 시트 본문 builder를 받습니다. [tagBody]를 주지 않으면 사주 기운 시트를 열 때 실패합니다.
  const new({
    required this.explainBody,
    required this.evidenceBody,
    required this.shareBody,
    this.tagBody = _unwiredTagBody,
    this.termHasBody = _alwaysHasBody,
  });

  /// 풀이 시트 본문.
  final ExplainBodyBuilder explainBody;

  /// 근거 시트 본문.
  final EvidenceBodyBuilder evidenceBody;

  /// 공유 미리보기 시트 본문.
  final ShareBodyBuilder shareBody;

  /// 사주 기운 시트 본문.
  final TagBodyBuilder tagBody;

  /// 용어 풀이 시트에 보일 본문(뜻이나 오늘 그런 이유)이 있는지. 모르면 true입니다(A130).
  final TermBodyCheck termHasBody;

  /// 풀이 시트(half)를 엽니다. [content]는 풀이할 내용입니다([ExplainTerm]은 용어가 들어 있던
  /// 슬롯과 그 슬롯을 담은 응답을 [ExplainTerm.origin]으로 갖습니다).
  ///
  /// [ExplainTerm.origin]을 주지 않으면 풀이 시트에 근거 보기도 오늘 그런 이유도 없고 응답을 받지
  /// 않습니다. 그날 시트(`day-sheet`)는 IA 깊이가 `surface`·`explain`까지라 근거 시트로 이어지지
  /// 않으므로 주지 않습니다. [head]는 제목 자리에 놓을 머리(`hanja-tag`)이고, [diaryLinkTag]는
  /// 대표 태그의 뜻 시트에서만 주는 태그 키입니다(본문 아래 모아보기 링크, `tag-diary` page.push).
  ///
  /// 용어([ExplainTerm])에 뜻도 오늘 그런 이유도 없고([termHasBody]가 false) 근거 출처가 있으면,
  /// 이름과 근거 아이콘만 남는 풀이 시트 대신 그 근거 시트를 바로 엽니다(A130, #957). 시트를 열기
  /// 전에 정하므로 시트가 겹치지 않습니다. 출처가 없으면 갈 곳이 없어 풀이 시트(이름만)입니다.
  Future<void> openExplain(
    BuildContext context,
    ExplainContent content, {
    Widget? head,
    String? diaryLinkTag,
  }) {
    if (content case ExplainTerm(:final origin?) when !termHasBody(content)) {
      return openEvidence(context, origin.slotId, personal: origin.personal);
    }
    return _showExplain(
      context,
      content,
      head: head,
      diaryLinkTag: diaryLinkTag,
    );
  }

  Future<void> _showExplain(
    BuildContext context,
    ExplainContent content, {
    Widget? head,
    String? diaryLinkTag,
  }) => showMyungliSheet<void>(
    context,
    size: SheetSize.half,
    // 제목이 아직 없는 loading·error에도 시트 이름이 알려지게 합니다.
    semanticLabel: AppLocalizations.of(context).depthExplain,
    builder: (_) => SheetScreenId(
      screenId: ScreenIds.explainSheet,
      child: explainBody(content, head: head, diaryLinkTag: diaryLinkTag),
    ),
  );

  /// 근거 시트(full)를 엽니다. [slotId]는 근거를 보는 슬롯 id이고, 같은 슬롯을 여러 카드가 쓰는
  /// 오늘 행운 카드는 카드 id(`<슬롯>#<카드 필드>`, `dailyCardSlotId`, A134)입니다.
  ///
  /// [personal]을 주면 그 자리의 원국 개인 해석("내 사주에서는") 구역을 함께 둡니다(A58).
  /// [headTags]와 [target]은 시트 위 대상(그 문장을 정한 태그와 대상 문장, 결정 V80)이고, 용어나
  /// 사주 표에서 연 근거는 주지 않습니다.
  Future<void> openEvidence(
    BuildContext context,
    String slotId, {
    PersonalReadingKey? personal,
    List<HanjaTag> headTags = const [],
    RenderedText? target,
  }) => showMyungliSheet<void>(
    context,
    size: SheetSize.full,
    // 잠긴 상태나 loading·error에서도 시트 이름이 알려지게 합니다.
    semanticLabel: AppLocalizations.of(context).evidenceSheetTitle,
    builder: (_) => SheetScreenId(
      screenId: ScreenIds.evidenceSheet,
      child: evidenceBody(
        slotId,
        personal,
        EvidenceTarget(tags: headTags, sentence: target),
      ),
    ),
  );

  /// 사주 기운 시트(half, 내용 높이)를 엽니다. [rank]는 누른 대표 태그의 `daily.tags.featured`
  /// 순번(0이 1순위, 1이 2순위)입니다(A113). 시트가 닫히면 끝나므로, 여는 쪽은 그동안 누른
  /// 태그를 `selected`로 둡니다.
  Future<void> openTag(
    BuildContext context, {
    required Daily daily,
    required int rank,
  }) {
    assert(
      rank >= 0 && rank < daily.tags.featured.length,
      '대표 태그 순번 $rank이 응답 범위 밖입니다',
    );
    return showMyungliSheet<void>(
      context,
      size: SheetSize.half,
      // 시트 이름은 IA tag-sheet의 이름(사주 기운)입니다.
      semanticLabel: AppLocalizations.of(context).todayFeaturedTitle,
      builder: (_) => SheetScreenId(
        screenId: ScreenIds.tagSheet,
        child: tagBody(daily, rank),
      ),
    );
  }

  /// 공유 미리보기 시트(half)를 엽니다.
  Future<void> openSharePreview(BuildContext context) => showMyungliSheet<void>(
    context,
    size: SheetSize.half,
    // 불러오는 중에도 시트 이름이 알려지게 합니다.
    semanticLabel: AppLocalizations.of(context).shareLabel,
    builder: (_) =>
        SheetScreenId(screenId: ScreenIds.sharePreview, child: shareBody()),
  );
}

/// 본문 provider를 연결하지 않았을 때의 오류 설명.
const String _unwired = 'depthSheetBodyOverrides를 연결하세요';

/// 풀이 시트 본문 builder. 기본값은 실패이고(조용히 빈 시트가 되지 않게) 조합 계층(`lib/app/depth_sheet_bodies.dart`)이
/// override로 실제 시트를 연결합니다(feature presentation끼리 import하지 않기 위해, spec §2).
final explainBodyProvider = Provider<ExplainBodyBuilder>(
  (ref) =>
      (_, {head, diaryLinkTag}) => throw UnimplementedError(_unwired),
);

/// 근거 시트 본문 builder. [explainBodyProvider]와 같은 방식으로 연결됩니다.
final evidenceBodyProvider = Provider<EvidenceBodyBuilder>(
  (ref) =>
      (_, _, _) => throw UnimplementedError(_unwired),
);

/// 공유 미리보기 시트 본문 builder. [explainBodyProvider]와 같은 방식으로 연결됩니다.
final shareBodyProvider = Provider<ShareBodyBuilder>(
  (ref) =>
      () => throw UnimplementedError(_unwired),
);

/// 사주 기운 시트 본문 builder. [explainBodyProvider]와 같은 방식으로 연결됩니다.
final tagBodyProvider = Provider<TagBodyBuilder>((ref) => _unwiredTagBody);

/// 깊이 시트 서비스. 본문은 위 네 provider에서 받습니다.
final depthSheetsProvider = Provider<DepthSheets>(
  (ref) => DepthSheets(
    explainBody: ref.watch(explainBodyProvider),
    evidenceBody: ref.watch(evidenceBodyProvider),
    shareBody: ref.watch(shareBodyProvider),
    tagBody: ref.watch(tagBodyProvider),
    termHasBody: (term) => termHasBodyIn(ref.read, term),
  ),
);

/// 용어 풀이 시트에 보일 본문이 있는지 판단합니다([DepthSheets.termHasBody]).
typedef TermBodyCheck = bool Function(ExplainTerm term);

bool _alwaysHasBody(ExplainTerm _) => true;

/// [term]의 풀이 시트에 뜻이나 오늘 그런 이유가 있는지. 사전을 아직 받지 못했으면(뜻을 모름)
/// true라 풀이 시트가 받는 동안 skeleton을 보입니다. 사전 뜻(`Glossary.meanings`)과 오늘 그런
/// 이유(`SlotText.todayReason`)는 계약상 비어 있을 수 있습니다.
bool termHasBodyIn(
  T Function<T>(ProviderListenable<T> provider) read,
  ExplainTerm term,
) {
  final names = read(glossaryProvider).value;
  if (names == null) return true;
  final meaning = names.meaningOf(term.termId);
  if (meaning != null && !isBlankText(meaning)) return true;
  final origin = term.origin;
  if (origin == null) return true;
  return read(origin.subject.todayReasonOf(origin.slotId)) != null;
}
