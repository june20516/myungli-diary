import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:myungli_diary/app/entry/entry_providers.dart';
import 'package:myungli_diary/app/entry/entry_state.dart';
import 'package:myungli_diary/app/router/app_router.dart';
import 'package:myungli_diary/app/router/pending_destination.dart';
import 'package:myungli_diary/app/router/screen_registry.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/api/gen/model/app_config.dart';
import 'package:myungli_diary/core/api/gen/model/legal_links.dart';
import 'package:myungli_diary/core/api/gen/model/minimum_version.dart';
import 'package:myungli_diary/core/clock/clock.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/ia/ia_model.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/core/storage/app_database.dart';
import 'package:myungli_diary/core/storage/secure_store.dart';
import 'package:myungli_diary/design/components/frame/tab_bar.dart';
import 'package:myungli_diary/design/theme/app_theme.dart';

import '../contract/ia_pending.dart';

class _FixedEntry extends EntryController {
  new(this.value);

  final EntryState value;

  /// 실제 진입 계산처럼 받은 앱 설정을 담습니다(legal 화면이 다시 부르지 않음, D80).
  @override
  Future<EntrySnapshot> build() async => EntrySnapshot(
    value,
    null,
    config: AppConfig(
      minimumVersion: MinimumVersion(ios: '1.0.0', android: '1.0.0'),
      legal: LegalLinks(
        terms: 'https://example.com/legal/terms',
        privacy: 'https://example.com/legal/privacy',
      ),
    ),
  );
}

/// 라우터 테스트용 컨테이너. 진입 갈래는 [entry]로 바꾸고 DB는 메모리 DB를 씁니다.
///
/// 화면(예 today)이 DB를 읽으면 테스트마다 DB가 열립니다. 가짜 시계 안에서는 drift의
/// `close()`가 끝나지 않아 다음 테스트에서 "AppDatabase multiple times" 경고가 나므로,
/// 닫기는 실제 시계(`runAsync`)에서 끝까지 기다립니다.
ProviderContainer _routerContainer(WidgetTester tester, Override entry) {
  final database = AppDatabase.forExecutor(NativeDatabase.memory());
  final container = ProviderContainer(
    overrides: [
      entry,
      appDatabaseProvider.overrideWithValue(database),
      // 탭 화면의 요청이 토큰을 읽습니다. 플랫폼 보안 저장소는 테스트에서 답하지 않습니다.
      secureStoreProvider.overrideWithValue(MemorySecureStore()),
      // today 화면이 "오늘"을 읽습니다. 기기 시계면 자정 구독 timer가 테스트 뒤에 남습니다.
      clockProvider.overrideWithValue(
        FixedClock(DateTime.utc(2026, 10, 13, 3)),
      ),
    ],
  );
  addTearDown(() async {
    container.dispose();
    await tester.runAsync(database.close);
  });
  return container;
}

/// 테스트가 [complete]를 부를 때까지 계산 중(entry null)으로 남는 진입 갈래.
class _PendingEntry extends EntryController {
  final _result = Completer<EntrySnapshot>();

  @override
  Future<EntrySnapshot> build() => _result.future;

  void complete(EntryState entry) =>
      _result.complete(EntrySnapshot(entry, null));
}

