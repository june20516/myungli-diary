import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/fake/fake_server.dart';
import 'package:myungli_diary/core/api/fake/scenario.dart';
import 'package:myungli_diary/core/api/gen/api/default_api.dart';
import 'package:myungli_diary/core/api/gen/model/guide_choice.dart';
import 'package:myungli_diary/core/api/rendered_text_plain.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:myungli_diary/core/clock/clock.dart';
import 'package:myungli_diary/core/platform/fakes.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';
import 'package:myungli_diary/core/storage/app_database.dart';
import 'package:myungli_diary/core/storage/cache_store.dart';
import 'package:myungli_diary/core/storage/secure_store.dart';
import 'package:myungli_diary/features/diary/application/diary_edit.dart';
import 'package:myungli_diary/features/diary/application/diary_providers.dart';
import 'package:myungli_diary/features/diary/model/diary_draft_target.dart';
import 'package:myungli_diary/features/diary/model/diary_edit_target.dart';

final _today = CalendarDate(2026, 10, 13);

/// member fixture의 그날 후보 앞 둘(guide.harmony 1, 2)과,
/// fixture에 없는 셋째 후보(guide.gongmang 1).
const _first = '오늘 마음이 잘 맞았던 대화가 있었다면 적어 볼까요?';
const _second = '오늘 함께해서 좋았던 사람이 있었나요?';
const _third = '오늘 기대와 다르게 흘러간 일이 있었다면 하나 적어 볼까요?';

Map<String, Object?> _candidate(String key, String variant, String text) => {
  'slot': 'daily.guide',
  'messageKey': key,
  'variant': variant,
  'reactable': false,
  'text': {
    'segments': [
      {'text': text},
    ],
  },
};

/// fake 서버(member) 앞에서 요청을 엿보고, `getDaily` 후보를 바꾸거나 `createDiary`를 끊습니다.
final class _Network extends Interceptor {
  bool offline = false;

  /// 다음 `createDiary` 요청 하나를 시간 초과로 끊습니다.
  bool timeoutNextCreate = false;

  /// `getDaily`만 연결 오류로 끊습니다.
  bool dailyOffline = false;

  /// 있으면 `getDaily` 요청을 이 completer가 끝날 때까지 붙잡습니다.
  Completer<void>? holdDaily;

  /// `getDaily`를 503 problem으로 끊습니다.
  bool dailyUnavailable = false;

  /// 있으면 `getDaily`를 서버를 거치지 않고 이 본문으로 바로 답합니다.
  Map<String, Object?>? dailyImmediate;

  /// 있으면 `getDaily` 응답의 `guideCandidates`를 이 목록으로 바꿉니다.
  List<Map<String, Object?>>? candidates;

  /// `createDiary` 요청 본문과 `Idempotency-Key`.
  final creates = <({Map<String, Object?> body, String? key})>[];

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.path.contains('/daily')) {
      if (dailyOffline) {
        handler.reject(
          DioException.connectionError(requestOptions: options, reason: '오프라인'),
        );
        return;
      }
      if (dailyUnavailable) {
        handler.reject(
          DioException.badResponse(
            statusCode: 503,
            requestOptions: options,
            response: Response<Object?>(
              requestOptions: options,
              statusCode: 503,
              data: {
                'type': 'about:blank',
                'title': 'Unavailable',
                'status': 503,
                'code': 'service.unavailable',
                'traceId': 'test',
              },
              headers: Headers.fromMap({
                Headers.contentTypeHeader: ['application/problem+json'],
              }),
            ),
          ),
        );
        return;
      }
      final immediate = dailyImmediate;
      if (immediate != null) {
        handler.resolve(
          Response<Object?>(
            requestOptions: options,
            statusCode: 200,
            data: immediate,
          ),
        );
        return;
      }
      final hold = holdDaily;
      if (hold != null) {
        unawaited(hold.future.then((_) => handler.next(options)));
        return;
      }
    }
    if (options.method == 'POST' && options.path == '/v1/diaries') {
      creates.add((
        body: _jsonObject(options.data),
        key: options.headers['Idempotency-Key'] as String?,
      ));
      if (timeoutNextCreate) {
        timeoutNextCreate = false;
        handler.reject(
          DioException.receiveTimeout(
            timeout: const Duration(seconds: 1),
            requestOptions: options,
          ),
        );
        return;
      }
    }
    if (offline) {
      handler.reject(
        DioException.connectionError(requestOptions: options, reason: '오프라인'),
      );
      return;
    }
    handler.next(options);
  }

  @override
  void onResponse(
    Response<Object?> response,
    ResponseInterceptorHandler handler,
  ) {
    final override = candidates;
    if (override != null && response.requestOptions.path.contains('/daily')) {
      final data = response.data;
      final changed = {..._jsonObject(data), 'guideCandidates': override};
      response.data = data is String ? jsonEncode(changed) : changed;
    }
    handler.next(response);
  }
}

