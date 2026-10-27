import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/action/purchase_row.dart';
import 'package:myungli_diary/design/elements/skeleton_bone.dart';
import 'package:myungli_diary/design/elements/status_tag.dart';
import 'package:myungli_diary/design/theme/app_theme.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

Widget _app(Widget child, {double width = 360, double scale = 1}) =>
    MaterialApp(
      builder: (context, home) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: home!,
      ),
      locale: const Locale('ko'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: buildTheme(
        brightness: Brightness.light,
        locale: const Locale('ko'),
      ),
      home: Scaffold(
        body: Center(
          child: SizedBox(width: width, child: child),
        ),
      ),
    );

const _purchased = '2026. 10. 13. 구매';
const _period = '2026. 10. 13.~2026. 11. 13.';

void main() {
  group('purchase-row', () {
    testWidgets('줄 사이에만 1px line 구분선이 있다', (tester) async {
      await tester.pumpWidget(
        _app(
          const PurchaseRowGroup(
            rows: [
              PurchaseRowData(
                product: '광고 제거 1개월',
                purchased: _purchased,
                period: _period,
              ),
              PurchaseRowData(
                product: '광고 제거 1개월',
                purchased: _purchased,
                period: _period,
              ),
              PurchaseRowData(
                product: '광고 제거 1개월',
                purchased: _purchased,
                period: _period,
              ),
            ],
          ),
        ),
      );
      final surface =
          tester
                  .widgetList<DecoratedBox>(find.byType(DecoratedBox))
                  .first
                  .decoration
              as BoxDecoration;
      final tokens = tester.element(find.byType(PurchaseRowGroup)).tokens;
      expect(surface.color, tokens.colors.bgSheet);
      expect(surface.borderRadius, BorderRadius.circular(Radii.lg));
      final dividers = find.byKey(PurchaseRowGroup.dividerKey);
      expect(dividers, findsNWidgets(2));
      final size = tester.getSize(dividers.first);
      expect(size.height, 1);
      final context = tester.element(dividers.first);
      final box = tester.widget<ColoredBox>(dividers.first);
      expect(box.color, Theme.of(context).colorScheme.outline);
    });

    testWidgets('active는 tag.status, 그 밖의 상태는 바탕 없는 글자, status null이면 자리가 없다', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          const PurchaseRowGroup(
            rows: [
              PurchaseRowData(
                product: '광고 제거 1개월',
                status: '사용 중',
                active: true,
                purchased: _purchased,
                period: _period,
              ),
              PurchaseRowData(
                product: '광고 제거 1개월',
                status: '만료',
                purchased: _purchased,
                period: _period,
              ),
              PurchaseRowData(
                product: '광고 제거 1개월',
                purchased: _purchased,
                period: _period,
              ),
            ],
          ),
        ),
      );
      expect(find.byType(StatusTag), findsOneWidget);
      expect(find.text('사용 중'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(StatusTag),
          matching: find.text('사용 중'),
        ),
        findsOneWidget,
      );
      expect(find.text('만료'), findsOneWidget);
      expect(
        find.descendant(of: find.byType(StatusTag), matching: find.text('만료')),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.ancestor(
            of: find.text('만료'),
            matching: find.byKey(PurchaseRowGroup.statusKey),
          ),
          matching: find.byType(DecoratedBox),
        ),
        findsNothing,
        reason: '바탕 없는 상태 글자는 바탕을 그리지 않는다',
      );
      final other = tester.widget<Text>(find.text('만료'));
      final context = tester.element(find.text('만료'));
      final tokens = context.tokens;
      expect(other.style?.color, tokens.colors.textSecondary);
      expect(other.style?.fontSize, tokens.typography.labelMd.fontSize);
      expect(other.style?.fontWeight, tokens.typography.labelMd.fontWeight);
      // 상태 자리: active, 그 밖 한 줄만 있고 status null 줄에는 없다.
      expect(find.byKey(PurchaseRowGroup.statusKey), findsNWidgets(2));
    });

    testWidgets('구매일과 사용 기간은 구분 글자 없이 space.2 사이를 둔 두 줄로 나뉜다', (tester) async {
      await tester.pumpWidget(
        _app(
          const PurchaseRowGroup(
            rows: [
              PurchaseRowData(
                product: '광고 제거 1개월',
                purchased: _purchased,
                period: _period,
              ),
            ],
          ),
        ),
      );
      final purchased = tester.getRect(find.text(_purchased));
      final period = tester.getRect(find.text(_period));
      expect(period.left, purchased.left);
      expect(period.top, purchased.bottom + PurchaseRowGroup.periodGap);
      expect(PurchaseRowGroup.periodGap, Space.s2);
    });

    testWidgets('사용 기간이 없으면 구매일 줄만 있다', (tester) async {
      await tester.pumpWidget(
        _app(
          const PurchaseRowGroup(
            rows: [
              PurchaseRowData(product: '광고 제거 1개월', purchased: _purchased),
            ],
          ),
        ),
      );
      expect(find.text(_purchased), findsOneWidget);
      expect(find.text(_period), findsNothing);
    });

    testWidgets('긴 상품 이름은 말줄임 없이 감긴다', (tester) async {
      const longName = '아주아주아주 긴 스토어 상품 이름이 한 줄에 다 들어가지 않을 만큼 길게 이어집니다 정말로 길게';
      await tester.pumpWidget(
        _app(
          const PurchaseRowGroup(
            rows: [
              PurchaseRowData(
                product: longName,
                status: '사용 중',
                active: true,
                purchased: _purchased,
                period: _period,
              ),
            ],
          ),
        ),
      );
      final text = tester.widget<Text>(find.text(longName));
      expect(text.overflow, isNot(TextOverflow.ellipsis));
      expect(text.maxLines, isNull);
      expect(tester.takeException(), isNull);
      final lineHeight = tester.getSize(find.text(longName)).height;
      final single = tester.getSize(find.text(_purchased)).height;
      expect(lineHeight, greaterThan(single * 1.5));
    });

    testWidgets('상태 글자 최대 폭 80, 넘으면 폭 안에서 감긴다', (tester) async {
      Future<Size> statusSize(String status) async {
        await tester.pumpWidget(
          _app(
            PurchaseRowGroup(
              rows: [
                PurchaseRowData(
                  product: '광고 제거 1개월',
                  status: status,
                  purchased: _purchased,
                  period: _period,
                ),
              ],
            ),
          ),
        );
        return tester.getSize(find.byKey(PurchaseRowGroup.statusKey));
      }

      expect(PurchaseRowGroup.statusMaxWidth, 80);
      final short = await statusSize('만료');
      final long = await statusSize('아주아주아주아주아주 긴 상태 낱말입니다 정말로');
      expect(short.width, lessThan(80));
      expect(long.width, lessThanOrEqualTo(80));
      expect(long.height, greaterThan(short.height * 1.5));
      expect(tester.takeException(), isNull);
    });

    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets('바탕 없는 상태 글자는 상품 첫 줄과 세로 가운데가 맞다 (글자 $scale배)', (
        tester,
      ) async {
        await tester.pumpWidget(
          _app(
            const PurchaseRowGroup(
              rows: [
                PurchaseRowData(
                  product: '광고 제거',
                  status: '만료',
                  purchased: _purchased,
                  period: _period,
                ),
              ],
            ),
            scale: scale,
          ),
        );
        final product = tester.getRect(find.text('광고 제거'));
        final status = tester.getRect(find.text('만료'));
        expect(status.center.dy, closeTo(product.center.dy, 1));
      });
    }

    testWidgets('사용 중 꼬리표는 글자 1배에서 상품 첫 줄과 세로 가운데가 맞다', (tester) async {
      await tester.pumpWidget(
        _app(
          const PurchaseRowGroup(
            rows: [
              PurchaseRowData(
                product: '광고 제거',
                status: '사용 중',
                active: true,
                purchased: _purchased,
                period: _period,
              ),
            ],
          ),
        ),
      );
      final product = tester.getRect(find.text('광고 제거'));
      final tag = tester.getRect(find.byType(StatusTag));
      expect(tag.center.dy, closeTo(product.center.dy, 1));
    });

    for (final scale in [1.3, 2.0]) {
      testWidgets('꼬리표가 첫 줄보다 커지면 위쪽을 맞춘다 (글자 $scale배)', (tester) async {
        await tester.pumpWidget(
          _app(
            const PurchaseRowGroup(
              rows: [
                PurchaseRowData(
                  product: '광고 제거',
                  status: '사용 중',
                  active: true,
                  purchased: _purchased,
                  period: _period,
                ),
              ],
            ),
            scale: scale,
          ),
        );
        final product = tester.getRect(find.text('광고 제거'));
        final tag = tester.getRect(find.byType(StatusTag));
        expect(tag.top, closeTo(product.top, 1));
      });
    }

    testWidgets('한 줄을 상품 이름, 상태, 구매일, 사용 기간 한 덩어리로 읽고 누를 수 없다', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          const PurchaseRowGroup(
            rows: [
              PurchaseRowData(
                product: '광고 제거 1개월',
                status: '사용 중',
                active: true,
                purchased: _purchased,
                period: _period,
              ),
            ],
          ),
        ),
      );
      final data = tester
          .getSemantics(find.byKey(PurchaseRowGroup.rowKey))
          .getSemanticsData();
      expect(data.label, '광고 제거 1개월, 사용 중, $_purchased, $_period');
      expect(data.hasAction(SemanticsAction.tap), isFalse);
      expect(data.flagsCollection.isButton, isFalse);
      expect(find.byType(InkWell), findsNothing);
      handle.dispose();
    });

    testWidgets('loading은 줄 세 개 자리에 상품, 구매일, 사용 기간 뼈를 그리고 읽지 않는다', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(const PurchaseRowGroup.loading()));
      final root = tester.getSemantics(find.byType(PurchaseRowGroup));
      var labelled = 0;
      void visit(SemanticsNode node) {
        if (node.getSemanticsData().label.isNotEmpty) labelled++;
        node.visitChildren((child) {
          visit(child);
          return true;
        });
      }

      visit(root);
      expect(labelled, 0);
      // 뼈 자체의 ExcludeSemantics와 별개로, 묶음이 줄들을 통째로 가립니다.
      final guard = find.descendant(
        of: find.byType(PurchaseRowGroup),
        matching: find.byWidgetPredicate(
          (widget) => widget is ExcludeSemantics && widget.excluding,
        ),
      );
      expect(
        find.descendant(
          of: guard.first,
          matching: find.byKey(PurchaseRowGroup.rowKey),
        ),
        findsNWidgets(3),
      );
      expect(find.byKey(PurchaseRowGroup.rowKey), findsNWidgets(3));
      // 줄마다 상품 이름 줄, 구매일 줄, 사용 기간 줄 뼈(V47).
      expect(find.byType(SkeletonBone), findsNWidgets(9));
      expect(find.byKey(PurchaseRowGroup.dividerKey), findsNWidgets(2));
      handle.dispose();
    });
  });
}
