import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/gen/model/city.dart';
import 'package:myungli_diary/design/components/action/breathing_dots.dart';
import 'package:myungli_diary/design/components/feedback/empty_state.dart';
import 'package:myungli_diary/design/components/feedback/error_state.dart';
import 'package:myungli_diary/design/components/input/city_search.dart';
import 'package:myungli_diary/design/components/sentence/press_ink_target.dart';
import 'package:myungli_diary/design/elements/skeleton_bone.dart';

import 'input_harness.dart';

final _seoul = City(
  id: '1835848',
  name: 'Seoul',
  country: 'KR',
  countryName: 'South Korea',
  timezone: 'Asia/Seoul',
  longitude: 126.9780,
);
final _newYork = City(
  id: '5128581',
  name: 'New York City',
  country: 'US',
  countryName: 'United States',
  regionName: 'New York',
  timezone: 'America/New_York',
  longitude: -74.0060,
);
final _busan = City(
  id: '1838524',
  name: 'Busan',
  country: 'KR',
  countryName: 'South Korea',
  timezone: 'Asia/Seoul',
  longitude: 129.0756,
);

Widget _search({
  AsyncValue<List<City>>? results,
  ValueChanged<String>? onQueryChanged,
  ValueChanged<City>? onSelected,
  VoidCallback? onRetry,
  String? savingCityId,
}) => CitySearch(
  label: '도시 이름',
  hint: '예: Seoul',
  onQueryChanged: onQueryChanged ?? (_) {},
  results: results,
  onSelected: onSelected ?? (_) {},
  emptyBody: '찾는 도시가 없어요.',
  onRetry: onRetry ?? () {},
  savingCityId: savingCityId,
  skeletonDelay: Duration.zero,
  animated: false,
);

/// 글자가 [text]인 [RichText]의 말단 조각 목록.
List<TextSpan> _spansOf(WidgetTester tester, String text) {
  final rich = tester
      .widgetList<RichText>(find.byType(RichText))
      .firstWhere((widget) => widget.text.toPlainText() == text);
  final leaves = <TextSpan>[];
  void collect(InlineSpan span) {
    if (span is! TextSpan) return;
    if (span.text != null) leaves.add(span);
    span.children?.forEach(collect);
  }

  collect(rich.text);
  return leaves;
}

