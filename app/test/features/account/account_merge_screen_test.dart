import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:myungli_diary/app/entry/entry_providers.dart';
import 'package:myungli_diary/app/entry/entry_state.dart';
import 'package:myungli_diary/app/router/app_router.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/gen/model/birth.dart';
import 'package:myungli_diary/core/api/gen/model/birth_place.dart';
import 'package:myungli_diary/core/api/gen/model/birth_time.dart';
import 'package:myungli_diary/core/api/gen/model/calendar_type.dart';
import 'package:myungli_diary/core/api/gen/model/lunar_or_solar_date.dart';
import 'package:myungli_diary/core/api/gen/model/me.dart';
import 'package:myungli_diary/core/api/gen/model/merge_profile.dart';
import 'package:myungli_diary/core/api/gen/model/merge_profile_summary.dart';
import 'package:myungli_diary/core/api/token_store.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/birth_format.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations_ko.dart';
import 'package:myungli_diary/core/platform/fakes.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';
import 'package:myungli_diary/core/platform/social_auth.dart';
import 'package:myungli_diary/core/storage/app_database.dart';
import 'package:myungli_diary/core/storage/secure_store.dart';
import 'package:myungli_diary/design/components/action/primary_button.dart';
import 'package:myungli_diary/design/components/action/social_login_button.dart';
import 'package:myungli_diary/design/components/frame/app_bar.dart';
import 'package:myungli_diary/design/components/input/account_choice.dart';
import 'package:myungli_diary/design/elements/app_icon.dart';
import 'package:myungli_diary/design/theme/app_theme.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';
import 'package:myungli_diary/features/account/application/account_merge_controller.dart';
import 'package:myungli_diary/features/account/data/account_link_repository.dart';
import 'package:myungli_diary/features/account/presentation/account_merge_screen.dart';
import 'package:myungli_diary/features/account/presentation/merge_summary_box.dart';
import 'package:phosphor_glyphs/phosphor_glyphs.dart';

import '../../support/app_bar_title.dart';
import 'fake_identity_api.dart';

final _ko = AppLocalizationsKo();

/// login-methods 자리의 시험용 화면. 합치기로 가는 버튼만 있습니다.
const Key _openMergeKey = ValueKey('test.open-merge');

/// onboard-call 자리의 시험용 화면.
const Key _onboardCallKey = ValueKey('test.onboard-call');

/// 처음엔 회원 갈래이고, 받은 내 정보로 갈래를 다시 정하는 진입 대역입니다.
class _FakeEntry extends EntryController {
  @override
  Future<EntrySnapshot> build() async =>
      EntrySnapshot(EntryState.ready, mergedMe(adFree: false));

  @override
  Future<AppError?> applyMe(Me me) async {
    state = AsyncData(
      EntrySnapshot(
        me.hasProfile ? EntryState.ready : EntryState.profileRequired,
        me,
      ),
    );
    return null;
  }
}

/// [gate]가 열릴 때까지 인증 창을 닫지 않는 Google 대역입니다.
final class _GatedGoogleAuth implements GoogleAuth {
  final gate = Completer<void>();

  @override
  Future<GoogleCredential> signIn({required String rawNonce}) async {
    await gate.future;
    return GoogleCredential(idToken: 'google-id-token', rawNonce: rawNonce);
  }
}

final class _Harness {
  new(this.api, this.container, this.router);

  final FakeIdentityApi api;
  final ProviderContainer container;
  final GoRouter router;

  AccountMergeState get state => container.read(accountMergeControllerProvider);
}

