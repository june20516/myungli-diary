import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/design/components/action/primary_button.dart';
import 'package:myungli_diary/design/components/calendar/event_row.dart';
import 'package:myungli_diary/design/elements/app_icon.dart';
import 'package:myungli_diary/design/elements/status_tag.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';
import 'package:phosphor_glyphs/phosphor_glyphs.dart';

import '../input/input_harness.dart';

/// 너비 360 칸에 [child]를 놓은 앱. [textScale]로 시스템 글자 크기를 바꿉니다.
Widget _app(Widget child, {double textScale = 1}) => inputApp(
  Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(textScale)),
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: 360, child: child),
      ),
    ),
  ),
);

BuildContext _context(WidgetTester tester) =>
    tester.element(find.byType(SizedBox).first);

Text _text(WidgetTester tester, String data) =>
    tester.widget<Text>(find.text(data));

/// [EventRow]가 버튼 하나로 [label]을 읽는지.
void _expectButton(WidgetTester tester, String label) {
  final data = tester.getSemantics(find.byType(EventRow)).getSemanticsData();
  expect(data.label, label);
  expect(data.flagsCollection.isButton, isTrue);
}

const _longTitle = '아주 긴 일정 제목이 한 줄을 넘어가면 끝을 말줄임으로 자르고 두 줄 목록에서는 두 줄까지 보여 줍니다';

