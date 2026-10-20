import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/action/primary_button.dart';
import 'package:myungli_diary/design/components/calendar/event_row.dart';
import 'package:myungli_diary/design/elements/app_icon.dart';
import 'package:myungli_diary/design/elements/status_tag.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';
import 'package:phosphor_glyphs/phosphor_glyphs.dart';

import '../../support/fonts.dart';
import '../input/input_harness.dart';

/// 너비 [width](기본 360) 칸에 [child]를 놓은 앱. [textScale]로 시스템 글자 크기를 바꿉니다.
Widget _app(Widget child, {double textScale = 1, double width = 360}) =>
    inputApp(
      Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: width, child: child),
          ),
        ),
      ),
    );

BuildContext _context(WidgetTester tester) =>
    tester.element(find.byType(SizedBox).first);

Text _text(WidgetTester tester, String data) =>
    tester.widget<Text>(find.text(data));

/// [EventRow]가 [label] 한 덩어리로 읽히고 [button] 여부가 맞는지.
void _expectNode(WidgetTester tester, String label, {bool button = true}) {
  final data = tester.getSemantics(find.byType(EventRow)).getSemanticsData();
  expect(data.label, label);
  expect(data.flagsCollection.isButton, button);
}

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(_context(tester));

/// [data] 글자가 실제로 받는 배율로 그린 [fontSize] 글자의 크기.
double _renderedFontSize(WidgetTester tester, String data, double fontSize) =>
    tester
        .renderObject<RenderParagraph>(
          find.descendant(of: find.text(data), matching: find.byType(RichText)),
        )
        .textScaler
        .scale(fontSize);

const _longTitle = '아주 긴 일정 제목이 한 줄을 넘어가면 끝을 말줄임으로 자르고 두 줄 목록에서는 두 줄까지 보여 줍니다';