/// login-methods 자리에서 account-merge로 들어간 화면을 띄웁니다. 라우터는 앱과 같은
/// [entryRedirect]로 진입 갈래를 따릅니다.
Future<_Harness> _pump(
  WidgetTester tester, {
  FakeIdentityApi? api,
  GoogleAuth? google,
}) async {
  // 휴대폰 크기 화면. 합치기 버튼이 바닥에 붙어 보입니다.
  tester.view
    ..physicalSize = const Size(1170, 2532)
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final server = api ?? FakeIdentityApi();
  final container = ProviderContainer(
    overrides: [
      crashReporterProvider.overrideWithValue(FakeCrashReporter()),
      accountLinkRepositoryProvider.overrideWithValue(
        AccountLinkRepository(server),
      ),
      targetPlatformProvider.overrideWithValue(TargetPlatform.android),
      if (google != null) googleAuthProvider.overrideWithValue(google),
      appDatabaseProvider.overrideWith((ref) {
        final database = AppDatabase.forExecutor(NativeDatabase.memory());
        ref.onDispose(database.close);
        return database;
      }),
      tokenStoreProvider.overrideWithValue(TokenStore(MemorySecureStore())),
      entryStateProvider.overrideWith(_FakeEntry.new),
      mergeRetryDelayProvider.overrideWithValue((_) async {}),
    ],
  );
  addTearDown(container.dispose);
  await tester.runAsync(() => container.read(entryStateProvider.future));
  final refresh = ValueNotifier<int>(0);
  addTearDown(refresh.dispose);
  container.listen(entryProvider, (_, _) => refresh.value++);
  final router = GoRouter(
    initialLocation: pathOf(ScreenIds.loginMethods),
    refreshListenable: refresh,
    redirect: (context, state) => entryRedirect(
      entry: container.read(entryProvider),
      location: state.uri.toString(),
    ),
    routes: [
      GoRoute(
        path: pathOf(ScreenIds.loginMethods),
        builder: (context, _) => Scaffold(
          body: TextButton(
            key: _openMergeKey,
            onPressed: () => context.push(pathOf(ScreenIds.accountMerge)),
            child: const Text('merge'),
          ),
        ),
      ),
      GoRoute(
        path: pathOf(ScreenIds.accountMerge),
        builder: (_, _) => const AccountMergeScreen(),
      ),
      GoRoute(
        path: pathOf(ScreenIds.onboardCall),
        builder: (_, _) => const Scaffold(key: _onboardCallKey),
      ),
    ],
  );
  addTearDown(router.dispose);
  const locale = Locale('ko');
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: router,
        locale: locale,
        theme: buildTheme(brightness: Brightness.light, locale: locale),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(_openMergeKey));
  await tester.pumpAndSettle();
  return _Harness(server, container, router);
}

Finder _button(SocialProvider provider) => find.byWidgetPredicate(
  (w) => w is SocialLoginButton && w.provider == provider,
);

SocialLoginButton _social(WidgetTester tester, SocialProvider provider) =>
    tester.widget<SocialLoginButton>(_button(provider));

Finder get _cta => find.byKey(AccountMergeScreen.mergeCtaKey);

PrimaryButton _ctaWidget(WidgetTester tester) =>
    tester.widget<PrimaryButton>(_cta);

AccountChoice _choice(WidgetTester tester) =>
    tester.widget<AccountChoice>(find.byType(AccountChoice));

/// 인증해 요약·고르기 단계로 갑니다(실제 I/O라 settle을 여러 번 기다립니다).
Future<void> _authenticate(
  WidgetTester tester, [
  SocialProvider provider = SocialProvider.line,
]) async {
  await tester.tap(_button(provider));
  await tester.pumpAndSettle();
}

Future<void> _choose(WidgetTester tester, int index) async {
  await tester.tap(find.byKey(AccountChoice.cardKey(index)));
  await tester.pumpAndSettle();
}

Future<void> _confirmMerge(WidgetTester tester) async {
  await tester.ensureVisible(_cta);
  await tester.tap(_cta);
  await tester.pumpAndSettle();
  await tester.tap(find.text(_ko.accountMergeMergeConfirmMerge));
}

double _top(WidgetTester tester, Finder finder) => tester.getTopLeft(finder).dy;

