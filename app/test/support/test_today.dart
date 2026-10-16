import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';

/// 손으로 바꾸는 "오늘". 화면이 열린 채 자정을 넘기는 것을 흉내 냅니다.
///
/// 옮기는 일은 공개 setter가 아니라 [moveTo]로 합니다(riverpod_lint가 Notifier의 공개
/// setter·getter를 막습니다).
final class TestToday extends Notifier<CalendarDate> {
  new(this._start);

  final CalendarDate _start;

  @override
  CalendarDate build() => _start;

  /// "오늘"을 [value]로 옮깁니다.
  // riverpod_lint는 공개 setter를 막고 use_setters_to_change_properties는 한 줄 대입
  // 메서드를 setter로 바꾸라 하여 둘이 부딪힙니다. 여기서는 Riverpod 쪽을 따릅니다.
  // ignore: use_setters_to_change_properties
  void moveTo(CalendarDate value) => state = value;
}

/// [start]에서 시작하는 [TestToday]의 provider.
NotifierProvider<TestToday, CalendarDate> testTodayProvider(
  CalendarDate start,
) => NotifierProvider<TestToday, CalendarDate>(() => TestToday(start));
