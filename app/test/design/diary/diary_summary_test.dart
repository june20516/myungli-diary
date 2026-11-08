import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/gen/model/day_kind.dart';
import 'package:myungli_diary/core/api/gen/model/day_kind_count.dart';
import 'package:myungli_diary/core/api/gen/model/diary_stats.dart';
import 'package:myungli_diary/core/api/gen/model/tag.dart';
import 'package:myungli_diary/core/api/gen/model/tag_count.dart';
import 'package:myungli_diary/design/components/diary/diary_summary.dart';
import 'package:myungli_diary/design/components/sentence/hanja_tag.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

import '../input/input_harness.dart';

const _names = {
  'dohwa': '도화',
  'yeokma': '역마',
  'hwagae': '화개',
  'gongmang': '공망',
};

String? _nameOf(Tag tag) => _names[tag.key];

TagCount _tag(String key, int days) => TagCount(
  tag: Tag(key: key, polarity: TagPolarityEnum.neutral),
  days: days,
);

DiaryStats _stats({
  int entryCount = 23,
  List<int> days = const [6, 3, 10, 4],
  List<TagCount> tags = const [],
}) => DiaryStats(
  entryCount: entryCount,
  // 응답 순서는 정해져 있지 않아 일부러 섞습니다.
  dayKinds: [
    DayKindCount(dayKind: DayKind.gisinDay, days: days[3]),
    DayKindCount(dayKind: DayKind.yongsinDay, days: days[0]),
    DayKindCount(dayKind: DayKind.ordinaryDay, days: days[2]),
    DayKindCount(dayKind: DayKind.gwiinDay, days: days[1]),
  ],
  topTags: tags,
);

Widget _host(
  DiaryStats stats, {
  void Function(Tag tag)? onTagTap,
  Locale locale = const Locale('ko'),
  double textScale = 1,
}) => inputApp(
  locale: locale,
  MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
    child: SingleChildScrollView(
      child: DiarySummary(
        stats: stats,
        tagNameOf: _nameOf,
        onTagTap: onTagTap ?? (_) {},
      ),
    ),
  ),
);

double _fillWidth(WidgetTester tester, int index) {
  final fill = find.byKey(DiarySummary.fillKey(index));
  return fill.evaluate().isEmpty ? 0 : tester.getSize(fill).width;
}