void main() {
  group('city-search', () {
    testWidgets('검색어 "seo"에 결과 Seoul이면 맞는 부분 "Seo"만 굵습니다', (tester) async {
      await tester.pumpWidget(
        inputApp(Center(child: _search(results: AsyncData([_seoul])))),
      );
      await tester.enterText(find.byType(TextField), 'seo');
      await tester.pump();

      final spans = _spansOf(tester, 'Seoul');
      final bold = spans.where(
        (span) => span.style?.fontWeight == FontWeight.w600,
      );
      expect(bold.map((span) => span.text), ['Seo']);
      final plain = spans.where(
        (span) => span.style?.fontWeight != FontWeight.w600,
      );
      expect(plain.map((span) => span.text).join(), 'ul');
    });

    testWidgets('검색어를 칠 때마다 onQueryChanged가 불립니다', (tester) async {
      final queries = <String>[];
      await tester.pumpWidget(
        inputApp(Center(child: _search(onQueryChanged: queries.add))),
      );
      await tester.enterText(find.byType(TextField), 'bus');
      expect(queries, ['bus']);
    });

    testWidgets('results가 null이면 결과 자리가 없습니다', (tester) async {
      await tester.pumpWidget(inputApp(Center(child: _search())));
      expect(find.byKey(CitySearch.resultsKey), findsNothing);
      expect(find.byType(SkeletonBone), findsNothing);
    });

    testWidgets('loading이면 skeleton 줄이 3개입니다', (tester) async {
      await tester.pumpWidget(
        inputApp(Center(child: _search(results: const AsyncLoading()))),
      );
      await tester.pump();
      expect(find.byType(SkeletonBone), findsNWidgets(3));
      // 줄이 실제로 카드 너비를 채워 그려져야 보입니다.
      final field = tester.getSize(find.byType(TextField)).width;
      for (final bone in tester.widgetList(find.byType(SkeletonBone))) {
        expect(tester.getSize(find.byWidget(bone)).width, greaterThan(field));
      }
    });

    testWidgets('빈 목록이면 emptyBody가 보입니다', (tester) async {
      await tester.pumpWidget(
        inputApp(
          SingleChildScrollView(child: _search(results: const AsyncData([]))),
        ),
      );
      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.text('찾는 도시가 없어요.'), findsOneWidget);
    });

    testWidgets('오류면 ErrorState가 보이고 다시 시도가 onRetry를 부릅니다', (tester) async {
      var retried = 0;
      await tester.pumpWidget(
        inputApp(
          SingleChildScrollView(
            child: _search(
              results: const AsyncError<List<City>>(
                OfflineError(),
                StackTrace.empty,
              ),
              onRetry: () => retried++,
            ),
          ),
        ),
      );
      expect(find.byType(ErrorState), findsOneWidget);
      await tester.tap(find.text('다시 시도'));
      expect(retried, 1);
    });

    testWidgets('지역 줄은 "행정 구역, 나라 이름"이고 나라 코드는 보이지 않습니다', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        inputApp(Center(child: _search(results: AsyncData([_newYork])))),
      );
      expect(find.text('New York City'), findsOneWidget);
      expect(find.text('New York, United States'), findsOneWidget);
      expect(find.textContaining('US'), findsNothing);
      // 결과 줄은 결과 수 알림과 따로 읽히고 누를 수 있습니다.
      final row = find.bySemanticsLabel(
        'New York City, New York, United States',
      );
      expect(row, findsOneWidget);
      expect(
        tester
            .getSemantics(row)
            .getSemanticsData()
            .hasAction(SemanticsAction.tap),
        isTrue,
      );
      expect(find.bySemanticsLabel('결과 1개'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('행정 구역이 없으면 나라 이름만 보입니다', (tester) async {
      await tester.pumpWidget(
        inputApp(Center(child: _search(results: AsyncData([_seoul])))),
      );
      expect(find.text('Seoul'), findsOneWidget);
      expect(find.text('South Korea'), findsOneWidget);
      expect(find.text('KR'), findsNothing);
    });

    testWidgets('지역 이름이 하나도 없으면 지역 줄을 그리지 않고 줄 높이는 56입니다', (tester) async {
      final nameless = City(
        id: '1',
        name: 'Somewhere',
        country: 'KR',
        countryName: ' ',
        timezone: 'Asia/Seoul',
        longitude: 126.9780,
      );
      await tester.pumpWidget(
        inputApp(Center(child: _search(results: AsyncData([nameless])))),
      );
      final row = find.byKey(CitySearch.rowKey(nameless.id));
      expect(
        find.descendant(of: row, matching: find.byType(Text)),
        findsOneWidget,
      );
      expect(find.text('KR'), findsNothing);
      expect(tester.getSize(row).height, greaterThanOrEqualTo(56));
    });

    test('cityRegionLine은 이름이 있는 것만 잇습니다', () {
      expect(
        cityRegionLine(_newYork, languageCode: 'en'),
        'New York, United States',
      );
      expect(cityRegionLine(_seoul, languageCode: 'en'), 'South Korea');
    });

    testWidgets('줄을 누르면 onSelected가 그 도시로 한 번 불립니다', (tester) async {
      final selected = <City>[];
      await tester.pumpWidget(
        inputApp(
          Center(
            child: _search(
              results: AsyncData([_seoul, _busan]),
              onSelected: selected.add,
            ),
          ),
        ),
      );
      await tester.tap(find.text('Busan'));
      await tester.pumpAndSettle();
      expect(selected, [_busan]);
    });

    testWidgets('이전 값이 빈 목록인 채 loading이 오면 빈 상태 대신 skeleton입니다', (
      tester,
    ) async {
      await tester.pumpWidget(
        inputApp(
          SingleChildScrollView(
            child: _search(
              // 이전 값을 붙인 상태는 provider가 만드는 것이라 내부 API를 씁니다.
              // ignore: invalid_use_of_internal_member
              results: const AsyncLoading<List<City>>().copyWithPrevious(
                const AsyncData([]),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(EmptyState), findsNothing);
      expect(find.text('찾는 도시가 없어요.'), findsNothing);
      expect(find.byType(SkeletonBone), findsNWidgets(3));
    });

    testWidgets('결과 수를 "결과 N개"로 알립니다', (tester) async {
      await tester.pumpWidget(
        inputApp(Center(child: _search(results: AsyncData([_seoul, _busan])))),
      );
      expect(find.bySemanticsLabel('결과 2개'), findsOneWidget);
    });

    testWidgets('결과 줄 높이는 56 이상입니다', (tester) async {
      await tester.pumpWidget(
        inputApp(Center(child: _search(results: AsyncData([_seoul])))),
      );
      final row = find.byKey(CitySearch.rowKey(_seoul.id));
      expect(tester.getSize(row).height, greaterThanOrEqualTo(56));
    });

    testWidgets('결과가 바뀌어도 스크롤 위치가 그대로입니다', (tester) async {
      final results = ValueNotifier<AsyncValue<List<City>>>(
        AsyncData([_seoul, _busan]),
      );
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        inputApp(
          SingleChildScrollView(
            controller: controller,
            child: Column(
              children: [
                const SizedBox(height: 900),
                ValueListenableBuilder(
                  valueListenable: results,
                  builder: (context, value, _) => _search(results: value),
                ),
                const SizedBox(height: 900),
              ],
            ),
          ),
        ),
      );
      controller.jumpTo(700);
      await tester.pump();

      // 다시 불러오는 동안(이전 값이 남은 loading)에도, 새 값이 와도 제자리입니다.
      // 실제로는 provider가 이전 값을 붙여 내보내는 상태입니다(테스트에서 직접 만듦).
      // ignore: invalid_use_of_internal_member
      results.value = const AsyncLoading<List<City>>().copyWithPrevious(
        AsyncData([_seoul, _busan]),
      );
      await tester.pump();
      expect(controller.offset, 700);
      expect(find.byType(SkeletonBone), findsNothing);

      results.value = AsyncData([_busan, _seoul]);
      await tester.pump();
      expect(controller.offset, 700);
      expect(find.text('Busan'), findsOneWidget);
    });
  });

  group('saving', () {
    testWidgets('savingCityId인 줄 끝에 점 숨쉬기가 있고 다른 줄은 눌리지 않습니다', (tester) async {
      final selected = <City>[];
      await tester.pumpWidget(
        inputApp(
          Center(
            child: _search(
              results: AsyncData([_seoul, _busan]),
              savingCityId: _seoul.id,
              onSelected: selected.add,
            ),
          ),
        ),
      );
      expect(
        find.descendant(
          of: find.byKey(CitySearch.rowKey(_seoul.id)),
          matching: find.byType(BreathingDots),
        ),
        findsOneWidget,
      );
      expect(find.byType(BreathingDots), findsOneWidget);

      await tester.tap(find.text('Busan'));
      await tester.tap(find.text('Seoul'));
      await tester.pump();
      expect(selected, isEmpty);
    });

    testWidgets('saving으로 바뀌어도 줄 위젯이 갈아 끼워지지 않습니다', (tester) async {
      final saving = ValueNotifier<String?>(null);
      await tester.pumpWidget(
        inputApp(
          Center(
            child: ValueListenableBuilder(
              valueListenable: saving,
              builder: (context, id, _) => _search(
                results: AsyncData([_seoul, _busan]),
                savingCityId: id,
              ),
            ),
          ),
        ),
      );
      State<PressInkTarget> inkOf(City city) => tester.state(
        find.descendant(
          of: find.byKey(ValueKey(city.id)),
          matching: find.byType(PressInkTarget),
        ),
      );
      final before = [inkOf(_seoul), inkOf(_busan)];

      saving.value = _seoul.id;
      await tester.pump();
      expect(inkOf(_seoul), same(before[0]));
      expect(inkOf(_busan), same(before[1]));
    });

    testWidgets('saving이 아니면 점이 없고 줄을 누르면 onSelected입니다', (tester) async {
      final selected = <City>[];
      await tester.pumpWidget(
        inputApp(
          Center(
            child: _search(
              results: AsyncData([_seoul]),
              onSelected: selected.add,
            ),
          ),
        ),
      );
      expect(find.byType(BreathingDots), findsNothing);
      await tester.tap(find.text('Seoul'));
      expect(selected, [_seoul]);
    });

    testWidgets('saving이면 스크린리더에 처리 중을 알립니다', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        inputApp(
          Center(
            child: _search(
              results: AsyncData([_seoul, _busan]),
              savingCityId: _seoul.id,
            ),
          ),
        ),
      );
      // ko actionBusy는 "처리 중"입니다.
      final busy = find.bySemanticsLabel(RegExp('처리 중'));
      expect(busy, findsOneWidget);
      final data = tester.getSemantics(busy).getSemanticsData();
      expect(data.label, contains('Seoul'));
      expect(data.hasAction(SemanticsAction.tap), isFalse);
      // 다른 줄은 눌러도 아무 일이 없는 꺼진 줄로 읽힙니다.
      final other = tester.getSemantics(
        find.bySemanticsLabel('Busan, South Korea'),
      );
      expect(other.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
      handle.dispose();
    });
  });

  test('ko·en은 ", "로, ja는 "、"로 지역 줄을 잇습니다', () {
    final city = City(
      id: '1',
      name: 'Suwon',
      country: 'KR',
      countryName: '대한민국',
      regionName: '경기도',
      timezone: 'Asia/Seoul',
      longitude: 127.0,
    );
    expect(cityRegionLine(city, languageCode: 'ko'), '경기도, 대한민국');
    expect(cityRegionLine(city, languageCode: 'en'), '경기도, 대한민국');
    expect(cityRegionLine(city, languageCode: 'ja'), '경기도、대한민국');
    expect(cityRegionLine(city, languageCode: 'fr'), '경기도, 대한민국');
  });

  testWidgets('ja 로캘이면 화면의 지역 줄도 "、"로 잇습니다', (tester) async {
    await tester.pumpWidget(
      inputApp(
        Center(child: _search(results: AsyncData([_newYork]))),
        locale: const Locale('ja'),
      ),
    );
    expect(find.text('New York、United States'), findsOneWidget);
  });
}
