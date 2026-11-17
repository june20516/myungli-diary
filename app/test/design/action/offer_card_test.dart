import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations_ko.dart';
import 'package:myungli_diary/design/components/action/offer_card.dart';
import 'package:myungli_diary/design/components/action/primary_button.dart';
import 'package:myungli_diary/design/elements/app_icon.dart';
import 'package:myungli_diary/design/elements/unlock_mark.dart';
import 'package:myungli_diary/design/interaction/patterns.dart';
import 'package:myungli_diary/design/interaction/unlock_glint.dart';
import 'package:myungli_diary/design/theme/app_theme.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:phosphor_glyphs/phosphor_glyphs.dart';

const _head = '한 달 동안 광고 없이 봐요';
const _price = '가격';
const _period = '1개월 동안 이용';
const _renewal = '자동 결제 없음, 다음 달에 결제되지 않아요';
const _statusLabel = '사용 중';
const _until = '2026년 12월 17일까지';
const _benefit = '광고 없이, 근거와 해석도 모두 열려 있어요.';
const _unavailable = '지금은 광고 제거권을 구매할 수 없어요.';

/// 카드 라벨의 항목 구분자(ko).
final String _separator = AppLocalizationsKo().a11yListSeparator;

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
  String? benefit = _benefit,
  bool justPurchased = false,
}) => OfferCard(
  state: state,
  head: _head,
  price: _price,
  period: _period,
  renewal: _renewal,
  buyLabel: '구매하기',
  historyLabel: '구매 내역',
  legalNotice: '구매 전에 약관을 확인해 주세요.',
  statusLabel: _statusLabel,
  remaining: _until,
  benefit: benefit,
  justPurchased: justPurchased,
  unavailableNote: _unavailable,
  onBuy: onBuy,
  onHistory: onHistory,
  onLegal: onLegal,
);