void main() {
  // 시각 칸·제목 자리 판단이 글자 폭을 재므로 실제 글꼴(Pretendard)로 그립니다.
  setUpAll(loadBundledFonts);

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
      String? time = '14:00',
      String title = '회의',
      int moreCount = 0,
      String? allPastSentence,
      VoidCallback? onTap,
    }) => EventRow.summary(
      status: status,
      time: time,
      title: title,
      moreCount: moreCount,
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

    testWidgets('상태 태그·시각(tnum)·제목·외 N개를 한 줄에 그립니다(문구는 ARB)', (tester) async {
      await tester.pumpWidget(_app(summary(moreCount: 2)));
      final tokens = _context(tester).tokens;
      final l10n = _l10n(tester);
      expect(
        find.widgetWithText(StatusTag, l10n.todayEventSummaryOngoing),
        findsOneWidget,
      );

      final time = _text(tester, '14:00').style!;
      expect(time.fontSize, tokens.typography.bodyUi.fontSize);
      expect(time.color, tokens.colors.textSecondary);
      expect(time.fontFeatures, contains(const FontFeature.tabularFigures()));

      final title = _text(tester, '회의');
      expect(title.style!.fontSize, tokens.typography.bodyUi.fontSize);
      expect(title.style!.color, tokens.colors.textPrimary);
      expect(title.maxLines, 1);
      expect(title.overflow, TextOverflow.ellipsis);

      final moreText = l10n.eventRowMore(2);
      expect(moreText, '외 2개');
      final more = _text(tester, moreText).style!;
      expect(more.fontSize, tokens.typography.captionLg.fontSize);
      expect(more.color, tokens.colors.textSecondary);

      // 한 줄: 태그·시각·제목·외 N개의 세로 가운데가 같습니다.
      final y = tester.getCenter(find.text('회의')).dy;
      expect(tester.getCenter(find.text('14:00')).dy, closeTo(y, 1));
      expect(tester.getCenter(find.text(moreText)).dy, closeTo(y, 1));
      expect(tester.getCenter(find.byType(StatusTag)).dy, closeTo(y, 1));
    });

    testWidgets('다음 상태는 todayEventSummaryNext, 시각이 없으면 하루 종일', (tester) async {
      await tester.pumpWidget(
        _app(summary(status: EventRowStatus.next, time: null)),
      );
      final l10n = _l10n(tester);
      expect(
        find.widgetWithText(StatusTag, l10n.todayEventSummaryNext),
        findsOneWidget,
      );
      expect(find.text(l10n.eventRowAllDay), findsOneWidget);
    });

    testWidgets('moreCount 0이면 외 N개를 붙이지 않습니다', (tester) async {
      await tester.pumpWidget(_app(summary()));
      expect(find.textContaining('외'), findsNothing);
    });

    testWidgets('긴 제목은 한 줄 말줄임이고 외 N개는 잘리지 않습니다', (tester) async {
      await tester.pumpWidget(_app(summary(title: _longTitle, moreCount: 3)));
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
      await tester.pumpWidget(_app(summary(status: null)));
      expect(find.byType(StatusTag), findsNothing);
      expect(find.text('14:00'), findsOneWidget);
    });

    testWidgets('모두 지났으면 개수 문장 한 줄만 보입니다', (tester) async {
      await tester.pumpWidget(
        _app(summary(allPastSentence: '오늘 일정 3개 모두 지났어요', moreCount: 2)),
      );
      final tokens = _context(tester).tokens;
      expect(find.byType(StatusTag), findsNothing);
      expect(find.text('14:00'), findsNothing);
      expect(find.text('회의'), findsNothing);
      expect(find.text('외 2개'), findsNothing);
      final style = _text(tester, '오늘 일정 3개 모두 지났어요').style!;
      expect(style.fontSize, tokens.typography.captionLg.fontSize);
      expect(style.color, tokens.colors.textSecondary);
      _expectNode(tester, '오늘 일정 3개 모두 지났어요', button: false);
    });

    testWidgets('스크린리더: 버튼, 라벨 틀 "상태 시각 제목" + 구분자 + 외 N개', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(summary(onTap: () {})));
      _expectNode(tester, '진행 중 14:00 회의');
      await tester.pumpWidget(
        _app(summary(status: EventRowStatus.next, moreCount: 2, onTap: () {})),
      );
      final l10n = _l10n(tester);
      expect(l10n.eventRowLabel('다음', '14:00', '회의'), '다음 14:00 회의');
      _expectNode(tester, '다음 14:00 회의${l10n.a11yListSeparator}외 2개');
      handle.dispose();
    });

    testWidgets('onTap이 없으면 라벨은 있고 버튼이 아닙니다', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(summary()));
      _expectNode(tester, '진행 중 14:00 회의', button: false);
      expect(inkLayer(find.byType(EventRow)), findsNothing);
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
        _app(summary(title: _longTitle, moreCount: 12), textScale: 2),
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

    testWidgets('좁은 폭·글자 크기 3.0에서 상태·시각도 자리가 모자라면 줄을 넘겨 넘치지 않습니다', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(summary(moreCount: 2), textScale: 3, width: 200),
      );
      expect(tester.takeException(), isNull);
      final tagRect = tester.getRect(find.byType(StatusTag));
      final timeRect = tester.getRect(find.text('14:00'));
      expect(timeRect.top, greaterThanOrEqualTo(tagRect.bottom));
      expect(timeRect.right, lessThanOrEqualTo(200));
    });
  });

  group('EventRow.list', () {
    Widget list({
      String? time = '14:00',
      String title = '회의',
      bool showDivider = true,
      VoidCallback? onTap,
    }) => EventRow.list(
      time: time,
      title: title,
      showDivider: showDivider,
      onTap: onTap,
    );

    testWidgets('1.0: 시각 칸은 58 고정이고 하루 종일도 같은 폭입니다', (tester) async {
      expect(EventRow.timeColumnWidth, 58);
      for (final time in ['14:00', null]) {
        await tester.pumpWidget(_app(list(time: time)));
        final timeText = time ?? _l10n(tester).eventRowAllDay;
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
        // 한 줄: 시각과 제목의 세로 가운데가 같습니다.
        expect(
          tester.getCenter(find.text(timeText)).dy,
          closeTo(tester.getCenter(find.text('회의')).dy, 1),
          reason: timeText,
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

    testWidgets('스크린리더: 버튼, 라벨 "시각 제목"(상태 자리 공백 없음)', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(list(onTap: () {})));
      _expectNode(tester, '14:00 회의');
      await tester.pumpWidget(_app(list(time: null, onTap: () {})));
      _expectNode(tester, '하루 종일 회의');
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

    testWidgets('2.0: 시각 글자는 numericTable × 2.0 그대로, 시각 / 제목·화살표 두 줄', (
      tester,
    ) async {
      for (final time in ['14:00', null]) {
        await tester.pumpWidget(
          _app(list(time: time, title: _longTitle), textScale: 2),
        );
        final timeText = time ?? _l10n(tester).eventRowAllDay;
        expect(tester.takeException(), isNull, reason: timeText);
        final tokens = _context(tester).tokens;
        final fontSize = tokens.typography.numericTable.fontSize!;
        expect(
          _renderedFontSize(tester, timeText, fontSize),
          fontSize * 2,
          reason: timeText,
        );
        expect(
          find.ancestor(
            of: find.text(timeText),
            matching: find.byType(FittedBox),
          ),
          findsNothing,
        );
        expect(
          tester.getRect(find.text(_longTitle)).top,
          greaterThanOrEqualTo(tester.getRect(find.text(timeText)).bottom),
          reason: timeText,
        );
        expect(tester.getRect(find.byType(Icon)).right, lessThanOrEqualTo(360));
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
          Builder(
            builder: (context) {
              final l10n = AppLocalizations.of(context);
              return EventRowListEmpty(
                message: l10n.daySheetEventEmpty,
                addLabel: l10n.daySheetEventAdd,
                onAdd: () => adds++,
              );
            },
          ),
        ),
      );
      final tokens = _context(tester).tokens;
      final l10n = _l10n(tester);
      final style = _text(tester, l10n.daySheetEventEmpty).style!;
      expect(style.fontSize, tokens.typography.captionLg.fontSize);
      expect(style.color, tokens.colors.textSecondary);
      final button = tester.widget<PrimaryButton>(find.byType(PrimaryButton));
      expect(button.variant, PrimaryButtonVariant.quiet);
      expect(button.label, l10n.daySheetEventAdd);
      await tester.tap(find.text(l10n.daySheetEventAdd));
      await tester.pumpAndSettle();
      expect(adds, 1);
    });

    testWidgets('IA 슬롯 id가 Semantics identifier로 붙습니다', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          EventRowListEmpty(
            message: '이날은 일정이 없어요.',
            addLabel: '일정 추가',
            onAdd: () {},
            messageIdentifier: SlotIds.daySheetEventEmpty,
            addIdentifier: SlotIds.daySheetEventAdd,
          ),
        ),
      );
      final message = tester
          .getSemantics(find.text('이날은 일정이 없어요.'))
          .getSemanticsData();
      expect(message.identifier, SlotIds.daySheetEventEmpty);
      expect(message.label, '이날은 일정이 없어요.');
      final add = tester.getSemantics(find.text('일정 추가')).getSemanticsData();
      expect(add.identifier, SlotIds.daySheetEventAdd);
      expect(add.label, '일정 추가');
      handle.dispose();
    });
  });

  group('EventRowListFailed', () {
    testWidgets('문구 한 줄(caption.lg text.secondary 가운데) + quiet 다시 시도·일정 추가', (
      tester,
    ) async {
      var retries = 0;
      var adds = 0;
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          EventRowListFailed(
            message: '인터넷에 연결되어 있지 않아요.',
            retryLabel: '다시 시도',
            onRetry: () => retries++,
            addLabel: '일정 추가',
            onAdd: () => adds++,
            addIdentifier: SlotIds.daySheetEventAdd,
          ),
        ),
      );
      final tokens = _context(tester).tokens;
      final message = _text(tester, '인터넷에 연결되어 있지 않아요.');
      expect(message.key, EventRowListFailed.messageKey);
      expect(message.textAlign, TextAlign.center);
      expect(message.style!.fontSize, tokens.typography.captionLg.fontSize);
      expect(message.style!.color, tokens.colors.textSecondary);
      final buttons = tester
          .widgetList<PrimaryButton>(find.byType(PrimaryButton))
          .toList();
      expect(buttons.map((b) => b.label), ['다시 시도', '일정 추가']);
      expect(
        buttons.map((b) => b.variant),
        everyElement(PrimaryButtonVariant.quiet),
      );
      expect(
        tester.getSemantics(find.text('일정 추가')).getSemanticsData().identifier,
        SlotIds.daySheetEventAdd,
      );
      await tester.tap(find.text('다시 시도'));
      await tester.tap(find.text('일정 추가'));
      await tester.pumpAndSettle();
      expect((retries, adds), (1, 1));
      handle.dispose();
    });
  });
}
