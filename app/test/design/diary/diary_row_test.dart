import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:myungli_diary/design/components/diary/diary_row.dart';
import 'package:myungli_diary/design/components/frame/scroll_hint.dart';
import 'package:myungli_diary/design/components/sentence/hanja_tag.dart';
import 'package:myungli_diary/design/components/sentence/sentence_block.dart';
import 'package:myungli_diary/design/elements/seal.dart';
import 'package:myungli_diary/design/elements/skeleton_bone.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

import '../input/input_harness.dart';

final _date = CalendarDate(2026, 10, 12);

Widget _rows({
  bool withBadge = true,
  bool withTag = true,
  VoidCallback? onTap,
  VoidCallback? onTag,
  VoidCallback? onDayKind,
  bool lastOnly = false,
}) => inputApp(
  SingleChildScrollView(
    child: SizedBox(
      width: 360,
      child: Column(
        children: [
          if (!lastOnly)
            DiaryRow(
              key: const ValueKey('first'),
              date: _date,
              excerpt: '오랜만에 연락이 온 친구와 점심을 먹었다.',
              dayKind: withBadge
                  ? HanjaTag(
                      glyph: '用',
                      label: '좋은 날',
                      tone: HanjaTagTone.yongsin,
                      onTap: onDayKind ?? () {},
                    )
                  : null,
              tags: [
                if (withTag)
                  HanjaTag(glyph: '貴', label: '천을귀인', onTap: onTag ?? () {}),
              ],
              onTap: onTap ?? () {},
            ),
          DiaryRow(
            key: const ValueKey('last'),
            date: CalendarDate(2026, 10, 8),
            excerpt: '아침 공기가 갑자기 차가워졌다.',
            isLast: true,
            onTap: () {},
          ),
        ],
      ),
    ),
  ),
);

Finder _in(String key, Finder finder) =>
    find.descendant(of: find.byKey(ValueKey(key)), matching: finder);

