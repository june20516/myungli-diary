import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/platform/fakes.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';
import 'package:myungli_diary/features/calendar/application/score_item_gaps.dart';

void main() {
  testWidgets('score_item.*, day_kind.*, relation.* 형식 모두 id마다 한 번만 보고합니다', (
    tester,
  ) async {
    final crash = FakeCrashReporter();
    late WidgetRef ref;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [crashReporterProvider.overrideWithValue(crash)],
        child: Consumer(
          builder: (context, widgetRef, _) {
            ref = widgetRef;
            return const SizedBox();
          },
        ),
      ),
    );
    const ids = ['score_item.hap', 'day_kind.gwiin_day', 'relation.chung'];

    reportScoreItemGaps(ref, ids);
    reportScoreItemGaps(ref, [...ids, 'relation.hyeong']);

    final reported = crash.errors.map((e) => e.toString()).toList();
    expect(reported, hasLength(4));
    for (final id in [...ids, 'relation.hyeong']) {
      expect(reported.where((e) => e.contains(id)), hasLength(1), reason: id);
    }
  });
}