/// 요청·응답 본문(JSON 글자 또는 이미 푼 객체)을 객체로 풉니다.
Map<String, Object?> _jsonObject(Object? data) => Map<String, Object?>.from(
  (data is String ? jsonDecode(data) : data)! as Map,
);

final class _Harness {
  new(this.container, this.server, this.network);

  final ProviderContainer container;
  final FakeServerInterceptor server;
  final _Network network;

  DiaryEdit notifier(DiaryEditTarget target) =>
      container.read(diaryEditProvider(target).notifier);

  DiaryEditState state(DiaryEditTarget target) =>
      container.read(diaryEditProvider(target)).requireValue;
}

Future<_Harness> _harness() async {
  final scenario = (await loadScenarios(rootBundle))
      .singleWhere((s) => s.id == 'member');
  final server = FakeServerInterceptor(scenario: scenario, bundle: rootBundle);
  final network = _Network();
  // 서버 응답 뒤 후보를 바꾸려면 엿보기가 서버 뒤(응답 쪽 먼저)에 있어야 합니다.
  final dio = Dio(BaseOptions(baseUrl: 'http://localhost:8080'))
    ..interceptors.addAll([network, server]);
  final database = AppDatabase.forExecutor(NativeDatabase.memory());
  final container = ProviderContainer(
    overrides: [
      restClientProvider.overrideWithValue(DefaultApi(dio)),
      secureStoreProvider.overrideWithValue(MemorySecureStore()),
      appDatabaseProvider.overrideWithValue(database),
      currentAccountIdProvider.overrideWithValue('a'),
      todayProvider.overrideWithValue(_today),
      crashReporterProvider.overrideWithValue(FakeCrashReporter()),
    ],
  );
  addTearDown(() async {
    container.dispose();
    await database.close();
  });
  return _Harness(container, server, network);
}

Future<DiaryEditState> _open(_Harness h, DiaryEditTarget target) async {
  final subscription = h.container.listen(diaryEditProvider(target), (_, _) {});
  addTearDown(subscription.close);
  return await h.container.read(diaryEditProvider(target).future);
}

final _newToday = DiaryEditTarget.newOn(_today);
final _draftToday = DiaryDraftTarget.newOn(_today);

