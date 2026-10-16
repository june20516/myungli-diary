import 'package:myungli_diary/core/ia/gen/ia.g.dart';

/// 시트 하나의 등록 정보. page 화면의 `ScreenSpec`에 해당합니다(결정 A23).
///
/// 시트는 route가 아니라 `showMyungliSheet`로 열리므로 `screenRegistry`에 없습니다.
/// IA 대조 테스트가 시트의 상태·출구를 이 등록부에서 찾습니다.
final class SheetSpec {
  /// [id] 시트를 등록합니다.
  const new(this.id, {this.handledStates = const {}, this.exits = const {}});

  /// IA 화면 id.
  final String id;

  /// 이 시트가 직접 처리하는 IA 상태 id.
  final Set<String> handledStates;

  /// 이 시트가 실제로 이동시키는 대상 화면 id. IA exits의 대상 집합과 같아야 합니다.
  final Set<String> exits;
}

/// 시트 spec 등록부. 키는 IA 화면 id입니다.
///
/// 시트 본문을 만드는 task(explain·evidence·share-preview·day-sheet)가 자기 시트를 여기에 더합니다.
const Map<String, SheetSpec> sheetRegistry = {
  ScreenIds.explainSheet: SheetSpec(
    ScreenIds.explainSheet,
    handledStates: {'loading', 'error'},
    exits: {ScreenIds.evidenceSheet},
  ),
  ScreenIds.evidenceSheet: SheetSpec(
    ScreenIds.evidenceSheet,
    handledStates: {'loading', 'error'},
    exits: {ScreenIds.systemRewardedAd, ScreenIds.adFree},
  ),
  ScreenIds.sharePreview: SheetSpec(
    ScreenIds.sharePreview,
    exits: {ScreenIds.systemShare},
  ),
  ScreenIds.daySheet: SheetSpec(
    ScreenIds.daySheet,
    handledStates: {'loading', 'empty', 'error'},
    exits: {
      ScreenIds.eventEdit,
      ScreenIds.diaryView,
      ScreenIds.diaryEdit,
      ScreenIds.explainSheet,
    },
  ),
};
