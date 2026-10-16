import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/design/components/frame/sheet.dart';
import 'package:myungli_diary/design/components/frame/sheet_screen_id.dart';

/// 그날 시트 본문. [date]는 그 날(양력)입니다.
typedef DaySheetBodyBuilder = Widget Function(CalendarDate date);

/// 그날 시트(`day-sheet`)를 어느 화면에서든 같은 호출로 여는 서비스.
///
/// 달력의 날짜 누름과 오늘 화면의 일정 한 줄이 함께 씁니다. 열고 닫는 움직임·쌓임은
/// `showMyungliSheet`가 처리하고, 본문은 주입받습니다(`DepthSheets`와 같은 방식).
final class DaySheets {
  /// 본문 builder를 받습니다.
  const new({required this.body});

  /// 그날 시트 본문.
  final DaySheetBodyBuilder body;

  /// [date]의 그날 시트(half)를 엽니다. 시트 이름은 그 날짜입니다(제목 글자가 없는 시트라
  /// loading·error에도 어느 날인지 알려지게, A38 `DateFormat`).
  Future<void> open(BuildContext context, CalendarDate date) {
    final locale = Localizations.localeOf(context).toString();
    return showMyungliSheet<void>(
      context,
      size: SheetSize.half,
      semanticLabel: DateFormat.MMMMEEEEd(locale)
          .format(DateTime(date.year, date.month, date.day)),
      builder: (_) =>
          SheetScreenId(screenId: ScreenIds.daySheet, child: body(date)),
    );
  }
}

/// 그날 시트 본문 builder. 기본값은 실패이고(조용히 빈 시트가 되지 않게) 조합 계층
/// (`lib/app/depth_sheet_bodies.dart`)이 override로 실제 본문을 연결합니다(feature
/// presentation끼리 import하지 않기 위해, spec §2).
final daySheetBodyProvider = Provider<DaySheetBodyBuilder>(
  (ref) =>
      (_) => throw UnimplementedError('daySheetBodyOverrides를 연결하세요'),
);

/// 그날 시트 서비스. 본문은 [daySheetBodyProvider]에서 받습니다.
final daySheetsProvider = Provider<DaySheets>(
  (ref) => DaySheets(body: ref.watch(daySheetBodyProvider)),
);
