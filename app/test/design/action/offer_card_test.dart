import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations_ko.dart';
import 'package:myungli_diary/design/components/action/offer_card.dart';
import 'package:myungli_diary/design/components/action/primary_button.dart';
import 'package:myungli_diary/design/elements/app_icon.dart';
import 'package:myungli_diary/design/elements/status_tag.dart';
import 'package:myungli_diary/design/theme/app_theme.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:phosphor_glyphs/phosphor_glyphs.dart';

const _head = '한 달 동안 광고 없이 봐요';
const _price = '가격';
const _period = '1개월, 자동 갱신 없음';

/// 카드 라벨의 항목 구분자(ko).
final _separator = AppLocalizationsKo().a11yListSeparator;

Widget _app(Widget child) => MaterialApp(
  locale: const Locale('ko'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: buildTheme(brightness: Brightness.light, locale: const Locale('ko')),
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

OfferCard _card(
  OfferCardState state, {
  VoidCallback? onBuy,
  VoidCallback? onHistory,
  VoidCallback? onLegal,
}) => OfferCard(
  state: state,
  head: _head,
  price: _price,
  period: _period,
  buyLabel: '구매하기',
  historyLabel: '구매 내역',
  legalNotice: '구매 전에 약관을 확인해 주세요.',
  statusLabel: '사용 중',
  remaining: '11월 23일까지 광고 없이 볼 수 있어요',
  onBuy: onBuy,
  onHistory: onHistory,
  onLegal: onLegal,
);

void main() {
  group('offer-card', () {
    testWidgets('available은 구매 버튼, active는 꼬리표와 남은 기간이고 구매 버튼이 없다', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(_card(OfferCardState.available, onBuy: () {})),
      );
      expect(find.byKey(OfferCard.buyKey), findsOneWidget);
      expect(find.byType(StatusTag), findsNothing);
      expect(find.text('11월 23일까지 광고 없이 볼 수 있어요'), findsNothing);

      await tester.pumpWidget(_app(_card(OfferCardState.active)));
      await tester.pumpAndSettle();
      expect(find.byKey(OfferCard.buyKey), findsNothing);
      expect(find.byType(StatusTag), findsOneWidget);
      expect(find.text('사용 중'), findsOneWidget);
      expect(find.text('11월 23일까지 광고 없이 볼 수 있어요'), findsOneWidget);
    });

    testWidgets('purchasing은 구매 버튼 loading이고 onBuy가 불리지 않는다', (tester) async {
      var bought = 0;
      await tester.pumpWidget(
        _app(_card(OfferCardState.purchasing, onBuy: () => bought++)),
      );
      await tester.pump(const Duration(seconds: 1));
      final buy = tester.widget<PrimaryButton>(find.byKey(OfferCard.buyKey));
      expect(buy.loading, isTrue);
      await tester.tap(find.byKey(OfferCard.buyKey));
      expect(bought, 0);
    });

    testWidgets('offline은 구매 버튼 비활성, 구매 내역 버튼은 누를 수 있다', (tester) async {
      var bought = 0;
      var history = 0;
      await tester.pumpWidget(
        _app(
          _card(
            OfferCardState.offline,
            onBuy: () => bought++,
            onHistory: () => history++,
          ),
        ),
      );
      final buy = tester.widget<PrimaryButton>(find.byKey(OfferCard.buyKey));
      expect(buy.onPressed, isNull);
      await tester.tap(find.byKey(OfferCard.buyKey));
      await tester.tap(find.byKey(OfferCard.historyKey));
      await tester.pumpAndSettle();
      expect(bought, 0);
      expect(history, 1);
    });

    testWidgets('구매 내역 버튼은 네 상태 모두 보인다', (tester) async {
      for (final state in OfferCardState.values) {
        await tester.pumpWidget(_app(_card(state, onHistory: () {})));
        await tester.pump(const Duration(seconds: 1));
        expect(
          find.byKey(OfferCard.historyKey),
          findsOneWidget,
          reason: state.name,
        );
        expect(find.text('구매 내역'), findsOneWidget, reason: state.name);
        final history = tester.widget<PrimaryButton>(
          find.byKey(OfferCard.historyKey),
        );
        expect(history.variant, PrimaryButtonVariant.quiet);
      }
    });

    testWidgets('약관 안내를 누르면 onLegal이 불린다', (tester) async {
      var legal = 0;
      await tester.pumpWidget(
        _app(_card(OfferCardState.available, onLegal: () => legal++)),
      );
      await tester.tap(find.byKey(OfferCard.legalKey));
      await tester.pumpAndSettle();
      expect(legal, 1);
    });

    testWidgets('카드 semantics는 라벨 있는 묶음이고 가격 문장을 함께 읽는다', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(_card(OfferCardState.available)));
      // 이 Flutter에는 group 역할이 없어 container + explicitChildNodes로 묶습니다.
      final group = tester.widget<Semantics>(find.byKey(OfferCard.cardKey));
      expect(group.container, isTrue);
      expect(group.explicitChildNodes, isTrue);
      final node = tester.getSemantics(find.byKey(OfferCard.cardKey));
      final data = node.getSemanticsData();
      expect(data.flagsCollection.isButton, isFalse);
      expect(data.label, [_head, _price, _period].join(_separator));
      var children = 0;
      node.visitChildren((_) {
        children++;
        return true;
      });
      expect(children, greaterThanOrEqualTo(2), reason: '구매·구매 내역 버튼은 따로 읽힘');
      handle.dispose();
    });

    testWidgets('period는 가격 아래 작은 보조색 글씨이고 구매 버튼보다 위다', (tester) async {
      await tester.pumpWidget(_app(_card(OfferCardState.available)));
      final priceBottom = tester.getBottomLeft(find.text(_price)).dy;
      final periodTop = tester.getTopLeft(find.text(_period)).dy;
      final periodBottom = tester.getBottomLeft(find.text(_period)).dy;
      final buyTop = tester.getTopLeft(find.byKey(OfferCard.buyKey)).dy;
      expect(periodTop - priceBottom, OfferCard.periodGap);
      expect(buyTop - periodBottom, OfferCard.buyGap);

      final context = tester.element(find.byKey(OfferCard.cardKey));
      final tokens = context.tokens;
      final captionLg = tokens.typography.captionLg;
      final style = tester.widget<Text>(find.text(_period)).style!;
      expect(style.fontSize, captionLg.fontSize);
      expect(style.fontWeight, captionLg.fontWeight);
      expect(style.height, captionLg.height);
      expect(style.color, tokens.colors.textSecondary);
    });

    testWidgets('period가 null이면 기간 줄이 없고 라벨에 끝 구분자가 남지 않는다', (tester) async {
      final handle = tester.ensureSemantics();
      const card = OfferCard(
        state: OfferCardState.available,
        head: _head,
        price: _price,
        buyLabel: '구매하기',
        historyLabel: '구매 내역',
        legalNotice: '구매 전에 약관을 확인해 주세요.',
      );
      await tester.pumpWidget(_app(card));
      expect(find.text(_period), findsNothing);
      final label = tester.getSemantics(find.byKey(OfferCard.cardKey)).label;
      expect(label, [_head, _price].join(_separator));
      handle.dispose();
    });

    testWidgets('price가 null이어도 period는 보인다', (tester) async {
      final handle = tester.ensureSemantics();
      const card = OfferCard(
        state: OfferCardState.offline,
        head: _head,
        period: _period,
        buyLabel: '구매하기',
        historyLabel: '구매 내역',
        legalNotice: '구매 전에 약관을 확인해 주세요.',
      );
      await tester.pumpWidget(_app(card));
      expect(find.text(_period), findsOneWidget);
      expect(find.text(_price), findsNothing);
      final label = tester.getSemantics(find.byKey(OfferCard.cardKey)).label;
      expect(label, [_head, _period].join(_separator));
      // 가격 줄이 없으면 head 아래 가격 자리 간격(priceGap)으로 기간이 시작합니다.
      final headBottom = tester.getBottomLeft(find.text(_head)).dy;
      final periodTop = tester.getTopLeft(find.text(_period)).dy;
      expect(periodTop - headBottom, OfferCard.priceGap);
      handle.dispose();
    });

    testWidgets('price와 period가 모두 null이면 라벨은 head만이다', (tester) async {
      final handle = tester.ensureSemantics();
      const card = OfferCard(
        state: OfferCardState.offline,
        head: _head,
        buyLabel: '구매하기',
        historyLabel: '구매 내역',
        legalNotice: '구매 전에 약관을 확인해 주세요.',
      );
      await tester.pumpWidget(_app(card));
      final noPrice = tester.getSize(find.byKey(OfferCard.cardKey)).height;
      expect(find.text(_price), findsNothing);
      expect(tester.getSemantics(find.byKey(OfferCard.cardKey)).label, _head);
      await tester.pumpWidget(_app(_card(OfferCardState.offline)));
      final priced = tester.getSize(find.byKey(OfferCard.cardKey)).height;
      expect(
        priced - noPrice,
        greaterThanOrEqualTo(OfferCard.priceGap),
        reason: '가격 줄과 그 위 간격이 빠짐',
      );
      handle.dispose();
    });

    testWidgets('아이콘은 명세대로 sparkle light 28이다', (tester) async {
      await tester.pumpWidget(_app(_card(OfferCardState.available)));
      final icon = tester.widget<AppIcon>(find.byType(AppIcon));
      expect(icon.weight, AppIconWeight.light);
      expect(icon.size.logical, 28);
      final drawn = tester.widget<Icon>(
        find.descendant(of: find.byType(AppIcon), matching: find.byType(Icon)),
      );
      expect(drawn.icon, PhosphorIconsLight.sparkle);
    });

    testWidgets('부품별 identifier가 Semantics identifier로 붙는다', (tester) async {
      final handle = tester.ensureSemantics();
      const ids = OfferCardIdentifiers(
        head: 'x.offer.head',
        price: 'x.offer.price',
        period: 'x.offer.period',
        remaining: 'x.status.remaining',
        buy: 'x.buy.cta',
        history: 'x.history.cta',
        legal: 'x.legal.notice',
      );
      OfferCard card(OfferCardState state) => OfferCard(
        state: state,
        head: _head,
        price: _price,
        period: _period,
        buyLabel: '구매하기',
        historyLabel: '구매 내역',
        legalNotice: '구매 전에 약관을 확인해 주세요.',
        statusLabel: '사용 중',
        remaining: '11월 23일까지 광고 없이 볼 수 있어요',
        onBuy: () {},
        identifiers: ids,
      );

      await tester.pumpWidget(_app(card(OfferCardState.available)));
      for (final id in [
        ids.head,
        ids.price,
        ids.period,
        ids.buy,
        ids.history,
        ids.legal,
      ]) {
        expect(find.bySemanticsIdentifier(id!), findsOneWidget, reason: id);
      }
      expect(find.bySemanticsIdentifier(ids.remaining!), findsNothing);
      // identifier를 달아도 카드는 head·price·period를 한 라벨로 읽습니다.
      expect(
        tester.getSemantics(find.byKey(OfferCard.cardKey)).label,
        [_head, _price, _period].join(_separator),
      );

      await tester.pumpWidget(_app(card(OfferCardState.active)));
      await tester.pumpAndSettle();
      expect(find.bySemanticsIdentifier(ids.remaining!), findsOneWidget);
      expect(find.bySemanticsIdentifier(ids.buy!), findsNothing);
      handle.dispose();
    });
  });
}
