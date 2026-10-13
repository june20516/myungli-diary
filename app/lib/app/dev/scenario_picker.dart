import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myungli_diary/app/bootstrap.dart';
import 'package:myungli_diary/app/myungli_app.dart';
import 'package:myungli_diary/app/router/app_router.dart';
import 'package:myungli_diary/core/api/fake/fake_server.dart';
import 'package:myungli_diary/core/api/fake/scenario.dart';
import 'package:myungli_diary/core/storage/app_database.dart';

// 개발 메뉴는 debug 빌드의 fake 모드에서만 쓰며(호출하는 쪽이 `kDebugMode`로 가름)
// 사용자에게 보이지 않으므로 문구를 ARB로 옮기지 않습니다.

/// 개발 메뉴에서 시나리오를 바꿔 앱을 다시 시작하는 함수를 하위에 줍니다.
class DevRestartScope extends InheritedWidget {
  /// [restart]를 하위에 줍니다.
  const new({required this.restart, required super.child, super.key});

  /// 시나리오 `scenarioId`로 앱을 처음부터 다시 시작합니다.
  final Future<void> Function(String scenarioId) restart;

  /// 가장 가까운 범위. 없으면 null입니다.
  static DevRestartScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DevRestartScope>();

  @override
  bool updateShouldNotify(DevRestartScope oldWidget) => false;
}

/// debug fake 모드의 앱 최상위: 컨테이너를 들고 있다가 시나리오가 바뀌면 새로 만듭니다.
class DevHost extends StatefulWidget {
  /// [initial] 컨테이너로 시작하고, 시나리오가 바뀌면 [createContainer]로 새로 만듭니다.
  const new({required this.initial, required this.createContainer, super.key});

  /// 처음 쓸 컨테이너.
  final ProviderContainer initial;

  /// 시나리오 id의 컨테이너를 만듭니다(`bootstrap`).
  final Future<ProviderContainer> Function(String scenarioId) createContainer;

  @override
  State<DevHost> createState() => _DevHostState();
}

class _DevHostState extends State<DevHost> {
  ProviderContainer? _container;
  Object? _failure;

  @override
  void initState() {
    super.initState();
    _container = widget.initial;
  }

  @override
  void dispose() {
    _container?.dispose();
    super.dispose();
  }

  Future<void> _restart(String scenarioId) async {
    final old = _container;
    setState(() {
      _container = null;
      _failure = null;
    });
    if (old != null) {
      await disposeClosingDatabase(old);
    }
    try {
      final next = await widget.createContainer(scenarioId);
      if (!mounted) {
        next.dispose();
        return;
      }
      setState(() => _container = next);
    } on Object catch (error) {
      if (mounted) {
        setState(() => _failure = error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final container = _container;
    if (container == null) {
      return _DevStatus(failure: _failure, onRestart: _restart);
    }
    return UncontrolledProviderScope(
      key: ObjectKey(container),
      container: container,
      child: DevRestartScope(restart: _restart, child: const MyungliApp()),
    );
  }
}

/// 다시 시작하는 동안(또는 실패했을 때)의 화면. 검은 화면을 남기지 않습니다.
class _DevStatus extends StatelessWidget {
  const new({required this.failure, required this.onRestart});

  final Object? failure;
  final Future<void> Function(String scenarioId) onRestart;

  @override
  Widget build(BuildContext context) {
    final error = failure;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        color: const Color(0xFFFFFFFF),
        child: Center(
          child: error == null
              ? const Text('시나리오를 다시 시작하는 중')
              : Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('시나리오를 시작하지 못했습니다'),
                      Text('$error'),
                      GestureDetector(
                        onTap: () => unawaited(onRestart(defaultScenarioId)),
                        child: const Text('기본 시나리오로 다시 시작'),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

/// 상태 표시줄 왼쪽 위 칸을 길게 누르면 시나리오 목록을 엽니다.
///
/// 상태 표시줄 칸은 화면 내용이 쓰지 않는 자리이고, 길게 누르기만 듣는 투명 칸이라
/// 일반 터치를 막지 않습니다.
class DevMenuTrigger extends ConsumerWidget {
  /// [child] 위에 투명 칸을 겹칩니다.
  const new({required this.child, super.key});

  /// 앱 내용.
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final height = math.max(MediaQuery.paddingOf(context).top, 24).toDouble();
    return Stack(
      textDirection: TextDirection.ltr,
      children: [
        child,
        Positioned(
          left: 0,
          top: 0,
          width: 96,
          height: height,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onLongPress: () {
              // builder 컨텍스트는 Navigator 위라 라우터의 Navigator에서 엽니다.
              final navigatorContext = ref
                  .read(routerProvider)
                  .routerDelegate
                  .navigatorKey
                  .currentContext;
              if (navigatorContext != null) {
                unawaited(
                  showModalBottomSheet<void>(
                    context: navigatorContext,
                    builder: (_) => _ScenarioList(
                      current: ref.read(scenarioProvider).id,
                      restart: DevRestartScope.maybeOf(context)?.restart,
                    ),
                  ),
                );
              }
            },
          ),
        ),
      ],
    );
  }
}

class _ScenarioList extends StatefulWidget {
  const new({required this.current, required this.restart});

  final String current;
  final Future<void> Function(String scenarioId)? restart;

  @override
  State<_ScenarioList> createState() => _ScenarioListState();
}

class _ScenarioListState extends State<_ScenarioList> {
  late final Future<List<Scenario>> _scenarios = loadScenarios(rootBundle);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: FutureBuilder<List<Scenario>>(
        future: _scenarios,
        builder: (context, snapshot) {
          final scenarios = snapshot.data;
          if (scenarios == null) {
            return const SizedBox(height: 120);
          }
          return ListView(
            shrinkWrap: true,
            children: [
              const ListTile(title: Text('시나리오를 바꾸고 다시 시작')),
              for (final scenario in scenarios)
                ListTile(
                  title: Text(scenario.id),
                  subtitle: Text('${scenario.today} ${scenario.timezone}'),
                  selected: scenario.id == widget.current,
                  onTap: () {
                    Navigator.of(context).pop();
                    unawaited(widget.restart?.call(scenario.id));
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}

/// [container]를 닫고, 그 컨테이너가 연 로컬 DB가 있으면 연결이 닫힐 때까지 기다립니다.
///
/// 같은 DB 파일을 새 컨테이너가 열기 전에 부릅니다. DB provider를 만든 적이 없으면
/// 닫으려고 새로 만들지 않습니다.
Future<void> disposeClosingDatabase(ProviderContainer container) async {
  final database = container.exists(appDatabaseProvider)
      ? container.read(appDatabaseProvider)
      : null;
  container.dispose();
  await database?.close();
}
