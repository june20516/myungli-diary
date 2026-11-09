import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/ia/ia_lookup.dart';

void main() {
  test('screenIdOfSlot은 슬롯 id의 첫 마디', () {
    expect(screenIdOfSlot(SlotIds.todayFortuneBody), ScreenIds.today);
    expect(screenIdOfSlot(SlotIds.sajuChartYongsinBasis), ScreenIds.sajuChart);
  });

  test('screenHasComponent는 IA 화면의 components를 본다', () {
    expect(screenHasComponent(ScreenIds.today, 'term-token'), isTrue);
    expect(screenHasComponent(ScreenIds.diaryList, 'term-token'), isFalse);
    expect(screenHasComponent('no-such-screen', 'term-token'), isFalse);
  });

  test('term-token이 있는 화면은 IA v5의 네 화면(그날 시트는 날의 성격 이유 줄이 없어져 뺌)', () {
    final screens = {
      for (final screen in iaScreens)
        if (screenHasComponent(screen.id, 'term-token')) screen.id,
    };
    expect(screens, {
      ScreenIds.today,
      ScreenIds.tagDiary,
      ScreenIds.mySaju,
      ScreenIds.sajuChart,
    });
  });
}
