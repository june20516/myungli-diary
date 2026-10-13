import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:myungli_diary/app/entry/entry_providers.dart';
import 'package:myungli_diary/app/entry/entry_state.dart';
import 'package:myungli_diary/app/router/screen_breadcrumbs.dart';
import 'package:myungli_diary/app/router/screen_registry.dart';
import 'package:myungli_diary/app/router/tab_shell.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/ia/ia_model.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';
import 'package:myungli_diary/design/components/frame/sheet.dart';

/// IA 화면 id의 경로.
String pathOf(String screenId) => '/$screenId';

final Map<String, IaScreen> _screensById = {
  for (final screen in iaScreens) screen.id: screen,
};

const Set<String> _onboardingIds = {
  ScreenIds.onboardCall,
  ScreenIds.onboardBirth,
  ScreenIds.onboardTime,
  ScreenIds.onboardGender,
  ScreenIds.birthplace,
  ScreenIds.legal,
};

const Set<String> _consentIds = {ScreenIds.consent, ScreenIds.legal};

/// 갈래마다 처음 보낼 화면. 광고 동의 전은 화면이 없어 ready와 같습니다.
String _homeOf(EntryState entry) => switch (entry) {
  EntryState.forceUpdate => pathOf(ScreenIds.forceUpdate),
  EntryState.signedOut => pathOf(ScreenIds.welcome),
  EntryState.consentRequired => pathOf(ScreenIds.consent),
  EntryState.profileRequired => pathOf(ScreenIds.onboardCall),
  EntryState.adConsentRequired || EntryState.ready => pathOf(ScreenIds.today),
};

/// [path]에서 [entry] 갈래가 보낼 곳. 그대로 두면 null입니다.
///
/// [entry]가 null이면 아직 계산 전이거나 실패한 것이라 launch에 모읍니다.
/// 규칙마다 허용 목록 안의 경로는 그대로 두므로 redirect가 루프를 만들지 않습니다.
String? entryRedirect({required EntryState? entry, required String path}) {
  final launch = pathOf(ScreenIds.launch);
  if (entry == null) {
    return path == launch ? null : launch;
  }
  final id = path.startsWith('/') ? path.substring(1) : path;
  final screen = _screensById[id];
  if (screen == null) {
    return null;
  }
  if (id == ScreenIds.launch) {
    return _homeOf(entry);
  }
  final home = _homeOf(entry);
  return switch (entry) {
    EntryState.forceUpdate => id == ScreenIds.forceUpdate ? null : home,
    EntryState.signedOut => screen.auth == IaAuth.member ? home : null,
    EntryState.consentRequired => _consentIds.contains(id) ? null : home,
    EntryState.profileRequired => _onboardingIds.contains(id) ? null : home,
    EntryState.adConsentRequired ||
    EntryState.ready => screen.auth == IaAuth.guest ? home : null,
  };
}

/// IA에 없는 경로(예 App Link `/auth/apple`)가 들어왔을 때 보낼 곳.
///
/// 계산 전이면 launch, 아니면 갈래의 첫 화면입니다. `/auth/apple` 복귀는 계획 7에서
/// 전용 처리로 이 경로보다 먼저 가로챕니다.
String unknownPathTarget(EntryState? entry) =>
    entry == null ? pathOf(ScreenIds.launch) : _homeOf(entry);

/// 탭 루트는 셸이 [SheetScreenBelow]로 감싸므로, 그 밖의 화면만 [wrap]으로 감쌉니다.
GoRoute _routeOf(String id, {bool wrap = false}) => GoRoute(
  name: id,
  path: pathOf(id),
  builder: (context, state) {
    final screen = screenRegistry[id]!.builder(context);
    return wrap ? SheetScreenBelow(child: screen) : screen;
  },
);

/// 앱 라우터를 만듭니다. 경로와 이름은 IA 화면 id입니다.
GoRouter buildRouter(Ref ref) {
  final refresh = ValueNotifier<int>(0);
  ref
    ..listen(entryProvider, (_, _) => refresh.value++)
    ..onDispose(refresh.dispose);

  final tabRootSet = tabRoots.toSet();
  final otherPages = [
    for (final id in screenRegistry.keys)
      if (!tabRootSet.contains(id)) _routeOf(id, wrap: true),
  ];

  final router = GoRouter(
    initialLocation: pathOf(ScreenIds.launch),
    refreshListenable: refresh,
    redirect: (context, state) =>
        entryRedirect(entry: ref.read(entryProvider), path: state.uri.path),
    // 기본 오류 페이지 대신 갈래의 첫 화면으로 보냅니다.
    onException: (context, state, router) =>
        router.go(unknownPathTarget(ref.read(entryProvider))),
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) =>
            TabShell(shell, path: state.uri.path),
        branches: [
          for (final id in tabRoots)
            StatefulShellBranch(routes: [_routeOf(id)]),
        ],
      ),
      ...otherPages,
    ],
  );
  final stopBreadcrumbs = listenScreenBreadcrumbs(
    router,
    ref.read(crashReporterProvider),
  );
  ref
    ..onDispose(stopBreadcrumbs)
    ..onDispose(router.dispose);
  return router;
}

/// 앱 라우터.
final routerProvider = Provider<GoRouter>(buildRouter);
