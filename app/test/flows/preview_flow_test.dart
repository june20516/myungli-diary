import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/api/fake/fake_server.dart';
import 'package:myungli_diary/core/api/fake/scenario.dart';
import 'package:myungli_diary/core/api/gen/model/preview.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations_ko.dart';
import 'package:myungli_diary/design/components/action/primary_button.dart';
import 'package:myungli_diary/design/components/feedback/error_state.dart';
import 'package:myungli_diary/design/components/feedback/notice_banner.dart';
import 'package:myungli_diary/design/components/sentence/term_token.dart';
import 'package:myungli_diary/design/components/today/day_character.dart';
import 'package:myungli_diary/features/onboarding/application/preview_providers.dart';
import 'package:myungli_diary/features/onboarding/data/onboarding_draft_store.dart';
import 'package:myungli_diary/testing/covers.dart';

import '../support/onboarding_steps.dart';

final _ko = AppLocalizationsKo();

FakeServerInterceptor _fake(ProviderContainer container) =>
    container.read(fakeServerInterceptorProvider)! as FakeServerInterceptor;

Finder _slot(String id) => find.byKey(ValueKey(id));

/// 화면 안의 모든 글자를 이어 붙입니다(조각이 나뉘어 있어도 한 문장으로 확인).
String _allText(WidgetTester tester, Finder scope) => tester
    .widgetList<RichText>(
      find.descendant(of: scope, matching: find.byType(RichText)),
    )
    .map((w) => w.text.toPlainText())
    .join();

