import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/frame/sheet.dart';
import 'package:myungli_diary/design/components/frame/sheet_screen_id.dart';
import 'package:myungli_diary/features/depth/application/term_origin.dart';

/// 풀이 시트 본문. [termId]는 용어 id, [origin]은 용어가 눌린 슬롯과 그 응답입니다.
/// [origin]이 null이면 근거로 이어지지 않는 곳에서 연 것이라 근거 보기도 오늘 그런 이유도 없습니다.
typedef ExplainBodyBuilder = Widget Function(String termId, TermOrigin? origin);

/// 근거 시트 본문. [slotId]는 근거를 보는 writing 슬롯 id입니다.
typedef EvidenceBodyBuilder = Widget Function(String slotId);

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

  /// 풀이 시트(half)를 엽니다. [origin]은 용어가 들어 있던 슬롯과 그 슬롯을 담은 응답입니다.
  ///
  /// [origin]을 주지 않으면 풀이 시트에 근거 보기도 오늘 그런 이유도 없고 응답을 받지 않습니다.
  /// 그날 시트(`day-sheet`)는 IA 깊이가 `surface`·`explain`까지라 근거 시트로 이어지지 않으므로
  /// 주지 않습니다.
  Future<void> openExplain(
    BuildContext context, {
    required String termId,
    TermOrigin? origin,
  }) => showMyungliSheet<void>(
    context,
    size: SheetSize.half,
    // 제목이 아직 없는 loading·error에도 시트 이름이 알려지게 합니다.
    semanticLabel: AppLocalizations.of(context).depthExplain,
    builder: (_) => SheetScreenId(
      screenId: ScreenIds.explainSheet,
      child: explainBody(termId, origin),
    ),
  );

  /// 근거 시트(full)를 엽니다. [slotId]는 근거를 보는 슬롯 id입니다.
  Future<void> openEvidence(BuildContext context, {required String slotId}) =>
      showMyungliSheet<void>(
        context,
        size: SheetSize.full,
        // 잠긴 상태나 loading·error에서도 시트 이름이 알려지게 합니다.
        semanticLabel: AppLocalizations.of(context).evidenceSheetTitle,
        builder: (_) => SheetScreenId(
          screenId: ScreenIds.evidenceSheet,
          child: evidenceBody(slotId),
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
      (_, _) => throw UnimplementedError(_unwired),
);

/// 근거 시트 본문 builder. [explainBodyProvider]와 같은 방식으로 연결됩니다.
final evidenceBodyProvider = Provider<EvidenceBodyBuilder>(
  (ref) =>
      (_) => throw UnimplementedError(_unwired),
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
