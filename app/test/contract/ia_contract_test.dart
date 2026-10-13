import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:myungli_diary/app/entry/entry_providers.dart';
import 'package:myungli_diary/app/entry/entry_state.dart';
import 'package:myungli_diary/app/router/app_router.dart';
import 'package:myungli_diary/app/router/screen_registry.dart';

import 'ia_pending.dart';

/// 실제 플랫폼 의존 없이 라우터를 만들기 위한 고정 진입 상태.
class _FixedEntry extends EntryController {
  @override
  Future<EntrySnapshot> build() async =>
      const EntrySnapshot(EntryState.ready, null);
}

/// 원본 IA JSON에서 읽은 화면 하나.
class _IaEntry {
  new(Map<String, Object?> json)
    : id = json['id']! as String,
      presentation = json['presentation']! as String,
      states = {
        for (final state in json['states']! as List<Object?>)
          (state! as Map<String, Object?>)['id']! as String,
      },
      components = {
        for (final component in json['components']! as List<Object?>)
          component! as String,
      };

  final String id;
  final String presentation;
  final Set<String> states;
  final Set<String> components;
}

/// route 트리를 순회해 이름 집합을 얻습니다.
Set<String> _routeNames(List<RouteBase> routes) => {
  for (final route in routes) ...[
    if (route is GoRoute && route.name != null) route.name!,
    ..._routeNames(route.routes),
    if (route is StatefulShellRoute)
      for (final branch in route.branches) ..._routeNames(branch.routes),
  ],
};

/// 탭 루트 route 이름 목록(branch 순서). 각 branch 최상위 route의 이름입니다.
///
/// 이름 없는 탭 루트가 있으면 무엇이 틀렸는지 알 수 있게 그 경로로 실패합니다.
List<String> _tabRootNames(List<RouteBase> routes) => [
  for (final route in routes)
    if (route is StatefulShellRoute)
      for (final branch in route.branches)
        if (branch.routes.first case final GoRoute root) _nameOf(root),
];

String _nameOf(GoRoute root) {
  final name = root.name;
  expect(name, isNotNull, reason: '탭 루트 ${root.path}에 route 이름(IA id)이 없습니다');
  return name!;
}

void main() {
  final json =
      jsonDecode(File('../docs/ia/screens.json').readAsStringSync())!
          as Map<String, Object?>;
  final screens = [
    for (final screen in json['screens']! as List<Object?>)
      _IaEntry(screen! as Map<String, Object?>),
  ];
  final screenIds = {for (final screen in screens) screen.id};
  final tabRootList = [
    for (final tab in json['tabs']! as List<Object?>)
      (tab! as Map<String, Object?>)['root']! as String,
  ];
  final tabRoots = tabRootList.toSet();

  late ProviderContainer container;
  late List<RouteBase> routes;

  setUp(() {
    container = ProviderContainer(
      overrides: [entryStateProvider.overrideWith(_FixedEntry.new)],
    );
    addTearDown(container.dispose);
    routes = container.read(routerProvider).configuration.routes;
  });

  test('page 화면마다 route가 있고 그 밖의 route는 없다', () {
    final pageIds = {
      for (final screen in screens)
        if (screen.presentation == 'page') screen.id,
    };
    expect(_routeNames(routes), pageIds);
  });

  test('탭 루트 4곳이 IA tabs[].root와 같다', () {
    expect(tabRoots, hasLength(4));
    expect(_tabRootNames(routes).toSet(), tabRoots);
  });

  test('탭 순서가 IA tabs 배열 순서와 같다', () {
    expect(_tabRootNames(routes), tabRootList);
  });

  test('pending이 아닌 화면은 handledStates가 IA states와 같다', () {
    for (final screen in screens) {
      if (pendingStateScreens.contains(screen.id)) {
        continue;
      }
      final handled = screenRegistry[screen.id]?.handledStates ?? <String>{};
      expect(handled, screen.states, reason: '${screen.id} 상태 처리 불일치');
    }
  });

  test('pendingStateScreens의 id가 모두 IA에 실재한다', () {
    expect(pendingStateScreens.difference(screenIds), isEmpty);
  });

  test('ratchet: 상태 처리를 마친 화면은 pending에서 빠져 있다', () {
    final finished = {
      for (final screen in screens)
        if (pendingStateScreens.contains(screen.id) &&
            setEquals(
              screenRegistry[screen.id]?.handledStates ?? <String>{},
              screen.states,
            ))
          screen.id,
    };
    expect(finished, isEmpty, reason: 'pendingStateScreens에서 지우세요');
  });

  test('ad-banner는 탭 루트 4곳에만 있다 (D53)', () {
    final withBanner = {
      for (final screen in screens)
        if (screen.components.contains('ad-banner')) screen.id,
    };
    expect(withBanner, {'today', 'calendar', 'diary-list', 'my-saju'});
    expect(withBanner, tabRoots);
  });
}
