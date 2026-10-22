import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/app/router/app_router.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/features/diary/model/diary_edit_target.dart';

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

  test('diaryPathOf는 `/<화면 id>?id=<일기 id>`입니다', () {
    expect(diaryPathOf(ScreenIds.diaryView, 'x'), '/diary-view?id=x');
    expect(diaryPathOf(ScreenIds.diaryEdit, 'abc'), '/diary-edit?id=abc');
    expect(diaryIdQuery, 'id');
  });

  group('diaryEditTargetOf', () {
    final today = CalendarDate(2026, 10, 13);

    test('id가 있으면 date보다 앞서 그 일기를 고칩니다', () {
      expect(
        diaryEditTargetOf(Uri.parse('/diary-edit?id=x&date=2026-10-12'), today),
        const DiaryEditTarget.existing('x'),
      );
    });

    test('date만 있으면 그날 새 일기입니다', () {
      expect(
        diaryEditTargetOf(Uri.parse('/diary-edit?date=2026-10-12'), today),
        DiaryEditTarget.newOn(CalendarDate(2026, 10, 12)),
      );
    });

    test('둘 다 없거나 읽을 수 없으면 오늘 새 일기입니다', () {
      expect(
        diaryEditTargetOf(Uri.parse('/diary-edit'), today),
        DiaryEditTarget.newOn(today),
      );
      expect(
        diaryEditTargetOf(Uri.parse('/diary-edit?date=nope&id='), today),
        DiaryEditTarget.newOn(today),
      );
    });
  });
}