void main() {
  group('offer-card', () {
    testWidgets('available은 가격, 확인 두 줄, 구매 버튼이고 이용 중 표시가 없다', (tester) async {
      await tester.pumpWidget(
        _app(_card(OfferCardState.available, onBuy: () {})),
      );
      expect(find.byKey(OfferCard.buyKey), findsOneWidget);
      expect(find.text(_price), findsOneWidget);
      expect(find.text(_period), findsOneWidget);
      expect(find.text(_renewal), findsOneWidget);
      expect(find.byKey(OfferCard.ownedKey), findsNothing);
      expect(find.text(_until), findsNothing);
    });

    testWidgets('active는 가격, 확인 두 줄, 구매 버튼 대신 이용 중 표시다(V135)', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(_card(OfferCardState.active)));
      await tester.pumpAndSettle();
      expect(find.byKey(OfferCard.buyKey), findsNothing);
      expect(find.text(_price), findsNothing);
      expect(find.byKey(OfferCard.termsKey), findsNothing);
      expect(find.byKey(OfferCard.ownedKey), findsOneWidget);
      expect(find.byKey(OfferCard.historyKey), findsOneWidget);

      final context = tester.element(find.byKey(OfferCard.cardKey));
      final tokens = context.tokens;
      // 사용 중: type.label.lg를 gradient.unlocked로 칠함(unlock.mark title).
      expect(
        find.ancestor(
          of: find.text(_statusLabel),
          matching: find.byType(UnlockMarkTitle),
        ),
        findsOneWidget,
      );
      final label = tester.widget<Text>(find.text(_statusLabel)).style!;
      expect(label.fontSize, tokens.typography.labelLg.fontSize);
      // 끝나는 날: type.title, text.primary, 사용 중 아래 4.
      final until = tester.widget<Text>(find.text(_until)).style!;
      expect(until.fontSize, tokens.typography.title.fontSize);
      expect(until.color, tokens.colors.textPrimary);
      expect(
        tester.getTopLeft(find.text(_until)).dy -
            tester.getBottomLeft(find.text(_statusLabel)).dy,
        OfferCard.untilGap,
      );
      // 혜택 한 줄: type.caption.lg, text.secondary, 끝나는 날 아래 4.
      final benefit = tester.widget<Text>(find.text(_benefit)).style!;
      expect(benefit.fontSize, tokens.typography.captionLg.fontSize);
      expect(benefit.color, tokens.colors.textSecondary);
      expect(
        tester.getTopLeft(find.text(_benefit)).dy -
            tester.getBottomLeft(find.text(_until)).dy,
        OfferCard.benefitGap,
      );
      // head 아래 24에서 시작하고, 왼쪽 밖 12에 세로선이 있습니다.
      expect(
        tester.getTopLeft(find.byKey(OfferCard.ownedKey)).dy -
            tester.getBottomLeft(find.text(_head)).dy,
        OfferCard.ownedGap,
      );
      expect(find.byKey(UnlockMarkRule.ruleKey), findsOneWidget);
      expect(
        tester.getTopLeft(find.byKey(UnlockMarkRule.ruleKey)).dx,
        tester.getTopLeft(find.text(_head)).dx + UnlockMark.ruleOffsetStart,
      );
      // 스크린리더는 주는 것 + 사용 중 + 끝나는 날 + 혜택을 한 묶음으로 읽습니다.
      expect(
        tester.getSemantics(find.byKey(OfferCard.cardKey)).label,
        [_head, _statusLabel, _until, _benefit].join(_separator),
      );
      handle.dispose();
    });

    testWidgets('active 혜택 한 줄이 비면 그리지 않는다', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(_card(OfferCardState.active, benefit: '')));
      await tester.pumpAndSettle();
      expect(find.text(_benefit), findsNothing);
      expect(
        tester.getSemantics(find.byKey(OfferCard.cardKey)).label,
        [_head, _statusLabel, _until].join(_separator),
      );
      handle.dispose();
    });

    testWidgets('구매 직후 이용 중이 되면 head에 반짝임이 한 번 지나가고 반복하지 않는다', (tester) async {
      // 여러 element가 같은 render object를 가리키므로 한 번씩만 셉니다.
      int glinting() => tester.allRenderObjects
          .whereType<RenderUnlockGlint>()
          .toSet()
          .where((render) => render.glinting)
          .length;
      await tester.pumpWidget(
        _app(_card(OfferCardState.active, justPurchased: true)),
      );
      await tester.pump(InteractionPattern.appearSeep.duration);
      await tester.pump(const Duration(milliseconds: 300));
      expect(glinting(), 1, reason: 'head 하나');
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(seconds: 5));
        expect(glinting(), 0, reason: '다시 지나가지 않음');
      }
    });

    testWidgets('구매 직후가 아니면 이용 중 카드에 반짝임이 없다', (tester) async {
      await tester.pumpWidget(_app(_card(OfferCardState.active)));
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(seconds: 5));
        expect(
          tester.allRenderObjects.whereType<RenderUnlockGlint>().where(
            (render) => render.glinting,
          ),
          isEmpty,
        );
      }
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

    testWidgets('unavailable은 가격, 기간, 구매 버튼 대신 안내 한 줄이고 나머지는 그대로다(V123)', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      var history = 0;
      await tester.pumpWidget(
        _app(_card(OfferCardState.unavailable, onHistory: () => history++)),
      );
      final tokens = tester.element(find.byType(OfferCard)).tokens;
      expect(find.text(_price), findsNothing);
      expect(find.text(_period), findsNothing);
      expect(find.byKey(OfferCard.buyKey), findsNothing);
      expect(find.byKey(OfferCard.termsKey), findsNothing);
      expect(find.byKey(OfferCard.ownedKey), findsNothing);
      expect(find.text(_head), findsOneWidget);
      expect(find.byType(AppIcon), findsOneWidget);
      expect(find.byKey(OfferCard.legalKey), findsOneWidget);
      final note = find.byKey(OfferCard.unavailableKey);
      final text = tester.widget<Text>(note);
      expect(text.data, _unavailable);
      expect(text.style!.fontSize, tokens.typography.bodyUi.fontSize);
      expect(text.style!.color, tokens.colors.textSecondary);
      // 주는 것 한 줄 아래 16에 놓이고 누를 수 없습니다.
      expect(
        tester.getTopLeft(note).dy - tester.getBottomLeft(find.text(_head)).dy,
        OfferCard.unavailableGap,
      );
      expect(
        find.ancestor(of: note, matching: find.byType(GestureDetector)),
        findsNothing,
      );
      // 스크린리더는 카드 묶음에서 주는 것 한 줄 + 안내를 읽습니다.
      expect(
        tester.getSemantics(find.byKey(OfferCard.cardKey)).label,
        [_head, _unavailable].join(_separator),
      );
      await tester.tap(find.byKey(OfferCard.historyKey));
      await tester.pumpAndSettle();
      expect(history, 1);
      handle.dispose();
    });

    testWidgets('unavailable 안내는 큰 글자에서도 자르지 않고 넘치지 않는다', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(
        _app(SizedBox(width: 320, child: _card(OfferCardState.unavailable))),
      );
      expect(tester.takeException(), isNull);
      final text = tester.widget<Text>(find.byKey(OfferCard.unavailableKey));
      expect(text.overflow, isNot(TextOverflow.ellipsis));
    });

    testWidgets('구매 내역 버튼은 모든 상태에서 보인다', (tester) async {
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
      expect(data.label, [_head, _price, _period, _renewal].join(_separator));
      var children = 0;
      node.visitChildren((_) {
        children++;
        return true;
      });
      expect(children, greaterThanOrEqualTo(2), reason: '구매·구매 내역 버튼은 따로 읽힘');
      handle.dispose();
    });

    testWidgets('확인 두 줄은 가격 아래 진한 본문 글씨와 check 16이고 구매 버튼보다 위다(V135)', (
      tester,
    ) async {
      await tester.pumpWidget(_app(_card(OfferCardState.available)));
      final priceBottom = tester.getBottomLeft(find.text(_price)).dy;
      final periodTop = tester.getTopLeft(find.text(_period)).dy;
      final periodBottom = tester.getBottomLeft(find.text(_period)).dy;
      final renewalTop = tester.getTopLeft(find.text(_renewal)).dy;
      final renewalBottom = tester.getBottomLeft(find.text(_renewal)).dy;
      final buyTop = tester.getTopLeft(find.byKey(OfferCard.buyKey)).dy;
      expect(periodTop - priceBottom, OfferCard.termsGap);
      expect(renewalTop - periodBottom, OfferCard.termsLineGap);
      expect(buyTop - renewalBottom, OfferCard.buyGap);

      final context = tester.element(find.byKey(OfferCard.cardKey));
      final tokens = context.tokens;
      final bodyUi = tokens.typography.bodyUi;
      for (final text in [_period, _renewal]) {
        final style = tester.widget<Text>(find.text(text)).style!;
        expect(style.fontSize, bodyUi.fontSize, reason: text);
        expect(style.color, tokens.colors.textPrimary, reason: text);
      }
      final checks = tester
          .widgetList<AppIcon>(
            find.descendant(
              of: find.byKey(OfferCard.termsKey),
              matching: find.byType(AppIcon),
            ),
          )
          .toList();
      expect(checks, hasLength(2));
      for (final check in checks) {
        expect(check.size, OfferCard.termsIconSize);
        expect(check.weight, AppIconWeight.regular);
        expect(check.color, tokens.colors.actionPrimary);
      }
      // 아이콘과 글자 사이 8.
      final iconRight = tester
          .getTopRight(
            find
                .descendant(
                  of: find.byKey(OfferCard.termsKey),
                  matching: find.byType(AppIcon),
                )
                .first,
          )
          .dx;
      expect(
        tester.getTopLeft(find.text(_period)).dx - iconRight,
        OfferCard.termsIconGap,
      );
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
      final icon = tester.widget<AppIcon>(find.byType(AppIcon).first);
      expect(icon.weight, AppIconWeight.light);
      expect(icon.size!.logical, 28);
      final drawn = tester.widget<Icon>(
        find.descendant(
          of: find.byType(AppIcon).first,
          matching: find.byType(Icon),
        ),
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
        statusLabel: _statusLabel,
        remaining: _until,
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
