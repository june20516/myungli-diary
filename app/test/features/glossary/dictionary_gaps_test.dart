import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/platform/fakes.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';
import 'package:myungli_diary/features/glossary/application/dictionary_gaps.dart';

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

    reportDictionaryGaps(ref.read, ids);
    reportDictionaryGaps(ref.read, [...ids, 'relation.hyeong']);

    final reported = crash.errors.map((e) => e.toString()).toList();
    expect(reported, hasLength(4));
    for (final id in [...ids, 'relation.hyeong']) {
      expect(reported.where((e) => e.contains(id)), hasLength(1), reason: id);
    }
  });

  test('같은 키를 여러 화면이 보고해도 앱 실행 동안 한 번만 기록합니다', () {
    final crash = FakeCrashReporter();
    final container = ProviderContainer(
      overrides: [crashReporterProvider.overrideWithValue(crash)],
    );
    addTearDown(container.dispose);

    // 오늘, 나 탭 회고, 일기 줄이 같은 `tag.<키>` 빈칸을 각자 보고하는 상황입니다.
    reportDictionaryGaps(container.read, ['tag.gyeopjae']);
    reportDictionaryGaps(container.read, ['tag.gyeopjae']);
    reportDictionaryGaps(container.read, ['tag.gyeopjae', 'tag.sikshin']);

    expect(crash.errors, hasLength(2));
  });

  test('집합을 새 컨테이너로 비우면 같은 빈칸을 다시 보고합니다', () {
    final crash = FakeCrashReporter();
    for (var i = 0; i < 2; i++) {
      final container = ProviderContainer(
        overrides: [crashReporterProvider.overrideWithValue(crash)],
      );
      reportDictionaryGaps(container.read, ['tag.gyeopjae']);
      container.dispose();
    }

    expect(crash.errors, hasLength(2));
  });
}
