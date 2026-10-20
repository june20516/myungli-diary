import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/app/entry/entry_providers.dart';
import 'package:myungli_diary/core/api/fake/fake_server.dart';
import 'package:myungli_diary/core/api/gen/model/chart.dart';
import 'package:myungli_diary/core/api/gen/model/evidence_access.dart';
import 'package:myungli_diary/core/api/gen/model/personal_reading.dart';
import 'package:myungli_diary/core/api/gen/model/position.dart';
import 'package:myungli_diary/core/api/gen/model/shinsal_kind.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/features/depth/application/evidence_unlock_controller.dart';
import 'package:myungli_diary/features/me/application/chart_providers.dart';

import '../../../support/app_harness.dart';

/// [scenario]로 띄운 컨테이너에서 차트를 받아 둡니다(구독을 유지합니다).
Future<(ProviderContainer, Chart)> _load(String scenario) async {
  final container = await bootstrapForTest(scenario);
  addTearDown(container.dispose);
  // 계정 캐시를 열려면 진입 계산(내 정보)이 끝나야 합니다.
  await container.read(entryStateProvider.future);
  container.listen(chartControllerProvider, (_, _) {});
  final chart = await container.read(chartControllerProvider.future);
  return (container, chart);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('member: 잠긴 차트라 근거 주제의 용신 근거가 비어 있고 개인 해석이 없습니다', () async {
    final (container, chart) = await _load('member');
    expect(chart.evidenceAccess, EvidenceAccess.locked);
    const subject = ChartEvidenceSubject();
    expect(container.read(subject.access).value, EvidenceAccess.locked);
    expect(
      container.read(subject.evidenceOf(SlotIds.sajuChartYongsinBasis)).value,
      isEmpty,
    );
    expect(container.read(subject.todayReasonOf('x')), isNull);
    expect(
      personalReadingOf(
        chart,
        kind: PersonalReadingKindEnum.PersonalReadingKindDayMaster,
      ),
      isNull,
    );
  });

  test('evidence-unlocked: 용신 판정 근거와 개인 해석을 용어 자리로 찾습니다', () async {
    final (container, chart) = await _load('evidence-unlocked');
    const subject = ChartEvidenceSubject();
    expect(
      container.read(subject.evidenceOf(SlotIds.sajuChartYongsinBasis)).value,
      isNotEmpty,
    );
    // 사주 표 슬롯이 아닌 슬롯은 근거가 없습니다.
    expect(
      container.read(subject.evidenceOf('today.fortune.head')).value,
      isEmpty,
    );

    final dayMaster = personalReadingOf(
      chart,
      kind: PersonalReadingKindEnum.PersonalReadingKindDayMaster,
      position: Position.dayStem,
    );
    expect(dayMaster, isNotNull);
    final hwagae = personalReadingOf(
      chart,
      kind: PersonalReadingKindEnum.PersonalReadingKindShinsal,
      shinsal: ShinsalKind.hwagae,
    );
    expect(hwagae?.position, Position.dayBranch);
    expect(
      personalReadingOf(
        chart,
        kind: PersonalReadingKindEnum.PersonalReadingKindShinsal,
        shinsal: ShinsalKind.yeokma,
      ),
      isNull,
    );
  });

  test('사주 표 슬롯은 나의 사주, 그 밖은 오늘 응답의 근거입니다', () {
    expect(
      evidenceSubjectFor(SlotIds.sajuChartYongsinBasis),
      const ChartEvidenceSubject(),
    );
    expect(
      evidenceSubjectFor(SlotIds.todayFortuneHead),
      const DailyEvidenceSubject(),
    );
  });

  test('refreshQuietly는 캐시를 건너뛰어 다시 받고 값을 바꿉니다', () async {
    final (container, _) = await _load('member');
    final fake =
        container.read(fakeServerInterceptorProvider)! as FakeServerInterceptor;
    final before = fake.callCountOf('getChart');
    await container.read(chartControllerProvider.notifier).refreshQuietly();
    expect(fake.callCountOf('getChart'), before + 1);
    expect(container.read(chartControllerProvider).hasValue, isTrue);
  });

  test(
    '시간 모름 판정: 시주가 없거나 time_unknown 안내가 있으면 참(my-saju·saju-chart 공통)',
    () async {
      final (_, member) = await _load('member');
      expect(chartTimeUnknown(member), isFalse);
      final (_, unknown) = await _load('member-time-unknown');
      expect(chartTimeUnknown(unknown), isTrue);
      expect(
        chartTimeUnknown(member.copyWith(notices: unknown.notices)),
        isTrue,
      );
    },
  );
}
