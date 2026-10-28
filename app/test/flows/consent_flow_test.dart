import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/app/entry/entry_providers.dart';
import 'package:myungli_diary/app/router/app_router.dart';
import 'package:myungli_diary/core/api/fake/fake_server.dart';
import 'package:myungli_diary/core/api/gen/model/birth.dart';
import 'package:myungli_diary/core/api/gen/model/birth_time.dart';
import 'package:myungli_diary/core/api/gen/model/calendar_type.dart';
import 'package:myungli_diary/core/api/gen/model/consent_document.dart';
import 'package:myungli_diary/core/api/gen/model/lunar_or_solar_date.dart';
import 'package:myungli_diary/core/api/gen/model/me.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations_ko.dart';
import 'package:myungli_diary/core/storage/app_database.dart';
import 'package:myungli_diary/core/storage/device_flags.dart';
import 'package:myungli_diary/design/components/action/primary_button.dart';
import 'package:myungli_diary/design/components/action/social_login_button.dart';
import 'package:myungli_diary/design/components/input/check_row.dart';
import 'package:myungli_diary/features/auth/presentation/consent_screen.dart';
import 'package:myungli_diary/features/onboarding/application/onboarding_providers.dart';
import 'package:myungli_diary/features/onboarding/data/onboarding_draft_store.dart';
import 'package:myungli_diary/features/onboarding/model/onboarding_draft.dart';
import 'package:myungli_diary/testing/covers.dart';

import '../support/app_bar_title.dart';
import '../support/app_harness.dart';
import '../support/onboarding_steps.dart';

final _ko = AppLocalizationsKo();

FakeServerInterceptor _fake(ProviderContainer container) =>
    container.read(fakeServerInterceptorProvider)! as FakeServerInterceptor;

Finder _screen(String id) => find.byKey(ValueKey(id));

Map<String, Object?> _bodyOf(Object? data) =>
    (data is String ? jsonDecode(data) : data)! as Map<String, Object?>;

final Finder _kakaoButton = find.byWidgetPredicate(
  (w) => w is SocialLoginButton && w.provider == SocialProvider.kakao,
);

Finder _row(ConsentDocumentDocumentEnum document) => find.descendant(
  of: find.byKey(consentDocumentKey(document)),
  matching: find.byType(CheckRow),
);

bool _checked(WidgetTester tester, ConsentDocumentDocumentEnum document) =>
    tester.widget<CheckRow>(_row(document)).checked;

Finder get _agreeButton => find.descendant(
  of: _screen(ScreenIds.consent),
  matching: find.byType(PrimaryButton),
);

bool _agreeEnabled(WidgetTester tester) =>
    tester.widget<PrimaryButton>(_agreeButton).onPressed != null;