/// 진입 계산이 끝나기 전 상태로 라우터를 띄웁니다.
Future<(ProviderContainer, GoRouter, _PendingEntry)> pumpPendingRouter(
  WidgetTester tester,
) async {
  final entry = _PendingEntry();
  final container = _routerContainer(
    tester,
    entryStateProvider.overrideWith(() => entry),
  );
  // 앱(MyungliApp)처럼 라우터를 듣고 있어야 진입 변화가 라우터에 닿습니다.
  final router = container.listen(routerProvider, (_, _) {}).read();
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: router,
        theme: buildTheme(
          brightness: Brightness.light,
          locale: const Locale('ko'),
        ),
        locale: const Locale('ko'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pump();
  return (container, router, entry);
}

Future<GoRouter> pumpRouter(
  WidgetTester tester,
  EntryState entry, {
  String? initial,
}) async {
  final container = _routerContainer(
    tester,
    entryStateProvider.overrideWith(() => _FixedEntry(entry)),
  );
  await container.read(entryStateProvider.future);
  final router = container.read(routerProvider);
  if (initial != null) {
    router.go(initial);
  }
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: router,
        theme: buildTheme(
          brightness: Brightness.light,
          locale: const Locale('ko'),
        ),
        locale: const Locale('ko'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

String currentPath(GoRouter router) =>
    router.routerDelegate.currentConfiguration.uri.path;

void main() {
  group('entryRedirect (순수 함수)', () {
    test('signedOut에서 member 화면은 /welcome', () {
      expect(
        entryRedirect(entry: EntryState.signedOut, location: '/today'),
        '/welcome',
      );
    });

    test('signedOut에서 일정 편집(/event-edit, date query 포함)은 /welcome', () {
      for (final location in ['/event-edit', '/event-edit?date=2026-10-20']) {
        expect(
          entryRedirect(entry: EntryState.signedOut, location: location),
          '/welcome',
          reason: location,
        );
      }
      expect(
        entryRedirect(
          entry: EntryState.ready,
          location: '/event-edit?date=2026-10-20',
        ),
        isNull,
      );
    });

    test('profileRequired는 로그인이 저장하는 보류 중일 때만 그대로 둔다(A79)', () {
      expect(
        entryRedirect(entry: EntryState.profileRequired, location: '/login'),
        '/onboard-call',
      );
      expect(
        entryRedirect(
          entry: EntryState.profileRequired,
          location: '/login',
          holdLogin: true,
        ),
        isNull,
      );
      // login 아래에 쌓인 화면(welcome)에서 다시 평가해도 붙듭니다.
      expect(
        entryRedirect(
          entry: EntryState.profileRequired,
          location: '/welcome',
          holdLogin: true,
        ),
        isNull,
      );
      // 보류는 profileRequired에서만 뜻이 있습니다.
      expect(
        entryRedirect(
          entry: EntryState.consentRequired,
          location: '/login',
          holdLogin: true,
        ),
        '/consent',
      );
    });

    test('ready에서 guest 화면은 /today', () {
      expect(
        entryRedirect(entry: EntryState.ready, location: '/welcome'),
        '/today',
      );
    });

    test('ready에서 notify-ask는 /today (알림 허락 대기가 끝난 뒤)', () {
      expect(
        entryRedirect(entry: EntryState.ready, location: '/notify-ask'),
        '/today',
      );
      expect(
        entryRedirect(
          entry: EntryState.adConsentRequired,
          location: '/notify-ask',
        ),
        '/today',
      );
    });

    test('ready·adConsentRequired에서 consent는 /today (관문 화면은 자기 갈래에서만)', () {
      expect(
        entryRedirect(entry: EntryState.ready, location: '/consent'),
        '/today',
      );
      expect(
        entryRedirect(
          entry: EntryState.adConsentRequired,
          location: '/consent',
        ),
        '/today',
      );
    });

    test('프로필 있는 갈래에서 온보딩 단계(수정 모드가 아님)는 /today', () {
      for (final entry in [EntryState.ready, EntryState.adConsentRequired]) {
        for (final id in [
          'onboard-call',
          'onboard-birth',
          'onboard-time',
          'onboard-gender',
          'birthplace',
        ]) {
          expect(
            entryRedirect(entry: entry, location: '/$id'),
            '/today',
            reason: '$entry /$id',
          );
          expect(
            entryRedirect(entry: entry, location: '/$id?mode=edit'),
            isNull,
            reason: '$entry /$id?mode=edit (A19 수정 모드)',
          );
        }
      }
    });

    test('profileRequired·signedOut에서 온보딩 단계는 그대로', () {
      expect(
        entryRedirect(
          entry: EntryState.profileRequired,
          location: '/onboard-gender',
        ),
        isNull,
      );
      expect(
        entryRedirect(entry: EntryState.signedOut, location: '/onboard-gender'),
        isNull,
      );
    });

    test('launch를 떠날 때 기억한 위치는 query까지 그대로 돌려줍니다', () {
      expect(
        entryRedirect(
          entry: EntryState.ready,
          location: '/launch',
          pending: '/onboard-call?mode=edit',
        ),
        '/onboard-call?mode=edit',
      );
      // 수정 모드가 아니면 프로필 있는 갈래에서 복원하지 않습니다.
      expect(
        entryRedirect(
          entry: EntryState.ready,
          location: '/launch',
          pending: '/onboard-call',
        ),
        '/today',
      );
    });

    test('ready에서 any 화면(/legal)은 그대로', () {
      expect(
        entryRedirect(entry: EntryState.ready, location: '/legal'),
        isNull,
      );
    });

    test('forceUpdate는 어디서든 /force-update', () {
      expect(
        entryRedirect(entry: EntryState.forceUpdate, location: '/today'),
        '/force-update',
      );
      expect(
        entryRedirect(entry: EntryState.forceUpdate, location: '/force-update'),
        isNull,
      );
    });

    test('consentRequired는 /consent와 /legal만 허용', () {
      expect(
        entryRedirect(entry: EntryState.consentRequired, location: '/today'),
        '/consent',
      );
      expect(
        entryRedirect(entry: EntryState.consentRequired, location: '/consent'),
        isNull,
      );
      expect(
        entryRedirect(entry: EntryState.consentRequired, location: '/legal'),
        isNull,
      );
    });

    test('profileRequired는 온보딩 경로를 그대로 둡니다', () {
      expect(
        entryRedirect(entry: EntryState.profileRequired, location: '/today'),
        '/onboard-call',
      );
      for (final path in [
        '/onboard-call',
        '/onboard-birth',
        '/onboard-time',
        '/onboard-gender',
        '/birthplace',
        '/legal',
      ]) {
        expect(
          entryRedirect(entry: EntryState.profileRequired, location: path),
          isNull,
          reason: path,
        );
      }
    });

    test('계산 기준(/calc-basis)은 로그인 전·온보딩 중·로그인 뒤 모두 그대로 (D71)', () {
      for (final entry in [
        EntryState.signedOut,
        EntryState.profileRequired,
        EntryState.ready,
      ]) {
        expect(
          entryRedirect(entry: entry, location: '/calc-basis'),
          isNull,
          reason: '$entry',
        );
      }
    });

    test('동의·알림 묻기·강제 업데이트 중에는 /calc-basis도 각 갈래 home으로', () {
      for (final (entry, home) in [
        (EntryState.consentRequired, '/consent'),
        (EntryState.notifyAskRequired, '/notify-ask'),
        (EntryState.forceUpdate, '/force-update'),
      ]) {
        expect(
          entryRedirect(entry: entry, location: '/calc-basis'),
          home,
          reason: '$entry',
        );
      }
    });

    test('notifyAskRequired는 /notify-ask만 허용 (A17)', () {
      expect(
        entryRedirect(entry: EntryState.notifyAskRequired, location: '/today'),
        '/notify-ask',
      );
      expect(
        entryRedirect(
          entry: EntryState.notifyAskRequired,
          location: '/notify-ask',
        ),
        isNull,
      );
      expect(
        entryRedirect(entry: EntryState.notifyAskRequired, location: '/launch'),
        '/notify-ask',
      );
    });

    test('계산이 끝나면 /launch에서 기억한 목적지가 허용되면 그곳으로 갑니다', () {
      expect(
        entryRedirect(
          entry: EntryState.ready,
          location: '/launch',
          pending: '/calendar',
        ),
        '/calendar',
      );
      expect(
        entryRedirect(
          entry: EntryState.ready,
          location: '/launch',
          pending: '/today',
        ),
        '/today',
      );
    });

    test('기억한 목적지가 그 갈래에서 허용되지 않으면 첫 화면으로 갑니다', () {
      expect(
        entryRedirect(
          entry: EntryState.signedOut,
          location: '/launch',
          pending: '/today',
        ),
        '/welcome',
      );
      expect(
        entryRedirect(
          entry: EntryState.notifyAskRequired,
          location: '/launch',
          pending: '/today',
        ),
        '/notify-ask',
      );
      expect(
        entryRedirect(
          entry: EntryState.ready,
          location: '/launch',
          pending: '/welcome',
        ),
        '/today',
      );
    });

    test('기억한 목적지가 IA page 화면이 아니면 첫 화면으로 갑니다', () {
      for (final pending in ['/auth/apple', '/launch', '/day-sheet']) {
        expect(
          entryRedirect(
            entry: EntryState.ready,
            location: '/launch',
            pending: pending,
          ),
          '/today',
          reason: pending,
        );
      }
    });

    test('/launch가 아닌 곳에서는 기억한 목적지를 쓰지 않습니다', () {
      expect(
        entryRedirect(
          entry: EntryState.ready,
          location: '/welcome',
          pending: '/calendar',
        ),
        '/today',
      );
    });

    test('아직 계산 전이면 /launch로 모읍니다', () {
      expect(entryRedirect(entry: null, location: '/today'), '/launch');
      expect(entryRedirect(entry: null, location: '/launch'), isNull);
    });

    test('계산이 끝나면 /launch에서 갈래의 첫 화면으로 보냅니다', () {
      expect(
        entryRedirect(entry: EntryState.signedOut, location: '/launch'),
        '/welcome',
      );
      expect(
        entryRedirect(entry: EntryState.ready, location: '/launch'),
        '/today',
      );
      expect(
        entryRedirect(entry: EntryState.profileRequired, location: '/launch'),
        '/onboard-call',
      );
    });

    test('어떤 상태·경로에서도 redirect가 루프 없이 멈춥니다', () {
      final paths = [
        for (final screen in iaScreens)
          if (screen.presentation == IaPresentation.page) '/${screen.id}',
      ];
      for (final entry in [null, ...EntryState.values]) {
        for (final start in paths) {
          var path = start;
          final seen = <String>{path};
          for (;;) {
            final next = entryRedirect(entry: entry, location: path);
            if (next == null) {
              break;
            }
            expect(seen.add(next), isTrue, reason: '$entry $start 루프');
            path = next;
          }
        }
      }
    });
  });

  group('진입 뒤 목적지 복귀', () {
    testWidgets('계산 전 /onboard-call?mode=edit는 query까지 기억했다가 ready면 수정 모드로', (
      tester,
    ) async {
      final (container, router, entry) = await pumpPendingRouter(tester);
      router.go('/onboard-call?mode=edit');
      await tester.pump();
      expect(currentPath(router), '/launch');
      expect(
        container.read(pendingDestinationProvider),
        '/onboard-call?mode=edit',
      );

      entry.complete(EntryState.ready);
      await tester.pumpAndSettle();
      expect(
        router.routerDelegate.currentConfiguration.uri.toString(),
        '/onboard-call?mode=edit',
      );
    });

    testWidgets('계산 전 /calendar는 /launch로 가고 기억했다가 ready가 되면 /calendar', (
      tester,
    ) async {
      final (container, router, entry) = await pumpPendingRouter(tester);
      router.go('/calendar');
      await tester.pump();
      expect(currentPath(router), '/launch');
      expect(container.read(pendingDestinationProvider), '/calendar');

      entry.complete(EntryState.ready);
      await tester.pumpAndSettle();
      expect(currentPath(router), '/calendar');
      expect(
        container.read(pendingDestinationProvider),
        isNull,
        reason: '비웁니다',
      );
    });

    testWidgets('기억한 /today는 signedOut이면 /welcome', (tester) async {
      final (container, router, entry) = await pumpPendingRouter(tester);
      router.go('/today');
      await tester.pump();
      expect(container.read(pendingDestinationProvider), '/today');

      entry.complete(EntryState.signedOut);
      await tester.pumpAndSettle();
      expect(currentPath(router), '/welcome');
      expect(container.read(pendingDestinationProvider), isNull);
    });
  });

  group('screenRegistry', () {
    test('page 화면만 있고 모두 IA id입니다', () {
      final pageIds = {
        for (final screen in iaScreens)
          if (screen.presentation == IaPresentation.page) screen.id,
      };
      expect(screenRegistry.keys.toSet(), pageIds);
      // 상태를 직접 처리하는 화면은 IA에 상태가 있고 ratchet에서 빠진 화면과 같습니다.
      expect(
        {
          for (final spec in screenRegistry.values)
            if (spec.handledStates.isNotEmpty) spec.id,
        },
        {
          for (final screen in iaScreens)
            if (screen.presentation == IaPresentation.page &&
                screen.states.isNotEmpty &&
                !pendingStateScreens.contains(screen.id))
              screen.id,
        },
      );
    });
  });

  group('router', () {
    testWidgets('signedOut에서 /today로 가면 /welcome', (tester) async {
      final router = await pumpRouter(
        tester,
        EntryState.signedOut,
        initial: '/today',
      );
      expect(currentPath(router), '/welcome');
      expect(find.byKey(const Key('welcome')), findsOneWidget);
      expect(find.bySemanticsIdentifier('welcome'), findsOneWidget);
    });

    testWidgets('ready에서 /welcome으로 가면 /today', (tester) async {
      final router = await pumpRouter(
        tester,
        EntryState.ready,
        initial: '/welcome',
      );
      expect(currentPath(router), '/today');
      expect(find.byKey(const Key('today')), findsOneWidget);
    });

    testWidgets('ready에서 /legal은 그대로', (tester) async {
      final router = await pumpRouter(
        tester,
        EntryState.ready,
        initial: '/legal',
      );
      expect(currentPath(router), '/legal');
      expect(find.byKey(const Key('legal')), findsOneWidget);
    });

    testWidgets('profileRequired에서 /calc-basis는 계산 기준 화면을 엽니다 (D71)', (
      tester,
    ) async {
      final router = await pumpRouter(
        tester,
        EntryState.profileRequired,
        initial: '/calc-basis',
      );
      expect(currentPath(router), '/calc-basis');
      expect(find.byKey(const Key('calc-basis')), findsOneWidget);
    });

    testWidgets('IA에 없는 경로는 갈래의 첫 화면으로 보냅니다', (tester) async {
      final router = await pumpRouter(
        tester,
        EntryState.ready,
        initial: '/auth/apple',
      );
      expect(currentPath(router), '/today');
      expect(find.byKey(const Key('today')), findsOneWidget);

      router.go('/no-such-screen');
      await tester.pumpAndSettle();
      expect(currentPath(router), '/today');
    });

    testWidgets('로그아웃 상태에서 IA에 없는 경로는 /welcome', (tester) async {
      final router = await pumpRouter(
        tester,
        EntryState.signedOut,
        initial: '/no-such-screen',
      );
      expect(currentPath(router), '/welcome');
    });

    testWidgets('탭 4개를 오갈 수 있습니다', (tester) async {
      final semantics = tester.ensureSemantics();
      final router = await pumpRouter(tester, EntryState.ready);
      expect(currentPath(router), '/today');
      for (final tab in ['calendar', 'diary-list', 'my-saju', 'today']) {
        final index = [
          'today',
          'calendar',
          'diary-list',
          'my-saju',
        ].indexOf(tab);
        await tester.tap(find.byKey(ValueKey('tab-bar.tab.$index')));
        await tester.pumpAndSettle();
        expect(currentPath(router), '/$tab');
        expect(find.byKey(Key(tab)), findsOneWidget);
        // 탭 바의 탭은 화면 이름(ko)으로 읽힙니다. 화면 본문의 같은 글자와 섞이지
        // 않게 탭 바 안에서만 찾습니다.
        expect(
          find.descendant(
            of: find.byType(TabBarRow),
            matching: find.bySemanticsLabel(
              RegExp(['오늘', '달력', '일기', '나'][index]),
            ),
          ),
          findsOneWidget,
        );
      }
      semantics.dispose();
    });
  });
}
