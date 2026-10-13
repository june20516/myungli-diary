import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:myungli_diary/app/entry/entry_providers.dart';
import 'package:myungli_diary/app/entry/entry_state.dart';
import 'package:myungli_diary/app/router/app_router.dart';
import 'package:myungli_diary/app/router/screen_registry.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/ia/ia_model.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/theme/app_theme.dart';

class _FixedEntry extends EntryController {
  new(this.value);

  final EntryState value;

  @override
  Future<EntrySnapshot> build() async => EntrySnapshot(value, null);
}

Future<GoRouter> pumpRouter(
  WidgetTester tester,
  EntryState entry, {
  String? initial,
}) async {
  final container = ProviderContainer(
    overrides: [entryStateProvider.overrideWith(() => _FixedEntry(entry))],
  );
  addTearDown(container.dispose);
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
        entryRedirect(entry: EntryState.signedOut, path: '/today'),
        '/welcome',
      );
    });

    test('ready에서 guest 화면은 /today', () {
      expect(
        entryRedirect(entry: EntryState.ready, path: '/welcome'),
        '/today',
      );
    });

    test('ready에서 any 화면(/legal)은 그대로', () {
      expect(entryRedirect(entry: EntryState.ready, path: '/legal'), isNull);
    });

    test('forceUpdate는 어디서든 /force-update', () {
      expect(
        entryRedirect(entry: EntryState.forceUpdate, path: '/today'),
        '/force-update',
      );
      expect(
        entryRedirect(entry: EntryState.forceUpdate, path: '/force-update'),
        isNull,
      );
    });

    test('consentRequired는 /consent와 /legal만 허용', () {
      expect(
        entryRedirect(entry: EntryState.consentRequired, path: '/today'),
        '/consent',
      );
      expect(
        entryRedirect(entry: EntryState.consentRequired, path: '/consent'),
        isNull,
      );
      expect(
        entryRedirect(entry: EntryState.consentRequired, path: '/legal'),
        isNull,
      );
    });

    test('profileRequired는 온보딩 경로를 그대로 둡니다', () {
      expect(
        entryRedirect(entry: EntryState.profileRequired, path: '/today'),
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
          entryRedirect(entry: EntryState.profileRequired, path: path),
          isNull,
          reason: path,
        );
      }
    });

    test('아직 계산 전이면 /launch로 모읍니다', () {
      expect(entryRedirect(entry: null, path: '/today'), '/launch');
      expect(entryRedirect(entry: null, path: '/launch'), isNull);
    });

    test('계산이 끝나면 /launch에서 갈래의 첫 화면으로 보냅니다', () {
      expect(
        entryRedirect(entry: EntryState.signedOut, path: '/launch'),
        '/welcome',
      );
      expect(entryRedirect(entry: EntryState.ready, path: '/launch'), '/today');
      expect(
        entryRedirect(entry: EntryState.profileRequired, path: '/launch'),
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
            final next = entryRedirect(entry: entry, path: path);
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

  group('screenRegistry', () {
    test('page 화면만 있고 모두 IA id입니다', () {
      final pageIds = {
        for (final screen in iaScreens)
          if (screen.presentation == IaPresentation.page) screen.id,
      };
      expect(screenRegistry.keys.toSet(), pageIds);
      // 상태를 직접 처리하는 화면은 launch뿐입니다(나머지는 자리 표시).
      expect(
        {
          for (final spec in screenRegistry.values)
            if (spec.handledStates.isNotEmpty) spec.id,
        },
        {ScreenIds.launch},
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
        // 탭 바의 탭은 화면 이름(ko)으로 읽힙니다.
        expect(
          find.bySemanticsLabel(RegExp(['오늘', '달력', '일기', '나'][index])),
          findsWidgets,
        );
      }
      semantics.dispose();
    });
  });
}
