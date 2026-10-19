import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart' show expect, find, findsNothing;
import 'package:myungli_diary/core/api/gen/model/evidence_access.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/design/components/action/share_button.dart';
import 'package:myungli_diary/design/components/depth/evidence_lock_panel.dart';
import 'package:myungli_diary/design/components/sentence/depth_link.dart';
import 'package:myungli_diary/design/components/sentence/press_ink_target.dart';
import 'package:myungli_diary/design/components/sentence/reaction_button.dart';
import 'package:myungli_diary/design/components/sentence/term_token.dart';
import 'package:myungli_diary/design/components/today/share_image.dart';
import 'package:myungli_diary/features/depth/application/evidence_unlock_controller.dart';
import 'package:myungli_diary/features/today/application/daily_controller.dart';
import 'package:myungli_diary/testing/covers.dart';
import 'package:patrol/patrol.dart';

import 'support/e2e_app.dart';

/// [done]이 참이 될 때까지 프레임을 돌립니다. 광고 확인처럼 실제 시간이 드는 일을 기다립니다.
Future<void> _waitUntil(
  PatrolIntegrationTester $,
  bool Function() done, {
  Duration timeout = const Duration(seconds: 40),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!done()) {
    if (DateTime.now().isAfter(deadline)) {
      throw StateError('$timeout 안에 조건을 만족하지 못했습니다');
    }
    await $.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  patrolTest(
    'reward-unlock: 용어 칩 → 풀이 → 근거 → 광고 보고 열기 → 좋아요, 다크에서도 공유 미리보기는 라이트',
    ($) async {
      covers(
        const Covers(
          exits: [
            'today>explain-sheet',
            'explain-sheet>evidence-sheet',
            'evidence-sheet>system-rewarded-ad',
            'today>share-preview',
          ],
          decisions: ['D60'],
        ),
      );
      // 문구가 아니라 IA id·Key·위젯 타입으로 찾으므로 기기 언어와 무관하지만, 표시 언어는 고정합니다.
      final container = await launchApp(
        $,
        flow: 'today',
        scenario: 'reward-unlock',
        deviceLocale: const Locale('ko', 'KR'),
      );
      await expectScreen($, ScreenIds.today);

      // 용어 칩 → 풀이 시트.
      // 오늘 내용이 올 때까지 기다린 뒤 첫 칩(총운의 `element.wood`)을 누릅니다.
      await $(TermToken).tap();
      await expectScreen($, ScreenIds.explainSheet);

      // 풀이 시트의 근거 보기 → 그 위에 근거 시트(잠김).
      await $(
        find.descendant(
          of: find.descendant(
            of: find.byKey(const Key(ScreenIds.explainSheet)),
            matching: find.byType(DepthLink),
          ),
          matching: find.byType(PressInkTarget),
        ),
      ).tap();
      await expectScreen($, ScreenIds.evidenceSheet, state: 'locked');
      final sheet = find.byKey(const Key(ScreenIds.evidenceSheet));
      final unlock = evidenceUnlockControllerProvider(
        const DailyEvidenceSubject(),
      );
      await _waitUntil(
        $,
        () => container.exists(unlock) && container.read(unlock).adReady,
      );

      // 광고를 끝까지 보면 이용권을 확인하고, 다시 받은 오늘 풀이가 unlocked입니다.
      await $(
        find.descendant(
          of: sheet,
          matching: find.byKey(EvidenceLockPanel.ctaKey),
        ),
      ).tap();
      await _waitUntil(
        $,
        () =>
            container
                    .read(dailyControllerProvider)
                    .value
                    ?.daily
                    .evidenceAccess ==
                EvidenceAccess.unlocked &&
            find
                .descendant(of: sheet, matching: find.byType(EvidenceLockPanel))
                .evaluate()
                .isEmpty,
      );
      await expectScreen($, ScreenIds.evidenceSheet, state: 'unlocked');

      // 바깥을 누르면 쌓인 시트가 모두 닫힙니다.
      await closeSheets($);
      expect(sheet, findsNothing);
      expect(find.byKey(const Key(ScreenIds.explainSheet)), findsNothing);

      // 총운 첫 문장에 좋아요를 켭니다.
      await $(find.byKey(ReactionButton.targetKey)).tap();
      await _waitUntil(
        $,
        () => $.tester.widget<ReactionButton>(find.byType(ReactionButton)).on,
      );
      await expectScreen($, ScreenIds.today, state: 'liked');

      // 기기를 다크로 바꿔도 공유 미리보기의 이미지는 라이트입니다(V5).
      $.tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      try {
        await $.pumpAndTrySettle();
        await $(find.byType(ShareButton)).tap();
        await expectScreen($, ScreenIds.sharePreview, state: 'dark');
        final canvas = $.tester.element(find.byKey(ShareImage.canvasKey));
        expect(Theme.of(canvas).brightness, Brightness.light);
        expect(
          Theme.of(
            $.tester.element(find.byKey(const Key(ScreenIds.sharePreview))),
          ).brightness,
          Brightness.dark,
        );
        await closeSheets($);
        expect(find.byKey(const Key(ScreenIds.sharePreview)), findsNothing);
      } finally {
        $.tester.platformDispatcher.clearPlatformBrightnessTestValue();
      }
    },
  );
}