void main() {
  group('StatusTag(tag.status)', () {
    testWidgets('옅은 sage 알약: status.bg·status.fg·label.md·radius.full·8×2', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const StatusTag('진행 중')));
      final tokens = _context(tester).tokens;
      final box = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(StatusTag),
          matching: find.byType(DecoratedBox),
        ),
      );
      final decoration = box.decoration as BoxDecoration;
      expect(decoration.color, tokens.colors.statusBg);
      expect(
        decoration.borderRadius,
        const BorderRadius.all(Radius.circular(Radii.full)),
      );
      final padding = tester.widget<Padding>(
        find.descendant(
          of: find.byType(StatusTag),
          matching: find.byType(Padding),
        ),
      );
      expect(
        padding.padding,
        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      );
      expect(StatusTag.padding, padding.padding);
      final style = _text(tester, '진행 중').style!;
      expect(style.fontSize, tokens.typography.labelMd.fontSize);
      expect(style.fontWeight, tokens.typography.labelMd.fontWeight);
      expect(style.color, tokens.colors.statusFg);
    });
  });

  group('EventRow.summary', () {
    Widget summary({
      EventRowStatus? status = EventRowStatus.inProgress,
      String? statusLabel = '진행 중',
      String? time = '14:00',
      String title = '회의',
      String? moreText,
      String? allPastSentence,
      VoidCallback? onTap,
    }) => EventRow.summary(
      status: status,
      statusLabel: statusLabel,
      time: time,
      title: title,
      moreText: moreText,
      allPastSentence: allPastSentence,
      onTap: onTap,
    );

    test('명세 대조용 요약은 event-row, summary·list, pressed입니다', () {
      expect(EventRow.spec.id, 'event-row');
      expect(EventRow.spec.variants, {'summary', 'list'});
      expect(EventRow.spec.states, {'pressed'});
      expect(EventRowVariant.values.map((v) => v.name), ['summary', 'list']);
      expect(EventRowStatus.values.map((v) => v.name), ['inProgress', 'next']);
    });

    testWidgets('상태 태그·시각(tnum)·제목·외 N개를 한 줄에 그립니다', (tester) async {
      await tester.pumpWidget(_app(summary(moreText: '외 2개')));
      final tokens = _context(tester).tokens;
      expect(find.widgetWithText(StatusTag, '진행 중'), findsOneWidget);

      final time = _text(tester, '14:00').style!;
      expect(time.fontSize, tokens.typography.bodyUi.fontSize);
      expect(time.color, tokens.colors.textSecondary);
      expect(time.fontFeatures, contains(const FontFeature.tabularFigures()));

      final title = _text(tester, '회의');
      expect(title.style!.fontSize, tokens.typography.bodyUi.fontSize);
      expect(title.style!.color, tokens.colors.textPrimary);
      expect(title.maxLines, 1);
      expect(title.overflow, TextOverflow.ellipsis);

      final more = _text(tester, '외 2개').style!;
      expect(more.fontSize, tokens.typography.captionLg.fontSize);
      expect(more.color, tokens.colors.textSecondary);

      // 한 줄: 태그·시각·제목·외 N개의 세로 가운데가 같습니다.
      final y = tester.getCenter(find.text('회의')).dy;
      expect(tester.getCenter(find.text('14:00')).dy, closeTo(y, 1));
      expect(tester.getCenter(find.text('외 2개')).dy, closeTo(y, 1));
      expect(tester.getCenter(find.byType(StatusTag)).dy, closeTo(y, 1));
    });

    testWidgets('긴 제목은 한 줄 말줄임이고 외 N개는 잘리지 않습니다', (tester) async {
      await tester.pumpWidget(
        _app(summary(title: _longTitle, moreText: '외 3개')),
      );
      expect(tester.takeException(), isNull);
      final title = tester.renderObject<RenderParagraph>(
        find.descendant(
          of: find.text(_longTitle),
          matching: find.byType(RichText),
        ),
      );
      expect(title.didExceedMaxLines, isTrue);
      expect(tester.getRect(find.text('외 3개')).right, lessThanOrEqualTo(360));
    });

    testWidgets('상태가 없으면 태그 없이 시각·제목만 그립니다', (tester) async {
      await tester.pumpWidget(_app(summary(status: null, statusLabel: null)));
      expect(find.byType(StatusTag), findsNothing);
      expect(find.text('14:00'), findsOneWidget);
    });

    testWidgets('모두 지났으면 개수 문장 한 줄만 보입니다', (tester) async {
      await tester.pumpWidget(
        _app(summary(allPastSentence: '오늘 일정 3개 모두 지났어요', moreText: '외 2개')),
      );
      final tokens = _context(tester).tokens;
      expect(find.byType(StatusTag), findsNothing);
      expect(find.text('14:00'), findsNothing);
      expect(find.text('회의'), findsNothing);
      expect(find.text('외 2개'), findsNothing);
      final style = _text(tester, '오늘 일정 3개 모두 지났어요').style!;
      expect(style.fontSize, tokens.typography.captionLg.fontSize);
      expect(style.color, tokens.colors.textSecondary);
    });

    testWidgets('스크린리더: 버튼, 라벨 "상태 시각 제목"(외 N개를 뒤에 붙임)', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(summary(onTap: () {})));
      _expectButton(tester, '진행 중 14:00 회의');
      await tester.pumpWidget(
        _app(
          summary(
            status: EventRowStatus.next,
            statusLabel: '다음',
            moreText: '외 2개',
            onTap: () {},
          ),
        ),
      );
      _expectButton(tester, '다음 14:00 회의 외 2개');
      handle.dispose();
    });

    testWidgets('누르면 onTap, 최소 높이 48', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_app(summary(onTap: () => taps++)));
      expect(
        tester.getSize(find.byType(EventRow)).height,
        greaterThanOrEqualTo(EventRow.minHeight),
      );
      await tester.tap(find.byType(EventRow));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });

    testWidgets('pressed: 누르는 동안 press.ink 얼룩이 번지고 뗀 뒤 사라집니다', (tester) async {
      await tester.pumpWidget(_app(summary(onTap: () {})));
      await tester.pumpAndSettle();
      final layer = inkLayer(find.byType(EventRow)).first;
      expect(paintsInk(tester, layer), isFalse);
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('회의')),
      );
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump(const Duration(milliseconds: 100));
      expect(paintsInk(tester, layer), isTrue);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(paintsInk(tester, layer), isFalse);
    });

    testWidgets('글자 크기 2.0에서 제목 자리가 모자라면 상태·시각 / 제목·외 N개 두 줄로 내립니다', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(summary(title: _longTitle, moreText: '외 12개'), textScale: 2),
      );
      expect(tester.takeException(), isNull);
      final timeRect = tester.getRect(find.text('14:00'));
      final titleRect = tester.getRect(find.text(_longTitle));
      expect(titleRect.top, greaterThanOrEqualTo(timeRect.bottom));
      expect(
        tester.getCenter(find.text('외 12개')).dy,
        closeTo(titleRect.center.dy, 1),
      );
    });
  });

  group('EventRow.list', () {
    Widget list({
      String timeText = '14:00',
      String title = '회의',
      bool showDivider = true,
      VoidCallback? onTap,
    }) => EventRow.list(
      timeText: timeText,
      title: title,
      showDivider: showDivider,
      onTap: onTap,
    );

    testWidgets('시각 칸은 58 고정이고 하루 종일도 같은 폭입니다', (tester) async {
      expect(EventRow.timeColumnWidth, 58);
      for (final timeText in ['14:00', '하루 종일']) {
        await tester.pumpWidget(_app(list(timeText: timeText)));
        expect(
          tester.getSize(find.byKey(EventRow.timeColumnKey)).width,
          58,
          reason: timeText,
        );
        final tokens = _context(tester).tokens;
        final style = _text(tester, timeText).style!;
        expect(style.fontSize, tokens.typography.numericTable.fontSize);
        expect(style.color, tokens.colors.textSecondary);
        expect(
          style.fontFeatures,
          contains(const FontFeature.tabularFigures()),
        );
      }
    });

    testWidgets('제목은 두 줄까지, 끝에 caret-right(Light 16 text.secondary)', (
      tester,
    ) async {
      await tester.pumpWidget(_app(list(title: _longTitle)));
      final tokens = _context(tester).tokens;
      final title = _text(tester, _longTitle);
      expect(title.maxLines, 2);
      expect(title.style!.fontSize, tokens.typography.bodyUi.fontSize);
      expect(title.style!.color, tokens.colors.textPrimary);
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, PhosphorIconsLight.caretRight);
      expect(icon.size, AppIconSize.inline.logical);
      expect(icon.size, 16);
      expect(icon.color, tokens.colors.textSecondary);
    });

    testWidgets('한 줄 제목도 최소 높이 48이고 아래에 1px line 구분선', (tester) async {
      await tester.pumpWidget(_app(list()));
      final tokens = _context(tester).tokens;
      final content = tester.getSize(find.byKey(EventRow.contentKey));
      expect(content.height, greaterThanOrEqualTo(48));
      expect(EventRow.minHeight, 48);
      final divider = find.byKey(EventRow.dividerKey);
      expect(tester.getSize(divider).height, 1);
      expect(tester.widget<ColoredBox>(divider).color, tokens.colors.line);
      expect(
        tester.getRect(divider).top,
        tester.getRect(find.byKey(EventRow.contentKey)).bottom,
      );
    });

    testWidgets('showDivider가 false면 구분선이 없습니다', (tester) async {
      await tester.pumpWidget(_app(list(showDivider: false)));
      expect(find.byKey(EventRow.dividerKey), findsNothing);
    });

    testWidgets('스크린리더: 버튼, 라벨 "시각 제목"', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(list(onTap: () {})));
      _expectButton(tester, '14:00 회의');
      handle.dispose();
    });

    testWidgets('pressed: press.ink, 누르면 onTap', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_app(list(onTap: () => taps++)));
      await tester.pumpAndSettle();
      final layer = inkLayer(find.byType(EventRow)).first;
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('회의')),
      );
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump(const Duration(milliseconds: 100));
      expect(paintsInk(tester, layer), isTrue);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(taps, 1);
    });

    testWidgets('글자 크기 1.3·2.0에서도 시각은 58 칸 안에 한 줄로 줄여 들어가고 제목과 떨어집니다', (
      tester,
    ) async {
      for (final scale in [1.3, 2.0]) {
        for (final timeText in ['14:00', '하루 종일']) {
          final reason = '$scale $timeText';
          await tester.pumpWidget(
            _app(
              list(timeText: timeText, title: _longTitle),
              textScale: scale,
            ),
          );
          expect(tester.takeException(), isNull, reason: reason);
          final column = tester.getRect(find.byKey(EventRow.timeColumnKey));
          expect(column.width, 58, reason: reason);
          final text = tester.getRect(find.text(timeText));
          expect(text.left, greaterThanOrEqualTo(column.left), reason: reason);
          // 칸 끝 8px 여백을 남겨 제목에 붙지 않습니다.
          expect(
            text.right,
            lessThanOrEqualTo(column.right - Space.s8),
            reason: reason,
          );
          final paragraph = tester.renderObject<RenderParagraph>(
            find.descendant(
              of: find.text(timeText),
              matching: find.byType(RichText),
            ),
          );
          expect(paragraph.didExceedMaxLines, isFalse, reason: reason);
          expect(_text(tester, timeText).maxLines, 1, reason: reason);
        }
      }
    });
  });

  group('EventRowListEmpty', () {
    testWidgets('빈 문장(caption.lg text.secondary) + quiet 일정 추가 버튼', (
      tester,
    ) async {
      var adds = 0;
      await tester.pumpWidget(
        _app(
          EventRowListEmpty(
            message: '이날 일정이 없어요',
            addLabel: '일정 추가',
            onAdd: () => adds++,
          ),
        ),
      );
      final tokens = _context(tester).tokens;
      final style = _text(tester, '이날 일정이 없어요').style!;
      expect(style.fontSize, tokens.typography.captionLg.fontSize);
      expect(style.color, tokens.colors.textSecondary);
      final button = tester.widget<PrimaryButton>(find.byType(PrimaryButton));
      expect(button.variant, PrimaryButtonVariant.quiet);
      expect(button.label, '일정 추가');
      await tester.tap(find.text('일정 추가'));
      await tester.pumpAndSettle();
      expect(adds, 1);
    });
  });
}
