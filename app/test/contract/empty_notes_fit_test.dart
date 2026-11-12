@Tags(['contract'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/action/offer_card.dart';
import 'package:myungli_diary/design/components/depth/explain_sheet_body.dart';

import '../design/input/input_harness.dart';
import '../support/fonts.dart';

/// 글자 수 상한 표(design `lengths.md`).
const String _lengthsPath = '../docs/identity/design/lengths.md';

/// `lengths.md`에서 [slot] 행의 칸 폭(px)과 줄 수.
({double width, int lines}) _lengthOf(String slot) {
  final row = File(_lengthsPath)
      .readAsLinesSync()
      .singleWhere((line) => line.startsWith('| `$slot` |'));
  final cells = row.split('|').map((cell) => cell.trim()).toList();
  // | 슬롯 | 놓이는 칸 | 칸 폭 | 줄 | ...
  return (
    width: double.parse(cells[3].replaceFirst('px', '')),
    lines: int.parse(cells[4]),
  );
}

/// [finder] 글자가 그려진 폭과 줄 수(배율 1.0, 실제 글꼴).
({double width, int lines}) _measure(WidgetTester tester, Finder finder) {
  final paragraph = tester.renderObject<RenderParagraph>(
    find.descendant(of: finder, matching: find.byType(RichText)),
  );
  final painter = TextPainter(
    text: paragraph.text,
    textDirection: paragraph.textDirection,
    textScaler: paragraph.textScaler,
  )..layout(maxWidth: paragraph.size.width);
  final lines = painter.computeLineMetrics().length;
  painter.dispose();
  return (width: paragraph.size.width, lines: lines);
}

/// 빈 상태 안내 둘(V123)이 배율 1.0, 계약 기준 폭에서 원고 그대로 두 줄 안에 드는지 잽니다.
///
/// A139 ③(계약 `maxLines: 2`는 배율 1.0에서 원고 글자 수 상한을 잰 줄 수로 읽고 큰 글자에서는
/// 자르지 않음)의 전제를 확인합니다. 넘치면 원고(writing) 몫입니다.
void main() {
  for (final locale in AppLocalizations.supportedLocales) {
    final code = locale.languageCode;

    testWidgets('$code: offer-card unavailable 안내는 lengths.md 폭에서 줄 수 안입니다', (
      tester,
    ) async {
      await loadBundledFonts();
      final length = _lengthOf('ad-free.unavailable.body');
      final l10n = await AppLocalizations.delegate.load(locale);
      await tester.pumpWidget(
        inputApp(
          Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              // 놓이는 칸 폭은 카드 안쪽 여백을 뺀 폭입니다.
              width: length.width + OfferCard.padding * 2,
              child: OfferCard(
                state: OfferCardState.unavailable,
                head: l10n.adFreeOfferHead,
                historyLabel: l10n.adFreeHistoryCta,
                legalNotice: l10n.adFreeLegalNotice,
                unavailableNote: l10n.adFreeUnavailableBody,
              ),
            ),
          ),
          locale: locale,
        ),
      );
      final measured = _measure(tester, find.byKey(OfferCard.unavailableKey));
      expect(measured.width, length.width);
      expect(
        measured.lines,
        lessThanOrEqualTo(length.lines),
        reason: l10n.adFreeUnavailableBody,
      );
      expect(OfferCard.unavailableMaxLines, length.lines);
    });

    testWidgets('$code: 풀이 시트 emptyNote는 lengths.md 폭에서 줄 수 안입니다', (
      tester,
    ) async {
      await loadBundledFonts();
      final length = _lengthOf('ui.explain.term-empty');
      final l10n = await AppLocalizations.delegate.load(locale);
      await tester.pumpWidget(
        inputApp(
          Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              // 놓이는 칸 폭은 시트 안쪽 여백을 뺀 본문 폭입니다.
              width: length.width,
              height: 400,
              child: ExplainSheetBody(
                title: '식신',
                emptyNote: l10n.explainSheetTermEmpty,
              ),
            ),
          ),
          locale: locale,
        ),
      );
      final measured = _measure(
        tester,
        find.byKey(ExplainSheetBody.emptyNoteKey),
      );
      expect(measured.width, length.width);
      expect(
        measured.lines,
        lessThanOrEqualTo(length.lines),
        reason: l10n.explainSheetTermEmpty,
      );
      expect(ExplainSheetBody.emptyNoteMaxLines, length.lines);
    });
  }
}