void main() {
  testWidgets('new-user: skeleton 뒤 용신의 날 배지와 총운 문장, 저장하고 계속하기 → login', (
    tester,
  ) async {
    covers(
      const Covers(
        exits: ['preview>login'],
        states: ['preview:loading'],
        decisions: ['D50'],
      ),
    );
    final container = await openPreviewStep(tester, settle: false);
    // 응답을 받기 전: 자리를 지키는 skeleton 영역(screen-state.loading)입니다.
    expect(find.byKey(const ValueKey('screen-state.loading')), findsOneWidget);

    await settlePreview(tester);
    expect(find.byKey(const ValueKey('screen-state.loading')), findsNothing);
    expect(find.text(_ko.dayKindYongsinDay), findsOneWidget);
    expect(
      tester.widget<DayCharacter>(find.byType(DayCharacter)).variant,
      DayCharacterVariant.good,
    );
    expect(_slot(SlotIds.previewFortuneHead), findsOneWidget);
    expect(
      _allText(tester, _slot(SlotIds.previewFortuneHead)),
      '별님, 오늘은 정관의 기운이 힘이 되는 날이에요.',
    );
    // preview는 용어 조각도 칩이 아니라 일반 글자입니다(V28).
    expect(find.byType(TermToken), findsNothing);
    expect(_slot(SlotIds.previewFortuneBody), findsOneWidget);
    expect(find.text('차분히 정리하기 좋은 날이에요.'), findsOneWidget);

    // 비로그인: App Check 헤더는 있고 Authorization은 없습니다. 본문은 한국 기기 기본값.
    final fake = _fake(container);
    expect(fake.callCountOf('createPreview'), 1);
    final headers = fake.requestHeadersOf('createPreview').single;
    expect(headers.containsKey('x-firebase-appcheck'), isTrue);
    expect(headers.containsKey('authorization'), isFalse);
    final body =
        (fake.requestBodiesOf('createPreview').single is String
                ? jsonDecode(
                    fake.requestBodiesOf('createPreview').single! as String,
                  )
                : fake.requestBodiesOf('createPreview').single)!
            as Map<String, Object?>;
    expect((body['installationId']! as String).isNotEmpty, isTrue);
    expect(body['currentTimezone'], 'Asia/Seoul');
    final birth = body['birth']! as Map<String, Object?>;
    expect(birth['gender'], 'female');
    expect(birth['timezone'], 'Asia/Seoul');

    await tester.tap(_slot(SlotIds.previewCtaSave));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey(ScreenIds.login)), findsOneWidget);
  });

  testWidgets('공유 버튼 → 로그인 안내 창 → 로그인이면 login, 닫기면 preview에 남습니다', (
    tester,
  ) async {
    covers(const Covers(exits: ['preview>login']));
    await openPreviewStep(tester);

    await tester.tap(find.text(_ko.shareLabel));
    await tester.pumpAndSettle();
    expect(_slot(SlotIds.previewShareLoginNotice), findsOneWidget);
    await tester.tap(find.text(_ko.previewShareLoginNoticeCancel));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey(ScreenIds.preview)), findsOneWidget);
    expect(_slot(SlotIds.previewShareLoginNotice), findsNothing);

    await tester.tap(find.text(_ko.shareLabel));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_ko.previewShareLoginNoticeConfirm));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey(ScreenIds.login)), findsOneWidget);
  });

  testWidgets('다시 입력 → onboard-call, 호칭이 채워져 있고 같은 입력이면 미리보기를 다시 쓰지 않습니다', (
    tester,
  ) async {
    covers(const Covers(exits: ['preview>onboard-call']));
    final container = await openPreviewStep(tester);

    await tester.tap(_slot(SlotIds.previewCtaRestart));
    await tester.pumpAndSettle();
    await settleIo(tester);
    expect(find.byKey(const ValueKey(ScreenIds.onboardCall)), findsOneWidget);
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).controller.text,
      '별님',
    );
    final draft = await tester.runAsync(
      () => container.read(onboardingDraftStoreProvider).read(),
    );
    expect(draft!.honorific, '별님');

    // 입력을 바꾸지 않고 다시 미리보기까지 오면, 설치당 1회인 요청을 다시 쓰지 않고 받아 둔 풀이를 보입니다.
    await tapNext(tester); // 호칭 → 생일
    await tapNext(tester); // 생일 → 시간
    await tapNext(tester); // 시간 → 성별
    await tapNext(tester); // 성별 → preview
    await settlePreview(tester);
    expect(find.text(_ko.dayKindYongsinDay), findsOneWidget);
    expect(_fake(container).callCountOf('createPreview'), 1);
  });

  testWidgets('time-unknown: 시간 모름 배너', (tester) async {
    covers(const Covers(states: ['preview:time-unknown']));
    await openPreviewStep(tester, scenario: 'time-unknown');
    final banner = tester.widget<NoticeBanner>(
      find.byKey(const ValueKey('preview.time-unknown')),
    );
    expect(banner.variant, NoticeBannerVariant.timeUnknown);
    expect(banner.message, '태어난 시간을 몰라 세 기둥으로 계산했어요.');
    expect(find.text(_ko.dayKindYongsinDay), findsOneWidget);
  });

  testWidgets('time_unknown notice의 문장이 비어 있으면 app 문구로 배너를 그립니다', (
    tester,
  ) async {
    final json = jsonDecode(
      File('fixtures/time-unknown/createPreview.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final body = json['body']! as Map<String, dynamic>;
    body['notices'] = [
      {
        'code': 'time_unknown',
        'text': {'segments': <Object>[]},
      },
    ];
    await openPreviewStep(
      tester,
      overrides: [
        previewProvider.overrideWith((ref) async => Preview.fromJson(body)),
      ],
    );
    final banner = tester.widget<NoticeBanner>(
      find.byKey(const ValueKey('preview.time-unknown')),
    );
    expect(banner.message, _ko.noticeTimeUnknown);
  });

  testWidgets('new-user는 time-unknown 배너가 없습니다', (tester) async {
    await openPreviewStep(tester);
    expect(find.byKey(const ValueKey('preview.time-unknown')), findsNothing);
  });

  testWidgets('오프라인: 오프라인 오류 상태와 다시 시도, 연결이 돌아오면 풀이를 보입니다', (tester) async {
    covers(const Covers(states: ['preview:offline']));
    final container = await openTimeStep(tester);
    // 입력을 마치는 동안은 온라인이고, 미리보기를 열기 직전에 연결이 끊깁니다.
    final dio = container.read(dioProvider);
    final online = dio.interceptors.whereType<FakeServerInterceptor>().single;
    final offline = FakeServerInterceptor(
      scenario: Scenario(
        id: 'new-user',
        today: online.scenario.today,
        timezone: online.scenario.timezone,
        offline: true,
      ),
      bundle: rootBundle,
    );
    final index = dio.interceptors.indexOf(online);
    dio.interceptors[index] = offline;
    addTearDown(() => dio.interceptors[index] = online);

    await tapNext(tester);
    await tester.tap(find.text(_ko.genderFemale));
    await tester.pumpAndSettle();
    await tapNext(tester);
    await settlePreview(tester);
    final errorState = tester.widget<ErrorState>(find.byType(ErrorState));
    expect(errorState.variant, ErrorStateVariant.offline);
    expect(find.text(_ko.actionRetry), findsOneWidget);
    // 오프라인이어도 저장하고 계속하기는 막지 않습니다.
    expect(
      tester.widget<PrimaryButton>(_slot(SlotIds.previewCtaSave)).onPressed,
      isNotNull,
    );

    dio.interceptors[index] = online;
    await tester.tap(find.text(_ko.actionRetry));
    await settlePreview(tester);
    expect(find.text(_ko.dayKindYongsinDay), findsOneWidget);
    expect(find.byType(ErrorState), findsNothing);
  });

  testWidgets('preview-invalid: birth.invalid 문구와 다시 입력, 입력은 그대로입니다', (
    tester,
  ) async {
    covers(const Covers(states: ['preview:error']));
    final container = await openPreviewStep(
      tester,
      scenario: 'preview-invalid',
    );
    final errorState = tester.widget<ErrorState>(find.byType(ErrorState));
    expect(errorState.variant, ErrorStateVariant.generic);
    expect(find.text(AppLocalizationsKo().errorBirthInvalid), findsOneWidget);
    // 같은 입력으로는 같은 오류라 다시 시도는 없고 다시 입력만 있습니다.
    expect(find.text(_ko.actionRetry), findsNothing);
    expect(find.byType(DayCharacter), findsNothing);

    await tester.tap(_slot(SlotIds.previewCtaRestart));
    await tester.pumpAndSettle();
    await settleIo(tester);
    expect(find.byKey(const ValueKey(ScreenIds.onboardCall)), findsOneWidget);
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).controller.text,
      '별님',
    );
    final draft = await tester.runAsync(
      () => container.read(onboardingDraftStoreProvider).read(),
    );
    expect(draft!.date, isNotNull);
    expect(draft.gender, isNotNull);
  });

  testWidgets('preview-used: 오류 문구를 보이되 저장하고 계속하기로 login에 갈 수 있습니다', (
    tester,
  ) async {
    final container = await openPreviewStep(tester, scenario: 'preview-used');
    expect(find.byType(ErrorState), findsOneWidget);
    expect(find.text(_ko.errorPreviewUsed), findsOneWidget);
    expect(find.text(_ko.actionRetry), findsNothing);
    expect(_fake(container).callCountOf('createPreview'), 1);

    await tester.tap(_slot(SlotIds.previewCtaSave));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey(ScreenIds.login)), findsOneWidget);
  });

  testWidgets('다시 입력 뒤 뒤로 가면 welcome이 남아 있습니다(앱이 닫히지 않음)', (tester) async {
    await openPreviewStep(tester);
    await tester.tap(_slot(SlotIds.previewCtaRestart));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey(ScreenIds.onboardCall)), findsOneWidget);

    final handled = await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(handled, isTrue);
    expect(find.byKey(const ValueKey(ScreenIds.welcome)), findsOneWidget);
  });
}