void main() {
  group('diary-row', () {
    testWidgets('날짜 열 44: 숫자 18 600 tnum이 옅은 도장 34 가운데, 아래 요일 caption.md', (
      tester,
    ) async {
      await tester.pumpWidget(_rows());
      final tokens = tester.element(find.byType(DiaryRow).first).tokens;
      expect(
        tester.getSize(_in('first', find.byKey(DiaryRow.dateColumnKey))).width,
        44,
      );
      final number = tester.widget<Text>(_in('first', find.text('12')));
      expect(number.style!.fontSize, 18);
      expect(number.style!.fontWeight, FontWeight.w600);
      expect(
        number.style!.fontFeatures,
        contains(const FontFeature.tabularFigures()),
      );
      final seal = tester.widget<Seal>(_in('first', find.byType(Seal)));
      expect((seal.size, seal.variant), (SealSize.row, SealVariant.soft));
      expect(
        tester.getCenter(_in('first', find.byType(Seal))),
        tester.getCenter(_in('first', find.text('12'))),
      );
      final weekday = tester.widget<Text>(_in('first', find.text('월')));
      expect(weekday.style!.fontSize, tokens.typography.captionMd.fontSize);
      expect(weekday.style!.color, tokens.colors.textSecondary);
    });

    testWidgets('글자 2.0배와 긴 이름(ja)에서도 두 태그가 카드 안에서 넘치지 않습니다', (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: inputApp(
            SizedBox(
              width: 360,
              child: DiaryRow(
                date: _date,
                excerpt: '久しぶりに連絡をくれた友達とお昼を食べた。',
                dayKind: const HanjaTag(
                  glyph: '忌',
                  label: '気をつけて過ごしたい日',
                  tone: HanjaTagTone.gisin,
                ),
                tags: const [HanjaTag(glyph: '貴', label: '天乙貴人の巡る日')],
                onTap: () {},
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      final card = tester.getRect(find.byKey(DiaryRow.cardKey));
      for (final tag in tester.widgetList<HanjaTag>(find.byType(HanjaTag))) {
        final rect = tester.getRect(find.byWidget(tag));
        expect(rect.left, greaterThanOrEqualTo(card.left));
        expect(rect.right, lessThanOrEqualTo(card.right));
      }
    });

    testWidgets('날짜 열은 글자 1.3배에서 멈춰 큰 글자에서도 숫자가 한 줄입니다', (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: _rows(),
        ),
      );
      final number = _in('first', find.text('12'));
      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(of: number, matching: find.byType(RichText)),
      );
      expect(paragraph.textScaler.scale(10), closeTo(13, 0.01));
      expect(tester.getSize(number).height, lessThan(18 * 1.3 * 1.5));
      expect(tester.takeException(), isNull);
    });

    testWidgets('흐름 줄 1.5는 요일 아래에서 줄 끝까지 이어지고 마지막 줄 뒤에는 없습니다', (tester) async {
      await tester.pumpWidget(_rows());
      final rail = _in('first', find.byKey(DiaryRow.railKey));
      expect(tester.getSize(rail).width, 1.5);
      final weekdayBottom = tester
          .getBottomLeft(_in('first', find.text('월')))
          .dy;
      expect(tester.getTopLeft(rail).dy, greaterThanOrEqualTo(weekdayBottom));
      expect(
        tester.getBottomLeft(rail).dy,
        tester.getBottomLeft(find.byKey(const ValueKey('first'))).dy,
        reason: '다음 줄 날짜까지 끊기지 않습니다',
      );
      expect(_in('last', find.byKey(DiaryRow.railKey)), findsNothing);
    });

    testWidgets(
      '카드: bg.sheet radius.lg 안쪽 16, 날의 성격 → 미리보기(preview) → 사주 기운 태그 줄',
      (tester) async {
        await tester.pumpWidget(_rows());
        final tokens = tester.element(find.byType(DiaryRow).first).tokens;
        final card =
            tester
                    .widget<DecoratedBox>(
                      _in('first', find.byKey(DiaryRow.cardKey)),
                    )
                    .decoration
                as BoxDecoration;
        expect(card.color, tokens.colors.bgSheet);
        expect(card.borderRadius, BorderRadius.circular(Radii.lg));
        final badge = _in('first', find.byType(HanjaTag)).first;
        final preview = _in('first', find.byType(SentenceBlock));
        final chip = _in('first', find.byType(HanjaTag)).last;
        expect(tester.widget<HanjaTag>(badge).tone, HanjaTagTone.yongsin);
        expect(tester.widget<HanjaTag>(chip).tone, HanjaTagTone.term);
        expect(tester.widget<HanjaTag>(chip).variant, HanjaTagVariant.normal);
        expect(
          tester.widget<SentenceBlock>(preview).variant,
          SentenceBlockVariant.preview,
        );
        expect(
          tester.getTopLeft(preview).dy - tester.getBottomLeft(badge).dy,
          Space.s8,
        );
        expect(
          tester.getTopLeft(chip).dy - tester.getBottomLeft(preview).dy,
          Space.s12,
        );
        expect(
          tester.getTopLeft(badge).dx -
              tester.getTopLeft(_in('first', find.byKey(DiaryRow.cardKey))).dx,
          Space.s16,
        );
      },
    );

    testWidgets('날의 성격·사주 기운 태그가 없으면 그 자리를 그리지 않고 간격도 없습니다', (tester) async {
      await tester.pumpWidget(_rows(withBadge: false, withTag: false));
      expect(_in('first', find.byType(HanjaTag)), findsNothing);
      final preview = _in('first', find.byType(SentenceBlock));
      final card = _in('first', find.byKey(DiaryRow.cardKey));
      expect(
        tester.getTopLeft(preview).dy - tester.getTopLeft(card).dy,
        Space.s16,
      );
    });

    testWidgets('카드를 누르면 onTap, 두 태그를 누르면 각 태그만 갑니다', (tester) async {
      var rows = 0;
      var tags = 0;
      var kinds = 0;
      await tester.pumpWidget(
        _rows(
          onTap: () => rows++,
          onTag: () => tags++,
          onDayKind: () => kinds++,
        ),
      );
      await tester.tap(_in('first', find.byType(SentenceBlock)));
      await tester.pumpAndSettle();
      await tester.tap(_in('first', find.byType(HanjaTag)).last);
      await tester.pumpAndSettle();
      await tester.tap(_in('first', find.byType(HanjaTag)).first);
      await tester.pumpAndSettle();
      expect((rows, tags, kinds), (1, 1, 1));
    });

    testWidgets('스크린리더: 카드 한 덩어리 버튼, "날짜 요일, 날의 성격, 미리보기, 태그" + 두 태그 동작', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      var tags = 0;
      await tester.pumpWidget(_rows(onTag: () => tags++));
      final node = tester.getSemantics(
        find.bySemanticsLabel(RegExp('^10월 12일 월요일')),
      );
      final data = node.getSemanticsData();
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.label, '10월 12일 월요일, 좋은 날, 오랜만에 연락이 온 친구와 점심을 먹었다., 천을귀인');
      expect(data.customSemanticsActionIds, hasLength(2));
      final byLabel = {
        for (final id in data.customSemanticsActionIds!)
          CustomSemanticsAction.getAction(id)!.label: id,
      };
      expect(byLabel.keys, containsAll(['좋은 날', '천을귀인']));
      node.owner!.performAction(
        node.id,
        SemanticsAction.customAction,
        byLabel['천을귀인'] ?? -1,
      );
      expect(tags, 1);
      handle.dispose();
    });

    testWidgets('한 편 카드의 낭독은 날짜 숫자·요일·배지 노드 없이 라벨 하나입니다', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_rows());
      expect(find.bySemanticsLabel(RegExp('^10월 12일 월요일')), findsOneWidget);
      expect(find.bySemanticsLabel('12'), findsNothing);
      expect(find.bySemanticsLabel('월'), findsNothing);
      expect(find.bySemanticsLabel('좋은 날'), findsNothing);
      handle.dispose();
    });

    testWidgets('날의 성격을 기다리는 동안(dayKindPending) 태그 자리는 skeleton입니다', (
      tester,
    ) async {
      await tester.pumpWidget(
        inputApp(
          SizedBox(
            width: 360,
            child: DiaryRow(
              date: _date,
              excerpt: '본문',
              dayKindPending: true,
              onTap: () {},
            ),
          ),
        ),
      );
      expect(find.byType(HanjaTag), findsNothing);
      final bone = tester.getSize(find.byType(SkeletonBone));
      expect(bone.height, HanjaTag.height);
    });

    testWidgets('loading: 목록 skeleton 줄은 도장 자리·카드 뼈이고 스크린리더는 읽지 않습니다', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        inputApp(const SizedBox(width: 360, child: DiaryRowSkeleton())),
      );
      expect(find.byType(SkeletonBone), findsWidgets);
      expect(
        tester.getSize(find.byKey(DiaryRow.dateColumnKey)).width,
        DiaryRow.dateColumnWidth,
      );
      expect(find.byType(Text), findsNothing);
      handle.dispose();
    });

    testWidgets('달 머리는 type.subtitle입니다', (tester) async {
      await tester.pumpWidget(
        inputApp(const DiaryMonthHeader(label: '2026년 10월')),
      );
      final tokens = tester.element(find.byType(DiaryMonthHeader)).tokens;
      final text = tester.widget<Text>(find.text('2026년 10월'));
      expect(text.style!.fontSize, tokens.typography.subtitle.fontSize);
      final handle = tester.ensureSemantics();
      await tester.pump();
      expect(
        tester
            .getSemantics(find.text('2026년 10월'))
            .getSemanticsData()
            .flagsCollection
            .isHeader,
        isTrue,
      );
      handle.dispose();
    });
  });

  group('diary-row 사주 기운 태그 줄(D115, V103)', () {
    const labels = ['천을귀인', '합', '도화', '역마', '화개', '공망'];
    const glyphs = ['貴', '合', '桃', '驛', '華', '空'];

    List<HanjaTag> tags(int count, {List<VoidCallback>? taps}) => [
      for (var i = 0; i < count; i++)
        HanjaTag(glyph: glyphs[i], label: labels[i], onTap: taps?[i] ?? () {}),
    ];

    Widget row(List<HanjaTag> tags) => inputApp(
      SingleChildScrollView(
        child: SizedBox(
          width: 360,
          child: DiaryRow(
            date: _date,
            excerpt: '오랜만에 연락이 온 친구와 점심을 먹었다.',
            tags: tags,
            onTap: () {},
          ),
        ),
      ),
    );

    /// 태그 줄의 흐림 두 개(시작, 끝)의 투명도.
    (double, double) fades(WidgetTester tester) {
      final opacities = tester
          .widgetList<AnimatedOpacity>(
            find.descendant(
              of: find.byType(ScrollHint),
              matching: find.byType(AnimatedOpacity),
            ),
          )
          .map((fade) => fade.opacity)
          .toList();
      expect(opacities, hasLength(2));
      return (opacities.first, opacities.last);
    }

    testWidgets('받은 순서대로 한 줄에 space.8 간격으로 모두 둡니다', (tester) async {
      await tester.pumpWidget(row(tags(3)));
      final pills = find.descendant(
        of: find.byKey(DiaryRow.tagsKey),
        matching: find.byType(HanjaTag),
      );
      expect(
        tester.widgetList<HanjaTag>(pills).map((tag) => tag.label),
        labels.take(3),
      );
      final rects = [for (var i = 0; i < 3; i++) tester.getRect(pills.at(i))];
      for (var i = 1; i < rects.length; i++) {
        expect(rects[i].left - rects[i - 1].right, DiaryRow.tagsGap);
        expect(rects[i].top, rects[0].top);
      }
      expect(DiaryRow.tagsGap, Space.s8);
    });

    testWidgets('넘치지 않으면 흐림이 없고 화살표 줄도 없습니다', (tester) async {
      await tester.pumpWidget(row(tags(2)));
      await tester.pump();
      expect(fades(tester), (0.0, 0.0));
      expect(find.byType(Icon), findsNothing);
    });

    testWidgets('넘치면 줄을 늘리지 않고 그 줄 안에서 가로로 밀며 더 있는 쪽 끝만 흐립니다', (tester) async {
      await tester.pumpWidget(row(tags(6)));
      await tester.pump();
      await tester.pumpAndSettle();
      final line = tester.getRect(find.byKey(DiaryRow.tagsKey));
      expect(line.height, HanjaTag.height);
      final card = tester.getRect(find.byKey(DiaryRow.cardKey));
      expect(line.right, lessThanOrEqualTo(card.right - Space.s16));
      expect(fades(tester), (0.0, 1.0));
      // 화살표 줄은 두지 않습니다(카드 안 한 줄, `arrows.visible: false`).
      expect(find.byType(Icon), findsNothing);
      final fade = tester.getRect(
        find
            .descendant(
              of: find.byType(ScrollHint),
              matching: find.byType(DecoratedBox),
            )
            .last,
      );
      expect(fade.width, ScrollHint.fadeWidth);
      expect(fade.right, line.right);
      final gradient =
          (tester
                          .widget<DecoratedBox>(
                            find
                                .descendant(
                                  of: find.byType(ScrollHint),
                                  matching: find.byType(DecoratedBox),
                                )
                                .last,
                          )
                          .decoration
                      as BoxDecoration)
                  .gradient!
              as LinearGradient;
      final tokens = tester.element(find.byType(DiaryRow)).tokens;
      expect(gradient.colors.first, tokens.colors.bgSheet);

      await tester.drag(find.byKey(DiaryRow.tagsKey), const Offset(-1000, 0));
      await tester.pumpAndSettle();
      // 끝까지 밀면 그쪽 흐림이 사라지고 앞쪽이 흐려집니다.
      expect(fades(tester), (1.0, 0.0));
    });

    testWidgets('태그를 누르면 그 태그만, 카드는 그대로입니다', (tester) async {
      final pressed = <int>[];
      await tester.pumpWidget(
        row(tags(3, taps: [for (var i = 0; i < 3; i++) () => pressed.add(i)])),
      );
      await tester.tap(find.text('합'));
      await tester.pumpAndSettle();
      expect(pressed, [1]);
    });

    testWidgets('스크린리더: 한 편 카드 라벨이 태그 모두를 차례로 읽고, 태그마다 추가 동작', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(row(tags(6)));
      final node = tester.getSemantics(
        find.bySemanticsLabel(RegExp('^10월 12일 월요일')),
      );
      final data = node.getSemanticsData();
      expect(
        data.label,
        '10월 12일 월요일, 오랜만에 연락이 온 친구와 점심을 먹었다., ${labels.join(', ')}',
      );
      expect(data.customSemanticsActionIds, hasLength(labels.length));
      handle.dispose();
    });

    testWidgets('묶음 카드의 태그 줄은 목록으로 차례로 읽힙니다', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        inputApp(
          SingleChildScrollView(
            child: SizedBox(
              width: 360,
              child: DiaryDayGroup(
                date: _date,
                entries: [
                  for (final hour in [8, 21])
                    DiaryEntryData(
                      createdAt: DateTime(2026, 10, 12, hour),
                      excerpt: '$hour시',
                      onTap: () {},
                    ),
                ],
                tags: tags(6),
              ),
            ),
          ),
        ),
      );
      for (final label in labels) {
        expect(find.bySemanticsLabel(label), findsOneWidget, reason: label);
      }
      handle.dispose();
    });

    testWidgets('태그가 없으면 줄과 간격을 그리지 않습니다', (tester) async {
      await tester.pumpWidget(row(const []));
      expect(find.byKey(DiaryRow.tagsKey), findsNothing);
      expect(find.byType(ScrollHint), findsNothing);
    });
  });
}