String? _questionText(DiaryEditState state) {
  final question = state.question;
  return question == null ? null : plainTextOf(question);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('질문 바꾸기(A115)', () {
    test('세 후보를 server 순서대로 돌고 끝에서 처음으로 돌아갑니다', () async {
      final h = await _harness();
      h.network.candidates = [
        _candidate('guide.harmony', '1', _first),
        _candidate('guide.harmony', '2', _second),
        _candidate('guide.gongmang', '1', _third),
      ];
      final opened = await _open(h, _newToday);
      expect(opened.candidates, hasLength(3));
      expect(opened.questionIndex, 0);
      expect(opened.canSwapQuestion, isTrue);
      expect(_questionText(opened), _first);

      final texts = <String?>[];
      for (var i = 0; i < 3; i++) {
        h.notifier(_newToday).swapQuestion();
        texts.add(_questionText(h.state(_newToday)));
      }
      expect(texts, [_second, _third, _first]);
      expect(h.state(_newToday).questionIndex, 0);
    });

    test('저장 요청의 guideQuestion은 고른 후보의 messageKey와 variant입니다', () async {
      final h = await _harness();
      await _open(h, _newToday);
      h.notifier(_newToday).swapQuestion();
      final saved = await h.notifier(_newToday).save('들은 말');
      expect(h.network.creates.single.body['guideQuestion'], {
        'messageKey': 'guide.harmony',
        'variant': '2',
      });
      // fake 서버도 고른 후보를 이 편의 질문으로 남깁니다.
      expect(plainTextOf(saved!.guideQuestion!), _second);
    });

    test('바꾸지 않아도 첫 후보를 보냅니다', () async {
      final h = await _harness();
      await _open(h, _newToday);
      await h.notifier(_newToday).save('글');
      expect(h.network.creates.single.body['guideQuestion'], {
        'messageKey': 'guide.harmony',
        'variant': '1',
      });
    });

    test('실패 뒤 같은 본문을 질문만 바꿔 다시 보내면 새 Idempotency-Key입니다', () async {
      final h = await _harness();
      await _open(h, _newToday);
      final notifier = h.notifier(_newToday);
      h.network.timeoutNextCreate = true;
      await expectLater(notifier.save('같은 글'), throwsA(isA<TimeoutError>()));
      notifier.swapQuestion();
      expect(await notifier.save('같은 글'), isNotNull);
      expect(h.network.creates, hasLength(2));
      expect(h.network.creates.last.key, isNot(h.network.creates.first.key));
    });

    test('실패 뒤 본문과 질문이 같으면 같은 Idempotency-Key입니다', () async {
      final h = await _harness();
      await _open(h, _newToday);
      final notifier = h.notifier(_newToday)..swapQuestion();
      h.network.timeoutNextCreate = true;
      await expectLater(notifier.save('같은 글'), throwsA(isA<TimeoutError>()));
      expect(await notifier.save('같은 글'), isNotNull);
      expect(h.network.creates.last.key, h.network.creates.first.key);
    });

    test('후보가 하나면 바꿀 수 없습니다', () async {
      final h = await _harness();
      h.network.candidates = [_candidate('guide.harmony', '1', _first)];
      final opened = await _open(h, _newToday);
      expect(opened.canSwapQuestion, isFalse);
      h.notifier(_newToday).swapQuestion();
      expect(h.state(_newToday).questionIndex, 0);
    });

    test('이미 저장한 일기를 고치면 바꿀 수 없고 저장된 질문입니다', () async {
      final h = await _harness();
      final id =
          (await h.container
                  .read(diaryRepositoryProvider)
                  .diariesOn(CalendarDate(2026, 10, 12)))
              .first
              .id;
      final target = DiaryEditTarget.existing(id);
      final opened = await _open(h, target);
      expect(opened.canSwapQuestion, isFalse);
      expect(opened.candidates, isEmpty);
      expect(opened.question, opened.existing!.guideQuestion);
    });

    test('후보를 받지 못하면(오프라인) 질문 없이 쓰고 guideQuestion을 보내지 않습니다', () async {
      final h = await _harness();
      h.network.offline = true;
      final opened = await _open(h, _newToday);
      expect(opened.candidates, isEmpty);
      expect(opened.question, isNull);
      expect(opened.offline, isTrue);
      h.network.offline = false;
      await h.notifier(_newToday).save('끊겼던 글');
      expect(
        h.network.creates.single.body.containsKey('guideQuestion'),
        isFalse,
      );
    });

    test('422 diary.guide_invalid면 오늘 풀이를 다시 읽어 후보를 바꾸고 초안을 남깁니다', () async {
      final h = await _harness();
      // 화면은 셋째 후보를 받았지만 server의 그날 후보에는 없습니다.
      h.network.candidates = [
        _candidate('guide.harmony', '1', _first),
        _candidate('guide.harmony', '2', _second),
        _candidate('guide.gongmang', '1', _third),
      ];
      await _open(h, _newToday);
      final notifier = h.notifier(_newToday)
        ..swapQuestion()
        ..swapQuestion();
      h.network.candidates = null;
      final dailyCalls = h.server.callCountOf('getDaily');
      await expectLater(
        notifier.save('지킬 글'),
        throwsA(
          isA<ProblemError>().having(
            (e) => e.code,
            'code',
            'diary.guide_invalid',
          ),
        ),
      );
      expect(h.server.callCountOf('getDaily'), dailyCalls + 1);
      final after = h.state(_newToday);
      expect(after.candidates, hasLength(4));
      expect(after.questionIndex, 0);
      expect(after.saving, isFalse);
      expect(
        await h.container.read(diaryDraftStoreProvider).read(_draftToday),
        '지킬 글',
      );
      // 새 후보로 다시 저장하면 됩니다.
      expect(await notifier.save('지킬 글'), isNotNull);
    });
  });

  group('고른 질문 초안(A115)', () {
    test('바꾼 질문은 본문 초안과 함께 남습니다', () async {
      final h = await _harness();
      await _open(h, _newToday);
      final notifier = h.notifier(_newToday)..edit('쓰는 중');
      await Future<void>.delayed(
        diaryDraftDelay + const Duration(milliseconds: 50),
      );
      notifier.swapQuestion();
      await Future<void>.delayed(
        diaryDraftDelay + const Duration(milliseconds: 50),
      );
      final draft = await h.container
          .read(diaryDraftStoreProvider)
          .find(_draftToday);
      expect(draft!.body, '쓰는 중');
      expect(draft.guideMessageKey, 'guide.harmony');
      expect(draft.guideVariant, '2');
    });

    test('다시 열면 초안의 질문이 후보에 있으면 그 질문입니다', () async {
      final h = await _harness();
      await h.container
          .read(diaryDraftStoreProvider)
          .write(
            _draftToday,
            '이어 쓸 글',
            guide: GuideChoice(messageKey: 'guide.harmony', variant: '2'),
          );
      final opened = await _open(h, _newToday);
      expect(opened.fromDraft, isTrue);
      expect(opened.questionIndex, 1);
      expect(_questionText(opened), _second);
    });

    test('초안의 질문이 후보에 없으면 첫 후보입니다', () async {
      final h = await _harness();
      await h.container
          .read(diaryDraftStoreProvider)
          .write(
            _draftToday,
            '이어 쓸 글',
            guide: GuideChoice(messageKey: 'guide.gone', variant: '1'),
          );
      final opened = await _open(h, _newToday);
      expect(opened.questionIndex, 0);
      expect(_questionText(opened), _first);
    });
  });

  group('질문 떼기와 다시 붙이기(D116)', () {
    test('떼면 detached, 바꾸기는 숨고 저장은 withoutGuideQuestion true만 보냅니다', () async {
      final h = await _harness();
      final opened = await _open(h, _newToday);
      expect(opened.canDetachQuestion, isTrue);
      expect(opened.guideDetached, isFalse);
      h.notifier(_newToday).detachQuestion();
      final detached = h.state(_newToday);
      expect(detached.guideDetached, isTrue);
      expect(detached.canSwapQuestion, isFalse);
      expect(detached.guideChoice, isNull);

      final saved = await h.notifier(_newToday).save('질문 없이 쓴 글');
      final body = h.network.creates.single.body;
      expect(body['withoutGuideQuestion'], isTrue);
      expect(body.containsKey('guideQuestion'), isFalse);
      // 대역 서버도 질문 없이 남깁니다(일기 보기와 목록에도 없음).
      expect(saved!.guideQuestion, isNull);
    });

    test('떼었다 붙이면 그날 기본 질문(첫 후보)이고 바꾸기 순서도 처음부터입니다', () async {
      final h = await _harness();
      h.network.candidates = [
        _candidate('guide.harmony', '1', _first),
        _candidate('guide.harmony', '2', _second),
        _candidate('guide.gongmang', '1', _third),
      ];
      await _open(h, _newToday);
      final notifier = h.notifier(_newToday)
        ..swapQuestion()
        ..swapQuestion();
      expect(_questionText(h.state(_newToday)), _third);
      notifier
        ..detachQuestion()
        ..attachQuestion();
      final attached = h.state(_newToday);
      expect(attached.guideDetached, isFalse);
      expect(attached.questionIndex, 0);
      expect(_questionText(attached), _first);
      notifier.swapQuestion();
      expect(_questionText(h.state(_newToday)), _second);
      await notifier.save('다시 붙인 글');
      final body = h.network.creates.single.body;
      expect(body['withoutGuideQuestion'], isFalse);
      expect(body['guideQuestion'], {
        'messageKey': 'guide.harmony',
        'variant': '2',
      });
    });

    test('실패 뒤 질문만 떼고 같은 본문을 다시 보내면 새 Idempotency-Key입니다', () async {
      final h = await _harness();
      await _open(h, _newToday);
      final notifier = h.notifier(_newToday);
      h.network.timeoutNextCreate = true;
      await expectLater(notifier.save('같은 글'), throwsA(isA<TimeoutError>()));
      notifier.detachQuestion();
      expect(await notifier.save('같은 글'), isNotNull);
      expect(h.network.creates.last.key, isNot(h.network.creates.first.key));
    });

    test('실패 뒤 뗀 채 같은 본문을 다시 보내면 같은 Idempotency-Key입니다', () async {
      final h = await _harness();
      await _open(h, _newToday);
      final notifier = h.notifier(_newToday)..detachQuestion();
      h.network.timeoutNextCreate = true;
      await expectLater(notifier.save('같은 글'), throwsA(isA<TimeoutError>()));
      expect(await notifier.save('같은 글'), isNotNull);
      expect(h.network.creates.last.key, h.network.creates.first.key);
    });

    test('뗀 상태는 초안에 남고 이어 쓰기는 뗀 채로 시작합니다', () async {
      final h = await _harness();
      await _open(h, _newToday);
      h.notifier(_newToday)
        ..edit('쓰는 중')
        ..detachQuestion();
      await Future<void>.delayed(
        diaryDraftDelay + const Duration(milliseconds: 50),
      );
      final draft = await h.container
          .read(diaryDraftStoreProvider)
          .find(_draftToday);
      expect(draft!.body, '쓰는 중');
      expect(draft.guideDetached, isTrue);
      expect(draft.guideMessageKey, isNull);

      h.container.invalidate(diaryEditProvider(_newToday));
      final reopened = await _open(h, _newToday);
      expect(reopened.fromDraft, isTrue);
      expect(reopened.guideDetached, isTrue);
      expect(reopened.canDetachQuestion, isTrue);
    });

    test('다시 붙이면 초안의 뗀 표시도 풀립니다', () async {
      final h = await _harness();
      await h.container
          .read(diaryDraftStoreProvider)
          .write(_draftToday, '이어 쓸 글', detached: true);
      await _open(h, _newToday);
      h.notifier(_newToday).attachQuestion();
      await Future<void>.delayed(
        diaryDraftDelay + const Duration(milliseconds: 50),
      );
      final draft = await h.container
          .read(diaryDraftStoreProvider)
          .find(_draftToday);
      expect(draft!.guideDetached, isFalse);
      expect(draft.guideMessageKey, 'guide.harmony');
      expect(draft.guideVariant, '1');
    });

    test('고치기와 후보를 받지 못한 새 일기는 뗄 수 없습니다', () async {
      final h = await _harness();
      final id =
          (await h.container
                  .read(diaryRepositoryProvider)
                  .diariesOn(CalendarDate(2026, 10, 12)))
              .first
              .id;
      final existing = DiaryEditTarget.existing(id);
      expect((await _open(h, existing)).canDetachQuestion, isFalse);
      h.notifier(existing).detachQuestion();
      expect(h.state(existing).guideDetached, isFalse);

      h.network.dailyOffline = true;
      final offline = await _open(h, _newToday);
      expect(offline.candidates, isEmpty);
      expect(offline.canDetachQuestion, isFalse);
    });

    test('후보를 받지 못해도 뗀 채 남은 초안은 뗀 대로 보냅니다', () async {
      final h = await _harness();
      await h.container
          .read(diaryDraftStoreProvider)
          .write(_draftToday, '뗀 채 쓴 글', detached: true);
      h.network.dailyOffline = true;
      final opened = await _open(h, _newToday);
      expect(opened.guideDetached, isTrue);
      await h.notifier(_newToday).save('뗀 채 쓴 글');
      final body = h.network.creates.single.body;
      expect(body['withoutGuideQuestion'], isTrue);
      expect(body.containsKey('guideQuestion'), isFalse);
    });
  });

  group('날짜 블록 일진', () {
    Future<String> writtenId(_Harness h) async =>
        (await h.container
                .read(diaryRepositoryProvider)
                .diariesOn(CalendarDate(2026, 10, 12)))
            .first
            .id;

    test('새 일기는 열 때 그날 일진(dayPillar)을 받습니다', () async {
      final h = await _harness();
      final opened = await _open(h, _newToday);
      expect(opened.dayPillar, isNotNull);
      expect(opened.dayPillarPending, isFalse);
    });

    test('고치기는 일진을 기다리지 않고 열고, 받으면 채웁니다', () async {
      final h = await _harness();
      final target = DiaryEditTarget.existing(await writtenId(h));
      final hold = h.network.holdDaily = Completer<void>();
      final opened = await _open(h, target);
      expect(opened.dayPillar, isNull);
      expect(opened.dayPillarPending, isTrue);
      hold.complete();
      await pumpEventQueue();
      for (var i = 0; i < 50 && h.state(target).dayPillarPending; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(h.state(target).dayPillar, isNotNull);
      expect(h.state(target).dayPillarPending, isFalse);
    });

    test('고치기에서 일진 읽기가 5xx로 실패해도 예외 없이 열리고 일진 줄만 없습니다', () async {
      final h = await _harness();
      final target = DiaryEditTarget.existing(await writtenId(h));
      h.network.dailyUnavailable = true;
      final opened = await _open(h, target);
      expect(opened.initialBody, startsWith('오랜만에'));
      for (var i = 0; i < 50 && h.state(target).dayPillarPending; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(h.state(target).dayPillar, isNull);
      expect(h.state(target).dayPillarPending, isFalse);
    });

    test('일진이 build보다 먼저 끝나도 pending이 풀리고 일진이 채워집니다', () async {
      final h = await _harness();
      final target = DiaryEditTarget.existing(await writtenId(h));
      final fixture = jsonDecode(
        await rootBundle.loadString('fixtures/member/getDaily.json'),
      ) as Map<String, Object?>;
      h.network.dailyImmediate = fixture['body']! as Map<String, Object?>;
      await _open(h, target);
      for (var i = 0; i < 50 && h.state(target).dayPillarPending; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(h.state(target).dayPillarPending, isFalse);
      expect(h.state(target).dayPillar, isNotNull);
    });

    test('고치기에서 일진을 받지 못해도(오프라인) 열리고 일진만 없습니다', () async {
      final h = await _harness();
      final target = DiaryEditTarget.existing(await writtenId(h));
      h.network.dailyOffline = true;
      final opened = await _open(h, target);
      expect(opened.initialBody, startsWith('오랜만에'));
      for (var i = 0; i < 50 && h.state(target).dayPillarPending; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(h.state(target).dayPillar, isNull);
      expect(h.state(target).dayPillarPending, isFalse);
      expect(h.state(target).offline, isFalse);
    });
  });

  test('422 guide_invalid 뒤 오늘 풀이를 다시 읽지 못하면 받아 둔 후보와 고른 질문을 지킵니다', () async {
    final h = await _harness();
    h.network.candidates = [
      _candidate('guide.harmony', '1', _first),
      _candidate('guide.harmony', '2', _second),
      _candidate('guide.gongmang', '1', _third),
    ];
    await _open(h, _newToday);
    final notifier = h.notifier(_newToday)
      ..swapQuestion()
      ..swapQuestion();
    h.network.dailyOffline = true;
    await expectLater(notifier.save('지킬 글'), throwsA(isA<ProblemError>()));
    final after = h.state(_newToday);
    expect(after.candidates, hasLength(3));
    expect(after.questionIndex, 2);
    final draft = await h.container
        .read(diaryDraftStoreProvider)
        .find(_draftToday);
    expect(draft!.body, '지킬 글');
    expect(draft.guideMessageKey, 'guide.gongmang');
  });
}
