import 'package:flutter/material.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/calendar/event_row.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';
import 'package:myungli_diary_widgetbook/calendar_month_use_cases.dart';
import 'package:myungli_diary_widgetbook/stage.dart';
import 'package:widgetbook/widgetbook.dart';

const String _longTitle = '분기 회고와 다음 분기 계획을 함께 정리하는 긴 이름의 회의';

/// 오늘 화면 요약: 진행 중(하루 종일)·다음(외 N개)·긴 제목·모두 지남.
class _SummaryDemo extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: Space.s8,
      children: [
        EventRow.summary(
          status: EventRowStatus.inProgress,
          title: '가족 여행',
          onTap: () {},
        ),
        EventRow.summary(
          status: EventRowStatus.next,
          time: '14:00',
          title: '치과 예약',
          moreCount: 2,
          onTap: () {},
        ),
        EventRow.summary(
          status: EventRowStatus.next,
          time: '09:30',
          title: _longTitle,
          moreCount: 1,
          onTap: () {},
        ),
        EventRow.summary(
          status: null,
          title: '',
          allPastSentence: l10n.todayEventSummaryAllPast(3),
          onTap: () {},
        ),
      ],
    );
  }
}

/// 그날 시트 목록: 하루 종일·긴 제목(두 줄)·마지막 줄(구분선 없음).
class _ListDemo extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EventRow.list(time: null, title: '가족 여행', onTap: () {}),
        EventRow.list(time: '09:30', title: _longTitle, onTap: () {}),
        EventRow.list(
          time: '14:00',
          title: '치과 예약',
          showDivider: false,
          onTap: () {},
        ),
      ],
    );
  }
}

/// 일정이 없는 그날 목록.
class _EmptyDemo extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return EventRowListEmpty(
      message: l10n.daySheetEventEmpty,
      addLabel: l10n.daySheetEventAdd,
      onAdd: () {},
    );
  }
}

/// 달력 컴포넌트 카탈로그: event-row, calendar-month, day-cell.
final WidgetbookFolder calendarDirectory = WidgetbookFolder(
  name: '달력',
  children: [
    WidgetbookComponent(
      name: 'event-row',
      useCases: [
        WidgetbookUseCase(
          name: 'summary',
          builder: (context) =>
              const Stage(child: SizedBox(width: 340, child: _SummaryDemo())),
        ),
        WidgetbookUseCase(
          name: 'list',
          builder: (context) =>
              const Stage(child: SizedBox(width: 340, child: _ListDemo())),
        ),
        WidgetbookUseCase(
          name: 'list 빈 목록',
          builder: (context) =>
              const Stage(child: SizedBox(width: 340, child: _EmptyDemo())),
        ),
      ],
    ),
    ...calendarMonthComponents,
  ],
);
