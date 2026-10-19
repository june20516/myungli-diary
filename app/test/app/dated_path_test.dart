import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/app/router/app_router.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';

void main() {
  test('datedPathOf는 `/<화면 id>?date=YYYY-MM-DD`입니다', () {
    expect(
      datedPathOf(ScreenIds.diaryView, CalendarDate(2026, 1, 5)),
      '/diary-view?date=2026-01-05',
    );
    expect(
      datedPathOf(ScreenIds.diaryEdit, CalendarDate(2026, 10, 12)),
      '/diary-edit?date=2026-10-12',
    );
    expect(dateQuery, 'date');
  });
}
