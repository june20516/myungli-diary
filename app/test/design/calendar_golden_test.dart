import 'package:flutter/material.dart';
import 'package:myungli_diary/design/components/calendar/event_row.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

import '../support/golden.dart';

const _longTitleKo = '분기 회고와 다음 분기 계획을 함께 정리하는 긴 이름의 회의';
const _longTitleJa = '四半期の振り返りと次の四半期の計画をまとめる長い名前の会議';

/// event-row summary: 진행 중·다음·상태 없음·긴 제목+외 N개·모두 지남.
Widget _summary() => Builder(
  builder: (context) {
    final ja = Localizations.localeOf(context).languageCode == 'ja';
    final inProgress = ja ? '進行中' : '진행 중';
    final next = ja ? '次' : '다음';
    final more = ja ? '他2件' : '외 2개';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: Space.s8,
      children: [
        EventRow.summary(
          status: EventRowStatus.inProgress,
          statusLabel: inProgress,
          time: ja ? '終日' : '하루 종일',
          title: ja ? '家族旅行' : '가족 여행',
          onTap: () {},
        ),
        EventRow.summary(
          status: EventRowStatus.next,
          statusLabel: next,
          time: '14:00',
          title: ja ? '歯医者' : '치과 예약',
          moreText: more,
          onTap: () {},
        ),
        EventRow.summary(
          status: EventRowStatus.next,
          statusLabel: next,
          time: '09:30',
          title: ja ? _longTitleJa : _longTitleKo,
          moreText: more,
          onTap: () {},
        ),
        EventRow.summary(
          status: null,
          title: '',
          allPastSentence: ja ? '今日の予定3件はすべて終わりました' : '오늘 일정 3개 모두 지났어요',
          onTap: () {},
        ),
      ],
    );
  },
);

/// event-row list: 시각·하루 종일·긴 제목(두 줄) 줄 + 빈 목록.
Widget _list() => Builder(
  builder: (context) {
    final ja = Localizations.localeOf(context).languageCode == 'ja';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EventRow.list(
          timeText: ja ? '終日' : '하루 종일',
          title: ja ? '家族旅行' : '가족 여행',
          onTap: () {},
        ),
        EventRow.list(
          timeText: '09:30',
          title: ja ? _longTitleJa : _longTitleKo,
          onTap: () {},
        ),
        EventRow.list(
          timeText: '14:00',
          title: ja ? '歯医者' : '치과 예약',
          showDivider: false,
          onTap: () {},
        ),
        const SizedBox(height: Space.s24),
        EventRowListEmpty(
          message: ja ? 'この日の予定はありません' : '이날 일정이 없어요',
          addLabel: ja ? '予定を追加' : '일정 추가',
          onAdd: () {},
        ),
      ],
    );
  },
);

void main() {
  goldenTest('event-row: summary', (tester) async {
    await goldenMatrix(tester, 'calendar_event_row_summary', _summary);
  });

  goldenTest('event-row: list + 빈 목록', (tester) async {
    await goldenMatrix(tester, 'calendar_event_row_list', _list);
  });
}