void main() {
  group('diary-summary 막대', () {
    testWidgets('편수 23, 수 [6,3,10,4]면 막대 길이 비가 6/10, 3/10, 1, 4/10입니다', (
      tester,
    ) async {
      await tester.pumpWidget(_host(_stats()));
      final track = tester.getSize(find.byKey(DiarySummary.trackKey(0))).width;
      expect(_fillWidth(tester, 0) / track, closeTo(0.6, 0.001));
      expect(_fillWidth(tester, 1) / track, closeTo(0.3, 0.001));
      expect(_fillWidth(tester, 2) / track, closeTo(1, 0.001));
      expect(_fillWidth(tester, 3) / track, closeTo(0.4, 0.001));
    });

    testWidgets('줄 순서는 용신, 귀인, 평범, 기신이고 이름과 수가 보입니다', (tester) async {
      await tester.pumpWidget(_host(_stats()));
      final ys = [
        for (final name in ['용신의 날', '귀인의 날', '평범한 날', '기신의 날'])
          tester.getTopLeft(find.text(name)).dy,
      ];
      expect(ys, [...ys]..sort());
      expect(find.text('쓴 날의 성격'), findsOneWidget);
      for (final days in ['6', '3', '10', '4']) {
        expect(find.text(days), findsOneWidget);
      }
    });

    testWidgets('막대는 높이 8 radius.full, 트랙 bg.base, 채움은 날의 성격 색입니다', (
      tester,
    ) async {
      await tester.pumpWidget(_host(_stats()));
      final colors = tester.element(find.byType(DiarySummary)).tokens.colors;
      final track =
          tester
                  .widget<DecoratedBox>(find.byKey(DiarySummary.trackKey(0)))
                  .decoration
              as BoxDecoration;
      expect(track.color, colors.bgBase);
      expect(
        track.borderRadius,
        const BorderRadius.all(Radius.circular(Radii.full)),
      );
      expect(tester.getSize(find.byKey(DiarySummary.trackKey(0))).height, 8);
      final expected = [
        colors.badgeGoodBg,
        colors.badgeGwiinFg,
        colors.badgeOrdinaryBorder,
        colors.badgeGisinFg,
      ];
      for (var i = 0; i < 4; i++) {
        final fill =
            tester
                    .widget<DecoratedBox>(find.byKey(DiarySummary.fillKey(i)))
                    .decoration
                as BoxDecoration;
        expect(fill.color, expected[i], reason: '줄 $i');
      }
    });

    testWidgets('수가 0인 줄은 트랙만 그립니다', (tester) async {
      await tester.pumpWidget(_host(_stats(days: [0, 5, 0, 5])));
      expect(find.byKey(DiarySummary.fillKey(0)), findsNothing);
      expect(find.byKey(DiarySummary.trackKey(0)), findsOneWidget);
      expect(find.byKey(DiarySummary.fillKey(1)), findsOneWidget);
    });

    testWidgets('편수 5편이면 few가 아니라 막대를 그립니다', (tester) async {
      await tester.pumpWidget(_host(_stats(entryCount: 5)));
      expect(find.byKey(DiarySummary.fewNoticeKey), findsNothing);
      expect(find.byKey(DiarySummary.trackKey(0)), findsOneWidget);
    });
  });

  group('diary-summary 편수', () {
    testWidgets('숫자는 28 700 고정폭이고 단위가 같은 줄 오른쪽에 붙습니다', (tester) async {
      await tester.pumpWidget(_host(_stats(entryCount: 28)));
      final number = tester.widget<Text>(find.text('28'));
      expect(number.style!.fontSize, 28);
      expect(number.style!.fontWeight, FontWeight.w700);
      expect(number.style!.fontFeatures, isNotEmpty);
      final unit = find.text('편');
      expect(
        tester.getTopLeft(unit).dx - tester.getTopRight(find.text('28')).dx,
        4,
      );
    });
  });

  group('diary-summary 기록이 적을 때', () {
    testWidgets('0편, 막대 모두 0, 태그 없음이면 예외 없이 few 안내만 보입니다', (tester) async {
      await tester.pumpWidget(_host(_stats(entryCount: 0, days: [0, 0, 0, 0])));
      expect(tester.takeException(), isNull);
      expect(find.text('0'), findsOneWidget);
      expect(find.text('일기가 몇 편 더 쌓이면 내 기록을 돌아볼 수 있어요.'), findsOneWidget);
      expect(find.text('쓴 날의 성격'), findsNothing);
      expect(find.byKey(DiarySummary.trackKey(0)), findsNothing);
      expect(find.text('자주 붙은 태그'), findsNothing);
    });

    testWidgets('편수 4편이면 막대를 숨기고 안내를 보이되 태그는 그대로입니다', (tester) async {
      await tester.pumpWidget(
        _host(_stats(entryCount: 4, tags: [_tag('dohwa', 2)])),
      );
      expect(find.byKey(DiarySummary.fewNoticeKey), findsOneWidget);
      expect(find.byKey(DiarySummary.trackKey(0)), findsNothing);
      expect(find.text('자주 붙은 태그'), findsOneWidget);
      expect(find.byType(HanjaTag), findsOneWidget);
    });

    testWidgets('편수 5편 이상인데 막대 넷이 모두 0이어도 0으로 나누지 않고 트랙만 그립니다', (tester) async {
      await tester.pumpWidget(_host(_stats(days: [0, 0, 0, 0])));
      expect(tester.takeException(), isNull);
      for (var i = 0; i < 4; i++) {
        expect(find.byKey(DiarySummary.trackKey(i)), findsOneWidget);
        expect(find.byKey(DiarySummary.fillKey(i)), findsNothing);
      }
    });
  });

  group('diary-summary 태그', () {
    testWidgets('수 많은 순 최대 셋이고 이름 뒤에 수가 붙습니다', (tester) async {
      await tester.pumpWidget(
        _host(
          _stats(
            tags: [
              _tag('dohwa', 2),
              _tag('gongmang', 9),
              _tag('yeokma', 5),
              _tag('hwagae', 3),
            ],
          ),
        ),
      );
      final labels = [
        for (final tag in tester.widgetList<HanjaTag>(find.byType(HanjaTag)))
          '${tag.label} ${tag.trailing}',
      ];
      expect(labels, ['공망 9', '역마 5', '화개 3']);
      expect(find.text('도화'), findsNothing);
      final nameRight = tester.getTopRight(find.text('공망')).dx;
      expect(tester.getTopLeft(find.text('9')).dx - nameRight, 4);
    });

    testWidgets('태그를 누르면 onTagTap에 그 태그가 옵니다', (tester) async {
      final tapped = <String>[];
      await tester.pumpWidget(
        _host(
          _stats(tags: [_tag('dohwa', 4)]),
          onTagTap: (tag) => tapped.add(tag.key),
        ),
      );
      await tester.tap(find.text('도화'));
      expect(tapped, ['dohwa']);
    });

    testWidgets('태그가 없으면 머리와 줄을 그리지 않습니다', (tester) async {
      await tester.pumpWidget(_host(_stats()));
      expect(find.text('자주 붙은 태그'), findsNothing);
      expect(find.byType(HanjaTag), findsNothing);
    });

    testWidgets('이름이나 한자 표에 없는 태그는 그리지 않고 건너뜁니다', (tester) async {
      final stats = _stats(
        tags: [_tag('unknown_key', 9), _tag('dohwa', 2), _tag('hwagae', 1)],
      );
      await tester.pumpWidget(_host(stats));
      expect(find.byType(HanjaTag), findsNWidgets(2));
      expect(DiarySummary.skippedTagKeys(stats, _nameOf), ['unknown_key']);
    });

    testWidgets('건너뛴 태그만 있으면 태그 머리도 숨깁니다', (tester) async {
      await tester.pumpWidget(_host(_stats(tags: [_tag('unknown_key', 9)])));
      expect(find.text('자주 붙은 태그'), findsNothing);
    });
  });

  group('diary-summary 큰 글자와 언어', () {
    for (final locale in const [Locale('ko'), Locale('ja'), Locale('en')]) {
      for (final scale in const [1.3, 2.0]) {
        testWidgets('${locale.languageCode} 글자 $scale배에서 넘치지 않습니다', (
          tester,
        ) async {
          tester.view.physicalSize = const Size(360, 1200);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(
            _host(
              _stats(tags: [_tag('dohwa', 4), _tag('gongmang', 3)]),
              locale: locale,
              textScale: scale,
            ),
          );
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('이름이 두 줄로 내려가도 막대와 수가 줄 가운데에 맞고 넘치지 않습니다', (tester) async {
      tester.view.physicalSize = const Size(320, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _host(_stats(), locale: const Locale('en'), textScale: 1.3),
      );
      expect(tester.takeException(), isNull);
      for (var i = 0; i < 4; i++) {
        final track = tester.getCenter(find.byKey(DiarySummary.trackKey(i)));
        final row = find
            .ancestor(
              of: find.byKey(DiarySummary.trackKey(i)),
              matching: find.byType(ConstrainedBox),
            )
            .first;
        expect(
          track.dy,
          closeTo(tester.getCenter(row).dy, 0.5),
          reason: '줄 $i',
        );
      }
    });

    testWidgets('글자 배율 상한 1.3배: 2.0배여도 편수 글자는 1.3배까지만 커집니다', (tester) async {
      await tester.pumpWidget(_host(_stats(entryCount: 28), textScale: 2));
      final element = tester.element(find.text('28'));
      expect(MediaQuery.textScalerOf(element).scale(10), closeTo(13, 0.001));
    });
  });

  group('diary-summary 접근성과 뼈', () {
    testWidgets('태그 시맨틱 라벨은 이름 뒤에 수를 붙인 "도화 4"입니다', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_host(_stats(tags: [_tag('dohwa', 4)])));
      expect(find.bySemanticsLabel('도화 4'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('같은 수의 태그는 응답 순서를 지킵니다', (tester) async {
      await tester.pumpWidget(
        _host(
          _stats(
            tags: [
              _tag('yeokma', 3),
              _tag('dohwa', 3),
              _tag('hwagae', 3),
              _tag('gongmang', 3),
            ],
          ),
        ),
      );
      final labels = [
        for (final tag in tester.widgetList<HanjaTag>(find.byType(HanjaTag)))
          tag.label,
      ];
      expect(labels, ['역마', '도화', '화개']);
    });

    testWidgets('막대는 읽지 않고 줄은 이름과 수를 한 덩어리로 읽습니다', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_host(_stats()));
      expect(find.bySemanticsLabel(RegExp(r'용신의 날\s*6')), findsOneWidget);
      handle.dispose();
    });

    testWidgets('뼈: 머리 글자는 바로 보이고 막대와 편수는 보이지 않습니다', (tester) async {
      await tester.pumpWidget(
        inputApp(
          SingleChildScrollView(child: DiarySummary.skeleton(animated: false)),
        ),
      );
      expect(find.text('쓴 날의 성격'), findsOneWidget);
      expect(find.text('자주 붙은 태그'), findsOneWidget);
      expect(find.byKey(DiarySummary.trackKey(0)), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
