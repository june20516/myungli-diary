import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/frame/sheet.dart';
import 'package:myungli_diary/design/components/frame/sheet_screen_id.dart';
import 'package:myungli_diary/features/depth/application/explain_content.dart';
import 'package:myungli_diary/features/depth/application/personal_reading_key.dart';

/// 풀이 시트 본문. [content]는 풀이할 내용이고, [head]가 있으면 제목 줄 대신 머리로 놓습니다
/// (`hanja-tag`). [diaryLinkTag]가 있으면 본문 아래에 그 태그(키)의 모아보기 링크를 둡니다.
typedef ExplainBodyBuilder = Widget Function(
  ExplainContent content, {
  Widget? head,
  String? diaryLinkTag,
});

/// 근거 시트 본문. [slotId]는 근거를 보는 writing 슬롯 id이고, [personal]은 "내 사주에서는"에
/// 보일 원국 개인 해석의 자리입니다(사주 표 칸 용어에서 열었을 때만, A58).
typedef EvidenceBodyBuilder = Widget Function(
  String slotId,
  PersonalReadingKey? personal,
);

/// 공유 미리보기 시트 본문.
typedef ShareBodyBuilder = Widget Function();

/// 깊이 시트(풀이·근거·공유 미리보기)를 어느 화면에서든 같은 호출로 여는 서비스(결정 A23).
///
/// 열고 닫는 움직임·햅틱·쌓임은 `showMyungliSheet`가 처리합니다.
/// 본문은 주입받으므로 시트를 만드는 task가 builder만 바꿔 끼웁니다.
final class DepthSheets {
  /// 세 시트의 본문 builder를 받습니다.
  const new({
    required this.explainBody,
    required this.evidenceBody,
    required this.shareBody,
  });

  /// 풀이 시트 본문.
  final ExplainBodyBuilder explainBody;

  /// 근거 시트 본문.
  final EvidenceBodyBuilder evidenceBody;

  /// 공유 미리보기 시트 본문.
  final ShareBodyBuilder shareBody;

  /// 풀이 시트(half)를 엽니다. [content]는 풀이할 내용입니다([ExplainTerm]은 용어가 들어 있던
  /// 슬롯과 그 슬롯을 담은 응답을 [ExplainTerm.origin]으로 갖습니다).
  ///
  /// [ExplainTerm.origin]을 주지 않으면 풀이 시트에 근거 보기도 오늘 그런 이유도 없고 응답을 받지
  /// 않습니다. 그날 시트(`day-sheet`)는 IA 깊이가 `surface`·`explain`까지라 근거 시트로 이어지지
  /// 않으므로 주지 않습니다. [head]는 제목 자리에 놓을 머리(`hanja-tag`)이고, [diaryLinkTag]는
  /// 대표 태그의 뜻 시트에서만 주는 태그 키입니다(본문 아래 모아보기 링크, `tag-diary` page.push).
  Future<void> openExplain(
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

  /// 근거 시트(full)를 엽니다. [slotId]는 근거를 보는 슬롯 id입니다.
  ///
  /// [personal]을 주면 그 자리의 원국 개인 해석("내 사주에서는") 구역을 함께 둡니다(A58).
  Future<void> openEvidence(
    BuildContext context, {
    required String slotId,
    PersonalReadingKey? personal,
  }) => showMyungliSheet<void>(
    context,
    size: SheetSize.full,
    // 잠긴 상태나 loading·error에서도 시트 이름이 알려지게 합니다.
    semanticLabel: AppLocalizations.of(context).evidenceSheetTitle,
    builder: (_) => SheetScreenId(
      screenId: ScreenIds.evidenceSheet,
      child: evidenceBody(slotId, personal),
    ),
  );

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
      (_, _) => throw UnimplementedError(_unwired),
);

/// 공유 미리보기 시트 본문 builder. [explainBodyProvider]와 같은 방식으로 연결됩니다.
final shareBodyProvider = Provider<ShareBodyBuilder>(
  (ref) =>
      () => throw UnimplementedError(_unwired),
);

/// 깊이 시트 서비스. 본문은 위 세 provider에서 받습니다.
final depthSheetsProvider = Provider<DepthSheets>(
  (ref) => DepthSheets(
    explainBody: ref.watch(explainBodyProvider),
    evidenceBody: ref.watch(evidenceBodyProvider),
    shareBody: ref.watch(shareBodyProvider),
  ),
);