void main() {
  testWidgets('app-bar 제목은 account-merge.bar.title 슬롯', (tester) async {
    await _pump(tester);
    await expectAppBarTitle(
      tester,
      SlotIds.accountMergeBarTitle,
      _ko.accountMergeBarTitle,
    );
  });

  group('인증 단계', () {
    testWidgets('제목, auth.body, 네 버튼(loginProviderOrder)', (tester) async {
      await _pump(tester);
      expect(find.text(_ko.accountMergeTitleHead), findsOneWidget);
      expect(find.text(_ko.accountMergeAuthBody), findsOneWidget);
      final buttons =
          tester
              .widgetList<SocialLoginButton>(find.byType(SocialLoginButton))
              .toList()
            ..sort(
              (a, b) => _top(
                tester,
                find.byWidget(a),
              ).compareTo(_top(tester, find.byWidget(b))),
            );
      expect(
        [for (final b in buttons) b.provider],
        [
          SocialProvider.kakao,
          SocialProvider.line,
          SocialProvider.google,
          SocialProvider.apple,
        ],
      );
      expect(
        [for (final b in buttons) b.label],
        [
          _ko.loginKakaoLabel,
          _ko.loginLineLabel,
          _ko.loginGoogleLabel,
          _ko.loginAppleLabel,
        ],
      );
      expect(buttons.any((b) => b.connected), isFalse);
      expect(_cta, findsNothing);
    });

    testWidgets('누른 버튼만 loading, 나머지는 disabled', (tester) async {
      final google = _GatedGoogleAuth();
      final h = await _pump(tester, google: google);
      await tester.tap(_button(SocialProvider.google));
      await tester.pump();
      expect((h.state as MergeAuth).busy, SocialProvider.google);
      expect(_social(tester, SocialProvider.google).loading, isTrue);
      for (final other in [
        SocialProvider.kakao,
        SocialProvider.line,
        SocialProvider.apple,
      ]) {
        expect(_social(tester, other).loading, isFalse);
        expect(_social(tester, other).disabled, isTrue);
        expect(_social(tester, other).onPressed, isNull);
      }
      google.gate.complete();
      await tester.pumpAndSettle();
      expect(h.state, isA<MergeChoosing>());
    });

    for (final entry in {
      'merge.same_account': _ko.accountMergeNotOtherBodySelf,
      'merge.no_account': _ko.accountMergeNotOtherBodyNone,
    }.entries) {
      testWidgets('not-other ${entry.key}: dialog notice 뒤 인증 단계', (
        tester,
      ) async {
        final api = FakeIdentityApi()..previewError = problemOf(422, entry.key);
        await _pump(tester, api: api);
        await _authenticate(tester);
        expect(find.text(entry.value), findsOneWidget);
        await tester.tap(find.text(_ko.actionConfirm));
        await tester.pumpAndSettle();
        expect(find.text(entry.value), findsNothing);
        expect(find.text(_ko.accountMergeAuthBody), findsOneWidget);
        expect(_social(tester, SocialProvider.line).onPressed, isNotNull);
        expect(api.linkCalls, isEmpty);
      });
    }

    testWidgets('요약 실패: accountMergeError dialog 뒤 인증 단계', (tester) async {
      final api = FakeIdentityApi()
        ..previewError = problemOf(401, 'auth.provider_token_invalid');
      await _pump(tester, api: api);
      await _authenticate(tester);
      expect(find.text(_ko.accountMergeError), findsOneWidget);
      await tester.tap(find.text(_ko.actionConfirm));
      await tester.pumpAndSettle();
      expect(find.text(_ko.accountMergeAuthBody), findsOneWidget);
    });
  });

  testWidgets('loading: 요약 상자와 카드 자리가 숨쉼', (tester) async {
    final api = FakeIdentityApi();
    final gate = api.previewGate = Completer<void>();
    final h = await _pump(tester, api: api);
    await tester.tap(_button(SocialProvider.line));
    await tester.pump();
    await tester.pump();
    expect(h.state, isA<MergeSummaryLoading>());
    expect(find.byKey(MergeSummaryBox.loadingKey), findsOneWidget);
    expect(_choice(tester).loading, isTrue);
    expect(find.text(_ko.accountMergeAuthBody), findsNothing);
    gate.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(MergeSummaryBox.loadingKey), findsNothing);
  });

  group('요약·고르기', () {
    testWidgets('title.body와 상자 줄 순서 일기 → 일정 → 광고 제거', (tester) async {
      await _pump(tester);
      await _authenticate(tester);
      expect(find.text(_ko.accountMergeTitleHead), findsOneWidget);
      expect(find.text(_ko.accountMergeTitleBody), findsOneWidget);
      expect(find.text(_ko.accountMergeSummaryHead), findsOneWidget);
      final diary = find.text(_ko.accountMergeSummaryDiary);
      final event = find.text(_ko.accountMergeSummaryEvent);
      final adFree = find.text(_ko.accountMergeSummaryAdFree);
      expect(_top(tester, diary), lessThan(_top(tester, event)));
      expect(_top(tester, event), lessThan(_top(tester, adFree)));
      expect(find.text(_ko.accountMergeSummaryDiaryCount(2)), findsOneWidget);
      expect(find.text(_ko.accountMergeSummaryEventCount(0)), findsOneWidget);
      expect(find.text(_ko.accountMergeSummaryAdFreeDays(12)), findsOneWidget);
    });

    testWidgets('일기·일정 0이어도 보이고 adFree 0이면 광고 제거 줄 없음', (tester) async {
      final api = FakeIdentityApi()
        ..preview = mergePreview(diaries: 0, adFreeDays: 0);
      await _pump(tester, api: api);
      await _authenticate(tester);
      expect(find.text(_ko.accountMergeSummaryDiaryCount(0)), findsOneWidget);
      expect(find.text(_ko.accountMergeSummaryEventCount(0)), findsOneWidget);
      expect(find.text(_ko.accountMergeSummaryAdFree), findsNothing);
    });

    testWidgets('제목은 두 단계에서 같은 자리(app-bar 아래 space.12)', (tester) async {
      await _pump(tester);
      final title = find.text(_ko.accountMergeTitleHead);
      final barBottom = tester.getBottomLeft(find.byType(MyungliAppBar)).dy;
      final authTop = _top(tester, title);
      expect(authTop - barBottom, Space.s12);
      await _authenticate(tester);
      expect(_top(tester, title), authTop);
    });

    testWidgets('본문은 위 정렬이고 합치기 버튼은 바닥(내용이 짧을 때)', (tester) async {
      await _pump(tester);
      await _authenticate(tester);
      final body = find.text(_ko.accountMergeTitleBody);
      final title = find.text(_ko.accountMergeTitleHead);
      expect(_top(tester, body) - tester.getBottomLeft(title).dy, Space.s8);
      final screenBottom =
          tester.view.physicalSize.height / tester.view.devicePixelRatio;
      expect(
        tester.getBottomLeft(_cta).dy,
        moreOrLessEquals(screenBottom - Space.s24),
      );
    });

    testWidgets('내용이 길면 합치기 버튼이 본문 뒤로 이어 스크롤', (tester) async {
      await _pump(tester);
      tester.view.physicalSize = const Size(960, 1200);
      await tester.pumpAndSettle();
      await _authenticate(tester);
      await tester.ensureVisible(_cta);
      await tester.pumpAndSettle();
      final notice = find.text(_ko.accountMergeOverlapNotice);
      expect(_top(tester, _cta) - tester.getBottomLeft(notice).dy, Space.s32);
    });

    testWidgets('overlap.notice: check-circle 16, 사이 space.8, caption.lg', (
      tester,
    ) async {
      await _pump(tester);
      await _authenticate(tester);
      final notice = find.text(_ko.accountMergeOverlapNotice);
      final tokens = tester.element(notice).tokens;
      expect(
        _top(
              tester,
              find.byKey(const ValueKey(SlotIds.accountMergeOverlapNotice)),
            ) -
            tester.getBottomLeft(find.byType(AccountChoice)).dy,
        Space.s16,
      );
      final icon = find.descendant(
        of: find.byKey(const ValueKey(SlotIds.accountMergeOverlapNotice)),
        matching: find.byType(AppIcon),
      );
      expect(icon, findsOneWidget);
      final glyph = tester.widget<AppIcon>(icon);
      expect(glyph.icon.light, PhosphorIconsLight.checkCircle);
      expect(glyph.weight, AppIconWeight.light);
      expect(glyph.size, AppIconSize.inline);
      expect(glyph.color, tokens.colors.textSecondary);
      expect(
        tester.getTopLeft(notice).dx - tester.getTopRight(icon).dx,
        Space.s8,
      );
      final style = tester.widget<Text>(notice).style!;
      expect(style.fontSize, tokens.typography.captionLg.fontSize);
      expect(style.height, tokens.typography.captionLg.height);
      expect(style.color, tokens.colors.textSecondary);
    });

    testWidgets('overlapDays 0이면 overlap.notice 없음', (tester) async {
      final api = FakeIdentityApi()..preview = mergePreview(overlapDays: 0);
      await _pump(tester, api: api);
      await _authenticate(tester);
      expect(find.text(_ko.accountMergeOverlapNotice), findsNothing);
    });

    testWidgets('overlapDays 1 이상이면 overlap.notice가 있고 고르기와 무관', (
      tester,
    ) async {
      await _pump(tester);
      await _authenticate(tester);
      expect(find.text(_ko.accountMergeOverlapNotice), findsOneWidget);
      await _choose(tester, 1);
      expect(find.text(_ko.accountMergeOverlapNotice), findsOneWidget);
      await _choose(tester, 0);
      expect(find.text(_ko.accountMergeOverlapNotice), findsOneWidget);
    });

    testWidgets('account-choice A → B, 처음엔 고르지 않음, 고르기 전 합치기 disabled', (
      tester,
    ) async {
      await _pump(tester);
      await _authenticate(tester);
      expect(find.text(_ko.accountMergeChoiceLabel), findsOneWidget);
      final choice = _choice(tester);
      expect(choice.options.map((o) => o.current), [true, false]);
      expect(choice.options.map((o) => o.name), ['하늘', '바다']);
      expect(choice.currentLabel, _ko.accountChoiceCurrent);
      expect(choice.otherLabel, _ko.accountChoiceOther);
      expect(choice.selectedIndex, isNull);
      expect(_ctaWidget(tester).onPressed, isNull);
      expect(_ctaWidget(tester).label, _ko.accountMergeCtaMerge);

      await _choose(tester, 1);
      expect(_choice(tester).selectedIndex, 1);
      expect(_ctaWidget(tester).onPressed, isNotNull);
    });

    testWidgets('status none 카드는 accountChoiceSajuEmpty, 사주가 있으면 요약 줄', (
      tester,
    ) async {
      final api = FakeIdentityApi()
        ..preview = mergePreview(
          current: MergeProfileSummary(
            status: MergeProfileSummaryStatusEnum.saved,
            honorific: '하늘',
            birth: Birth(
              calendar: CalendarType.solar,
              date: LunarOrSolarDate(year: 1990, month: 4, day: 15),
              isLeapMonth: false,
              time: BirthTime(status: BirthTimeStatusEnum.unknown),
              gender: BirthGenderEnum.female,
              timezone: 'Asia/Seoul',
              place: BirthPlace(status: BirthPlaceStatusEnum.notAsked),
            ),
          ),
          other: MergeProfileSummary(
            status: MergeProfileSummaryStatusEnum.none,
          ),
        );
      await _pump(tester, api: api);
      await _authenticate(tester);
      final options = _choice(tester).options;
      expect(options[1].saju, _ko.accountChoiceSajuEmpty);
      expect(options[0].saju, isNot(_ko.accountChoiceSajuEmpty));
      expect(options[0].saju, startsWith(_ko.calendarSolar));
      expect(options[0].saju, contains('1990'));
    });

    testWidgets('음력 윤달 생일은 달력 종류 뒤에 윤달 낱말이 붙는 틀입니다(V48, W46)', (tester) async {
      Birth lunar({required bool leap, required BirthTime time}) => Birth(
        calendar: CalendarType.lunar,
        date: LunarOrSolarDate(year: 1990, month: 6, day: 15),
        isLeapMonth: leap,
        time: time,
        gender: BirthGenderEnum.female,
        timezone: 'Asia/Seoul',
        place: BirthPlace(status: BirthPlaceStatusEnum.notAsked),
      );
      final api = FakeIdentityApi()
        ..preview = mergePreview(
          current: MergeProfileSummary(
            status: MergeProfileSummaryStatusEnum.saved,
            honorific: '하늘',
            birth: lunar(
              leap: true,
              time: BirthTime(
                status: BirthTimeStatusEnum.known,
                value: '08:30',
              ),
            ),
          ),
          other: MergeProfileSummary(
            status: MergeProfileSummaryStatusEnum.saved,
            honorific: '바다',
            birth: lunar(
              leap: true,
              time: BirthTime(status: BirthTimeStatusEnum.unknown),
            ),
          ),
        );
      await _pump(tester, api: api);
      await _authenticate(tester);
      final options = _choice(tester).options;
      final date = formatBirthDay('ko', 1990, 6, 15);
      expect(
        options[0].saju,
        _ko.accountChoiceSajuLeap(
          date,
          _ko.calendarLunar,
          formatBirthClock('ko', '08:30'),
        ),
      );
      expect(
        options[1].saju,
        _ko.accountChoiceSajuNoTimeLeap(date, _ko.calendarLunar),
      );
      expect(options[0].saju, startsWith('${_ko.calendarLunar} 윤달 '));
    });
  });

  group('합치기', () {
    testWidgets('확인 dialog destructive 뒤에만 merge', (tester) async {
      final h = await _pump(tester);
      await _authenticate(tester);
      await _choose(tester, 1);
      await tester.tap(_cta);
      await tester.pumpAndSettle();
      expect(find.text(_ko.accountMergeMergeConfirm), findsOneWidget);
      await tester.tap(find.text(_ko.accountMergeMergeConfirmCancel));
      await tester.pumpAndSettle();
      expect(h.api.mergeCalls, isEmpty);

      await _confirmMerge(tester);
      await tester.pumpAndSettle();
      expect(h.api.mergeCalls, hasLength(1));
      expect(h.api.mergeCalls.single.profile, MergeProfile.other);
    });

    testWidgets('합치는 동안 버튼 loading, 카드 disabled, 뒤로 가기(app-bar, 시스템) 막힘', (
      tester,
    ) async {
      final api = FakeIdentityApi();
      final gate = api.mergeGate = Completer<void>();
      final h = await _pump(tester, api: api);
      await _authenticate(tester);
      await _choose(tester, 0);
      await _confirmMerge(tester);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(h.state, isA<MergeRunning>());
      expect(_ctaWidget(tester).loading, isTrue);
      expect(_choice(tester).onSelected, isNull);
      expect(
        tester.widget<MyungliAppBar>(find.byType(MyungliAppBar)).showBack,
        isFalse,
      );
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byType(AccountMergeScreen), findsOneWidget);

      gate.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('완료 → login-methods(진입이 회원 갈래 그대로)', (tester) async {
      final h = await _pump(tester);
      await _authenticate(tester);
      await _choose(tester, 0);
      await _confirmMerge(tester);
      await tester.pumpAndSettle();
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
      expect(find.byType(AccountMergeScreen), findsNothing);
      expect(find.byKey(_openMergeKey), findsOneWidget);
      expect(
        h.router.routerDelegate.currentConfiguration.uri.path,
        pathOf(ScreenIds.loginMethods),
      );
    });

    testWidgets('완료 뒤 진입이 다른 갈래(profileRequired)면 그 화면이 우선', (tester) async {
      final api = FakeIdentityApi()..mergeMe = mergedMe(hasProfile: false);
      final h = await _pump(tester, api: api);
      await _authenticate(tester);
      await _choose(tester, 1);
      await _confirmMerge(tester);
      await tester.pumpAndSettle();
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
      expect(find.byKey(_onboardCallKey), findsOneWidget);
      expect(
        h.router.routerDelegate.currentConfiguration.uri.path,
        pathOf(ScreenIds.onboardCall),
      );
    });

    testWidgets('MergeTokenInvalid → errorMergeTokenInvalid dialog 뒤 인증 단계', (
      tester,
    ) async {
      final api = FakeIdentityApi()
        ..mergeAnswers.add(problemOf(422, 'merge.token_invalid'));
      await _pump(tester, api: api);
      await _authenticate(tester);
      await _choose(tester, 0);
      await _confirmMerge(tester);
      await tester.pumpAndSettle();
      expect(find.text(_ko.errorMergeTokenInvalid), findsOneWidget);
      await tester.tap(find.text(_ko.actionConfirm));
      await tester.pumpAndSettle();
      expect(find.text(_ko.accountMergeAuthBody), findsOneWidget);
      expect(find.byType(AccountChoice), findsNothing);
    });

    testWidgets('MergeFailed → accountMergeError dialog, 고름 유지', (
      tester,
    ) async {
      final api = FakeIdentityApi()
        ..mergeAnswers.add(problemOf(500, 'internal'));
      await _pump(tester, api: api);
      await _authenticate(tester);
      await _choose(tester, 1);
      await _confirmMerge(tester);
      await tester.pumpAndSettle();
      expect(find.text(_ko.accountMergeError), findsOneWidget);
      await tester.tap(find.text(_ko.actionConfirm));
      await tester.pumpAndSettle();
      expect(_choice(tester).selectedIndex, 1);
      expect(_choice(tester).onSelected, isNotNull);
      expect(_ctaWidget(tester).onPressed, isNotNull);
    });
  });

  group('그만두기', () {
    testWidgets('"합치지 않기" 버튼 없음', (tester) async {
      await _pump(tester);
      await _authenticate(tester);
      expect(
        find.byWidgetPredicate(
          (w) => w is PrimaryButton && w.key != AccountMergeScreen.mergeCtaKey,
        ),
        findsNothing,
      );
    });

    for (final stage in ['인증', '요약·고르기']) {
      testWidgets('$stage 단계에서 뒤로 가기는 login-methods이고 합치기 토큰을 버림', (
        tester,
      ) async {
        final h = await _pump(tester);
        if (stage != '인증') {
          await _authenticate(tester);
          await _choose(tester, 0);
          expect(h.state, isA<MergeChoosing>());
        }
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byKey(_openMergeKey), findsOneWidget);
        // 화면을 떠나 controller가 버려졌으므로 다시 읽으면 처음 인증 단계입니다.
        final fresh = h.container.read(accountMergeControllerProvider);
        expect(fresh, isA<MergeAuth>());
        expect(h.api.mergeCalls, isEmpty);
      });
    }
  });
}