Future<void> _check(
  WidgetTester tester,
  ConsentDocumentDocumentEnum document,
) async {
  await tester.tap(
    find.descendant(
      of: _row(document),
      matching: find.text(
        document == ConsentDocumentDocumentEnum.terms
            ? _ko.consentRequiredLabelTerms
            : _ko.consentRequiredLabelPrivacy,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _checkAll(WidgetTester tester) async {
  await _check(tester, ConsentDocumentDocumentEnum.terms);
  await _check(tester, ConsentDocumentDocumentEnum.privacy);
}

/// login 화면에서 카카오로 로그인해 consent에 닿을 때까지 기다립니다.
Future<void> _signInToConsent(WidgetTester tester) async {
  expect(_screen(ScreenIds.login), findsOneWidget);
  await tester.tap(_kakaoButton);
  await pumpUntilScreen(tester, ScreenIds.consent);
}

/// 동의를 누르고 [screenId]에 닿을 때까지 기다립니다.
Future<void> _agreeUntil(WidgetTester tester, String screenId) async {
  await tester.tap(_agreeButton);
  await pumpUntilScreen(tester, screenId);
}

final _completeDraft = OnboardingDraft(
  honorific: '별님',
  calendar: CalendarType.solar,
  date: LunarOrSolarDate(year: 1990, month: 5, day: 15),
  time: BirthTime(status: BirthTimeStatusEnum.known, value: '14:30'),
  gender: BirthGenderEnum.female,
);

/// 처음 읽을 때 완전한 입력을 저장해 두는 저장소(앱이 꺼지기 전에 저장한 입력).
class _SeededDraftStore extends OnboardingDraftStore {
  new(super._database, this._seed);

  OnboardingDraft? _seed;

  @override
  Future<OnboardingDraft?> read() async {
    final seed = _seed;
    if (seed != null) {
      _seed = null;
      await write(seed);
    }
    return await super.read();
  }
}

/// `getMe`만 [requiredDocuments]를 필수 동의로 답하고 나머지는 대역 서버에 넘깁니다.
///
/// 대역 fixture는 계약 스키마로 검증되어 계약 밖 문서 값을 둘 수 없으므로 여기서 만듭니다.
final class _RequiredDocumentsMe extends Interceptor {
  new(this.requiredDocuments);

  /// 필수 동의 문서 값(계약 밖 값 포함).
  final List<String> requiredDocuments;

  /// `getMe`에 답한 횟수.
  int answered = 0;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.method != 'GET' || options.path != '/v1/me') {
      handler.next(options);
      return;
    }
    answered++;
    handler.resolve(
      Response<Object?>(
        requestOptions: options,
        statusCode: 200,
        data: {
          'accountId': '0b3f6a9e-6c1d-4f43-9a52-3c1e7d2b8a10',
          'status': 'active',
          'consentRequired': true,
          'requiredConsents': [
            for (final document in requiredDocuments)
              {'document': document, 'version': '2026-10-01'},
          ],
          'hasProfile': true,
          'adFree': {'active': false},
          'insight': {'active': false},
        },
      ),
    );
  }
}

void main() {
  testWidgets('new-user: 미리보기 뒤 동의하면 프로필을 저장하고 notify-ask', (tester) async {
    covers(const Covers(exits: ['consent>notify-ask'], decisions: ['D50']));
    final container = await openPreviewStep(tester);
    await tester.tap(_screen(SlotIds.previewCtaSave));
    await tester.pumpAndSettle();
    await _signInToConsent(tester);

    expect(_screen(SlotIds.consentTitleHead), findsOneWidget);
    // 갈래의 첫 화면이라 돌아갈 곳이 없어 뒤로 버튼을 두지 않습니다.
    expect(find.byKey(const ValueKey('app-bar.back')), findsNothing);
    expect(find.byType(CheckRow), findsNWidgets(2));
    expect(find.text(_ko.consentRequiredLabelTerms), findsOneWidget);
    expect(find.text(_ko.consentRequiredLabelPrivacy), findsOneWidget);
    expect(_agreeEnabled(tester), isFalse);
    await _check(tester, ConsentDocumentDocumentEnum.terms);
    expect(_agreeEnabled(tester), isFalse);
    await _check(tester, ConsentDocumentDocumentEnum.privacy);
    expect(_agreeEnabled(tester), isTrue);

    await _agreeUntil(tester, ScreenIds.notifyAsk);

    final fake = _fake(container);
    expect(_bodyOf(fake.requestBodiesOf('agreeConsents').single), {
      'documents': [
        {'document': 'terms', 'version': '2026-10-01'},
        {'document': 'privacy', 'version': '2026-10-01'},
      ],
    });
    expect(fake.callCountOf('createProfile'), 1);
    expect(
      container.read(onboardingDraftProvider).value,
      const OnboardingDraft(),
    );
    expect(
      await tester.runAsync(
        () => container
            .read(deviceFlagsStoreProvider)
            .readBool(notifyAskPendingKey),
      ),
      isTrue,
    );
  });

  testWidgets(
    'new-user-signin: 동의 → onboard-call → 입력을 마치면 미리보기 없이 notify-ask',
    (tester) async {
      covers(const Covers(exits: ['consent>onboard-call']));
      final container = await pumpApp(
        tester,
        scenario: 'new-user-signin',
        locale: koreaLocale,
      );
      await tester.tap(_screen(SlotIds.welcomeCtaSignin));
      await tester.pumpAndSettle();
      await _signInToConsent(tester);
      await _checkAll(tester);

      await _agreeUntil(tester, ScreenIds.onboardCall);
      final fake = _fake(container);
      expect(fake.callCountOf('agreeConsents'), 1);
      expect(fake.callCountOf('createProfile'), 0);

      await tester.enterText(find.byType(EditableText), '별님');
      await tester.pump();
      await tapNext(tester); // 호칭 → 생일
      await tapNext(tester); // 생일 → 시간
      await tapNext(tester); // 시간 → 성별
      await tester.tap(find.text(_ko.genderFemale));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(PrimaryButton));
      await pumpUntilScreen(tester, ScreenIds.notifyAsk);

      expect(fake.callCountOf('createPreview'), 0);
      expect(fake.callCountOf('createProfile'), 1);
      expect(
        _bodyOf(fake.requestBodiesOf('createProfile').single)['honorific'],
        '별님',
      );
    },
  );

  testWidgets('consent-renewal: 약관 개정 동의 뒤 프로필 저장 없이 today로 갑니다', (
    tester,
  ) async {
    covers(const Covers(decisions: ['D50']));
    final container = await pumpApp(tester, scenario: 'consent-renewal');
    expect(_screen(ScreenIds.consent), findsOneWidget);
    await expectAppBarTitle(
      tester,
      SlotIds.consentBarTitle,
      _ko.consentBarTitle,
    );
    await _checkAll(tester);

    await _agreeUntil(tester, ScreenIds.today);

    final fake = _fake(container);
    expect(fake.callCountOf('agreeConsents'), 1);
    expect(fake.callCountOf('createProfile'), 0);
    expect(_screen(ScreenIds.consent), findsNothing);
  });

  testWidgets(
    'consent-renewal: 완전한 온보딩 입력이 남은 회원이 동의해도 프로필을 덮어쓰지 않고 입력을 지웁니다',
    (tester) async {
      final container = await pumpApp(
        tester,
        scenario: 'consent-renewal',
        locale: koreaLocale,
        overrides: [
          onboardingDraftStoreProvider.overrideWith(
            (ref) => _SeededDraftStore(
              ref.watch(appDatabaseProvider),
              _completeDraft,
            ),
          ),
        ],
      );
      expect(_screen(ScreenIds.consent), findsOneWidget);
      // 남은 입력이 있는 상태(로그인 직후 삭제가 실패한 경우 등)입니다.
      expect(
        await tester.runAsync(
          () => container.read(onboardingDraftProvider.future),
        ),
        _completeDraft,
      );
      await _checkAll(tester);

      await _agreeUntil(tester, ScreenIds.today);

      final fake = _fake(container);
      expect(fake.callCountOf('createProfile'), 0);
      expect(
        await tester.runAsync(
          () => container
              .read(deviceFlagsStoreProvider)
              .readBool(notifyAskPendingKey),
        ),
        isFalse,
      );
      // 프로필 있는 갈래로 진입하면 남은 입력을 지웁니다.
      await pumpUntil(
        tester,
        () =>
            container.read(onboardingDraftProvider).value ==
            const OnboardingDraft(),
      );
      expect(
        await tester.runAsync(
          () => container.read(onboardingDraftStoreProvider).read(),
        ),
        isNull,
      );
    },
  );

  testWidgets("'보기'는 legal을 열고, 돌아오면 체크가 그대로입니다", (tester) async {
    covers(const Covers(exits: ['consent>legal']));
    final container = await pumpApp(tester, scenario: 'consent-required');
    expect(_screen(ScreenIds.consent), findsOneWidget);
    await _check(tester, ConsentDocumentDocumentEnum.terms);

    await tester.tap(
      find.descendant(
        of: find.byKey(consentDocumentKey(ConsentDocumentDocumentEnum.privacy)),
        matching: find.text(_ko.consentView),
      ),
    );
    await tester.pumpAndSettle();
    expect(_screen(ScreenIds.legal), findsOneWidget);
    // '보기'를 눌러도 체크는 바뀌지 않습니다.
    container.read(routerProvider).pop();
    await tester.pumpAndSettle();

    expect(_screen(ScreenIds.consent), findsOneWidget);
    expect(_checked(tester, ConsentDocumentDocumentEnum.terms), isTrue);
    expect(_checked(tester, ConsentDocumentDocumentEnum.privacy), isFalse);
  });

  testWidgets('동의 줄의 Semantics identifier는 문서별로 다릅니다', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpApp(tester, scenario: 'consent-required');
    expect(
      find.bySemanticsIdentifier('consent.required.label.terms'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsIdentifier('consent.required.label.privacy'),
      findsOneWidget,
    );
    handle.dispose();
  });

  for (final documents in [
    ['terms', 'added_after_freeze', 'privacy'],
    ['added_after_freeze'],
  ]) {
    testWidgets('모르는 필수 문서 $documents가 있으면 동의 대신 force-update(A66)', (
      tester,
    ) async {
      final me = _RequiredDocumentsMe(documents);
      final container = await pumpApp(
        tester,
        scenario: 'consent-required',
        network: me,
      );
      expect(me.answered, greaterThan(0));
      expect(_screen(ScreenIds.forceUpdate), findsOneWidget);
      // 이유 문장은 약관 사유 키입니다(W45).
      expect(find.text(_ko.forceUpdateNoticeBodyConsent), findsOneWidget);
      expect(find.text(_ko.forceUpdateNoticeBody), findsNothing);
      expect(_screen(ScreenIds.consent), findsNothing);
      expect(_fake(container).callCountOf('agreeConsents'), 0);
    });
  }

  testWidgets('모르는 문서(열린 enum)는 줄을 그리지 않고 동의에도 보내지 않습니다', (tester) async {
    // 계약 ConsentDocument.document는 열린 enum입니다(A66). 진입 계산이 모르는 필수 문서를
    // force-update로 보내지만, 화면도 모르는 문서는 그리지도 보내지도 않습니다(안전망).
    final me = Me.fromJson({
      'accountId': '0b3f6a9e-6c1d-4f43-9a52-3c1e7d2b8a10',
      'status': 'active',
      'consentRequired': true,
      'requiredConsents': [
        {'document': 'terms', 'version': '2026-10-01'},
        {'document': 'added_after_freeze', 'version': '2026-10-01'},
        {'document': 'privacy', 'version': '2026-10-01'},
      ],
      'hasProfile': true,
      'adFree': {'active': false},
      'insight': {'active': false},
    });
    final container = await pumpApp(
      tester,
      scenario: 'consent-required',
      overrides: [meProvider.overrideWithValue(me)],
    );
    expect(find.byType(CheckRow), findsNWidgets(2));
    expect(
      find.byKey(
        consentDocumentKey(ConsentDocumentDocumentEnum.unknownDefaultOpenApi),
      ),
      findsNothing,
    );

    await _checkAll(tester);
    expect(_agreeEnabled(tester), isTrue);
    await tester.tap(_agreeButton);
    await pumpUntil(
      tester,
      () => _fake(container).callCountOf('agreeConsents') == 1,
    );

    final body = _bodyOf(
      _fake(container).requestBodiesOf('agreeConsents').single,
    );
    expect(body['documents'], [
      {'document': 'terms', 'version': '2026-10-01'},
      {'document': 'privacy', 'version': '2026-10-01'},
    ]);
  });

  testWidgets('동의 버튼을 빠르게 두 번 눌러도 agreeConsents는 한 번입니다', (tester) async {
    final container = await pumpApp(tester, scenario: 'consent-required');
    await _checkAll(tester);

    await tester.tap(_agreeButton);
    await tester.pump();
    await tester.tap(_agreeButton, warnIfMissed: false);
    await tester.pump();
    await pumpUntil(
      tester,
      () => find.byKey(PrimaryButton.dotsKey).evaluate().isEmpty,
    );

    expect(_fake(container).callCountOf('agreeConsents'), 1);
  });

  testWidgets('consent-mismatch: 내 정보를 다시 받아 체크를 풀고 오류 문구를 보입니다', (
    tester,
  ) async {
    covers(const Covers(states: ['consent:error']));
    final container = await pumpApp(tester, scenario: 'consent-mismatch');
    final fake = _fake(container);
    expect(fake.callCountOf('getMe'), 1);
    await _checkAll(tester);

    await tester.tap(_agreeButton);
    await pumpUntil(
      tester,
      () => find.byKey(consentErrorKey).evaluate().isNotEmpty,
    );

    expect(_screen(ScreenIds.consent), findsOneWidget);
    expect(fake.callCountOf('getMe'), 2);
    expect(find.text(_ko.errorConsentVersionMismatch), findsOneWidget);
    expect(_checked(tester, ConsentDocumentDocumentEnum.terms), isFalse);
    expect(_checked(tester, ConsentDocumentDocumentEnum.privacy), isFalse);
    expect(_agreeEnabled(tester), isFalse);

    // 다시 동의하면 새로 받은 버전을 보냅니다.
    await _checkAll(tester);
    await tester.tap(_agreeButton);
    await pumpUntil(
      tester,
      () => find.byKey(PrimaryButton.dotsKey).evaluate().isEmpty,
    );
    final second = _bodyOf(fake.requestBodiesOf('agreeConsents').last);
    expect(second['documents'], [
      {'document': 'terms', 'version': '2026-10-10'},
      {'document': 'privacy', 'version': '2026-10-01'},
    ]);
  });

  testWidgets(
    'profile-invalid: 프로필 저장이 422면 onboard-call에서 오류 toast, 입력은 남습니다',
    (tester) async {
      final container = await openPreviewStep(
        tester,
        scenario: 'profile-invalid',
      );
      await tester.tap(_screen(SlotIds.previewCtaSave));
      await tester.pumpAndSettle();
      await _signInToConsent(tester);
      await _checkAll(tester);

      await _agreeUntil(tester, ScreenIds.onboardCall);

      expect(find.text(_ko.errorBirthInvalid), findsOneWidget);
      // 같은 입력으로 다시 저장하지 않고 고칠 수 있게 입력을 보여 줍니다.
      expect(_fake(container).callCountOf('createProfile'), 1);
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).controller.text,
        '별님',
      );
      final draft = container.read(onboardingDraftProvider).value!;
      expect(draft.honorific, '별님');
      expect(draft.gender, BirthGenderEnum.female);
      await tester.pump(const Duration(seconds: 10));
    },
  );

  testWidgets('앱 재시작: 동의 뒤 프로필 저장 전에 꺼졌으면 같은 질문 없이 notify-ask', (tester) async {
    final container = await pumpApp(
      tester,
      scenario: 'profile-required',
      locale: koreaLocale,
      overrides: [
        onboardingDraftStoreProvider.overrideWith(
          (ref) =>
              _SeededDraftStore(ref.watch(appDatabaseProvider), _completeDraft),
        ),
      ],
    );
    await pumpUntilScreen(tester, ScreenIds.notifyAsk);

    final fake = _fake(container);
    expect(fake.callCountOf('createProfile'), 1);
    expect(
      _bodyOf(fake.requestBodiesOf('createProfile').single)['honorific'],
      '별님',
    );
    expect(find.byType(EditableText), findsNothing);
    expect(
      container.read(onboardingDraftProvider).value,
      const OnboardingDraft(),
    );
  });

  testWidgets(
    'profile-save-unavailable: 저장이 통신 실패면 onboard-call에서 안내하고 다음으로 다시 저장합니다',
    (tester) async {
      final container = await openPreviewStep(
        tester,
        scenario: 'profile-save-unavailable',
      );
      await tester.tap(_screen(SlotIds.previewCtaSave));
      await tester.pumpAndSettle();
      await _signInToConsent(tester);
      await _checkAll(tester);

      await _agreeUntil(tester, ScreenIds.onboardCall);
      // 동의 직후 1회 + onboard-call 진입 때 1회에서 멈춥니다.
      await pumpUntil(
        tester,
        () => find.byType(EditableText).evaluate().isNotEmpty,
      );
      final fake = _fake(container);
      expect(fake.callCountOf('createProfile'), 2);
      expect(find.text(_ko.errorServiceUnavailable), findsOneWidget);
      expect(
        await tester.runAsync(
          () => container
              .read(deviceFlagsStoreProvider)
              .readBool(notifyAskPendingKey),
        ),
        isFalse,
      );
      expect(container.read(onboardingDraftProvider).value!.honorific, '별님');
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).controller.text,
        '별님',
      );
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      expect(fake.callCountOf('createProfile'), 2);

      // 입력이 완전하므로 onboard-call의 다음이 곧 다시 저장입니다.
      await tester.tap(find.byType(PrimaryButton));
      await pumpUntilScreen(tester, ScreenIds.notifyAsk);
      expect(fake.callCountOf('createProfile'), 3);
      expect(fake.callCountOf('createPreview'), 1);
    },
  );

  testWidgets('로그인 전에는 입력이 완전해도 onboard-call의 다음이 onboard-birth입니다', (
    tester,
  ) async {
    final container = await pumpApp(
      tester,
      scenario: 'new-user',
      locale: koreaLocale,
      overrides: [
        onboardingDraftStoreProvider.overrideWith(
          (ref) =>
              _SeededDraftStore(ref.watch(appDatabaseProvider), _completeDraft),
        ),
      ],
    );
    await tester.tap(_screen(SlotIds.welcomeCtaStart));
    await tester.pumpAndSettle();
    expect(_screen(ScreenIds.onboardCall), findsOneWidget);
    await tapNext(tester);

    expect(_screen(ScreenIds.onboardBirth), findsOneWidget);
    expect(_fake(container).callCountOf('createProfile'), 0);
  });
}
