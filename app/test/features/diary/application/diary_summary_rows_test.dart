import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/app/diary_summary_rows.dart';
import 'package:myungli_diary/core/api/gen/model/diary_summary.dart';
import 'package:myungli_diary/features/diary/application/diary_summary_rows.dart';
import 'package:myungli_diary/features/diary/presentation/diary_page_list.dart';

final _summary = DiarySummary(
  id: 'd1',
  date: '2026-10-12',
  createdAt: DateTime.utc(2026, 10, 12, 9),
  excerpt: '일기',
  featuredTags: const [],
);

void main() {
  test('연결하지 않으면 줄을 만들 때 실패합니다', () {
    final plain = ProviderContainer();
    addTearDown(plain.dispose);
    expect(
      () => plain.read(diarySummaryRowProvider)(
        _summary,
        isLast: true,
        tagLinked: true,
      ),
      throwsUnimplementedError,
    );
  });

  test('app의 override가 DiarySummaryRow를 잇습니다', () {
    final wired = ProviderContainer(overrides: diarySummaryRowOverrides);
    addTearDown(wired.dispose);
    final row = wired.read(diarySummaryRowProvider)(
      _summary,
      isLast: true,
      tagLinked: false,
    );
    expect(row, isA<DiarySummaryRow>());
    expect((row as DiarySummaryRow).summary, _summary);
    expect(row.isLast, isTrue);
    expect(row.tagLinked, isFalse);
  });
}
