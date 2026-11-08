import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/frame/sheet.dart';
import 'package:myungli_diary/design/components/frame/sheet_screen_id.dart';

/// 색 규칙 시트(`color-rule-sheet`) 본문.
typedef ColorRuleSheetBodyBuilder = Widget Function();

/// 색 규칙 시트를 달력 범례 입구에서 여는 서비스.
///
/// 열고 닫는 움직임·쌓임은 `showMyungliSheet`가 처리하고, 본문은 주입받습니다
/// (`DaySheets`와 같은 방식).
final class ColorRuleSheets {
  /// 본문 builder를 받습니다.
  const new({required this.body});

  /// 색 규칙 시트 본문.
  final ColorRuleSheetBodyBuilder body;

  /// 색 규칙 시트(half)를 엽니다. 시트 이름은 제목 슬롯 문구입니다.
  Future<void> open(BuildContext context) => showMyungliSheet<void>(
    context,
    size: SheetSize.half,
    semanticLabel: AppLocalizations.of(context).colorRuleSheetSheetTitle,
    builder: (_) =>
        SheetScreenId(screenId: ScreenIds.colorRuleSheet, child: body()),
  );
}

/// 색 규칙 시트 본문 builder. 기본값은 실패이고(조용히 빈 시트가 되지 않게) 본문을 만드는
/// 쪽이 조합 계층(`lib/app/depth_sheet_bodies.dart`)에서 override로 연결합니다.
final colorRuleSheetBodyProvider = Provider<ColorRuleSheetBodyBuilder>(
  (ref) =>
      () => throw UnimplementedError('colorRuleSheetBodyOverrides를 연결하세요'),
);

/// 색 규칙 시트 서비스. 본문은 [colorRuleSheetBodyProvider]에서 받습니다.
final colorRuleSheetsProvider = Provider<ColorRuleSheets>(
  (ref) => ColorRuleSheets(body: ref.watch(colorRuleSheetBodyProvider)),
);
