import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/app/entry/entry_providers.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/api/fake/fake_server.dart';
import 'package:myungli_diary/core/api/gen/model/chart.dart';
import 'package:myungli_diary/core/api/gen/model/evidence_access.dart';
import 'package:myungli_diary/core/api/gen/model/personal_reading.dart';
import 'package:myungli_diary/core/api/gen/model/position.dart';
import 'package:myungli_diary/core/api/gen/model/shinsal_kind.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/storage/cache_store.dart';
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

/// `/v1/chart` 앞에 끼우는 탭. [unlocked]면 응답을 `unlocked`로 바꾸고(보상형 광고로 연 날),
/// [offline]이면 연결 오류로 끊습니다. [hold]가 있으면 다음 요청 하나를 그때까지 붙잡습니다.
final class _ChartTap extends Interceptor {
  bool unlocked = false;
  bool offline = false;
  Completer<void>? hold;

  /// 받은 `/v1/chart` 요청 수와 돌아온 응답 수.
  int requests = 0;
  int responses = 0;

  static const _unlockedKey = 'chartTap.unlocked';

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.path != '/v1/chart') {
      handler.next(options);
      return;
    }
    requests++;
    options.extra[_unlockedKey] = unlocked;
    final gate = hold;
    hold = null;
    if (gate != null) {
      await gate.future;
    }
    if (offline) {
      handler.reject(
        DioException.connectionError(requestOptions: options, reason: 'off'),
      );
      return;
    }
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    final body = response.data;
    if (response.requestOptions.path == '/v1/chart') {
      responses++;
      if (response.requestOptions.extra[_unlockedKey] == true &&
          body is Map<String, dynamic>) {
        body['evidenceAccess'] = EvidenceAccess.unlocked.value;
      }
    }
    handler.next(response);
  }
}

/// [_load]와 같고 대역 서버 앞에 [_ChartTap]을 끼웁니다(첫 받기 전에).
Future<(ProviderContainer, _ChartTap)> _loadWithTap({
  bool unlocked = false,
}) async {
  final container = await bootstrapForTest('member');
  addTearDown(container.dispose);
  await container.read(entryStateProvider.future);
  final tap = _ChartTap()..unlocked = unlocked;
  final interceptors = container.read(dioProvider).interceptors;
  interceptors.insert(interceptors.length - 1, tap);
  container.listen(chartControllerProvider, (_, _) {});
  // 응답을 받은 뒤 캐시 쓰기와 state 갱신은 비동기라, state에 값이 들 때까지 기다립니다.
  await _untilChart(
    container,
    () =>
        tap.responses == 1 && container.read(chartControllerProvider).hasValue,
  );
  return (container, tap);
}

/// [done]이 참이 될 때까지 실제 시간으로 기다립니다(최대 3초).
Future<void> _untilChart(
  ProviderContainer container,
  bool Function() done,
) async {
  for (var i = 0; i < 300; i++) {
    if (done()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('조건이 채워지지 않음');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('캐시 먼저 보이고 server로 확인(A56·D60)', () {
    test('다시 들어오면 캐시를 먼저 보인 뒤 server 응답으로 바꿉니다', () async {
      final (container, tap) = await _loadWithTap();
      final release = Completer<void>();
      tap.hold = release;

      container.invalidate(chartControllerProvider);
      await _untilChart(container, () => tap.requests == 2);
      await _untilChart(
        container,
        () => container.read(chartControllerProvider).hasValue,
      );
      expect(tap.responses, 1);

      release.complete();
      await _untilChart(container, () => tap.responses == 2);
    });

    test('unlocked로 캐시한 차트도 server가 locked로 답하면 잠깁니다(자정 만료)', () async {
      final (container, tap) = await _loadWithTap(unlocked: true);
      expect(
        container.read(chartControllerProvider).value?.evidenceAccess,
        EvidenceAccess.unlocked,
      );
      final cache = container.read(cacheStoreProvider);
      expect(await cache.lockedKeys(CacheKind.chart), isEmpty);

      tap.unlocked = false;
      container.invalidate(chartControllerProvider);
      await _untilChart(
        container,
        () =>
            container.read(chartControllerProvider).value?.evidenceAccess ==
            EvidenceAccess.locked,
      );
      expect(tap.requests, 2);
      expect(await cache.lockedKeys(CacheKind.chart), hasLength(1));
    });

    test('오프라인이면 캐시한 차트를 그대로 보입니다', () async {
      final (container, tap) = await _loadWithTap(unlocked: true);

      tap.offline = true;
      container.invalidate(chartControllerProvider);
      await _untilChart(container, () => tap.requests == 2);
      await _untilChart(
        container,
        () => !container.read(chartControllerProvider).isLoading,
      );

      final state = container.read(chartControllerProvider);
      expect(state.hasError, isFalse);
      expect(state.value?.evidenceAccess, EvidenceAccess.unlocked);
    });
  });

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
