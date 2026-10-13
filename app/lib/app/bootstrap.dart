import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:myungli_diary/app/entry/entry_providers.dart';
import 'package:myungli_diary/app/licenses.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/api/fake/fake_server.dart';
import 'package:myungli_diary/core/api/fake/scenario.dart';
import 'package:myungli_diary/core/api/http_client.dart';
import 'package:myungli_diary/core/clock/clock.dart';
import 'package:myungli_diary/core/platform/crash_reporter.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';
import 'package:myungli_diary/core/storage/app_database.dart';

/// fake 모드에서 시나리오를 정하지 않았을 때 쓰는 시나리오.
const defaultScenarioId = 'new-user';

/// `--dart-define=SCENARIO=<id>`로 고르는 fake 모드 시작 시나리오.
const _scenarioFromEnvironment = String.fromEnvironment('SCENARIO');

var _fontLicensesRegistered = false;

/// 앱이 뜨기 전에 필요한 준비를 하고 앱 루트 [ProviderContainer]를 돌려줍니다.
///
/// 시간대 데이터, 글꼴 라이선스, 비정상 종료 핸들러를 준비하고 로컬 DB를 엽니다.
/// fake 모드에서는 [scenarioId](생략하면 `SCENARIO` dart-define, 그것도 없으면
/// [defaultScenarioId])의 시나리오와 대역 서버를 연결하고, 시나리오의 로그인 상태에
/// 맞춰 토큰을 심거나 비웁니다. 테스트는 [installErrorHandlers]를 꺼 테스트 틀의
/// 오류 처리를 지킵니다.
Future<ProviderContainer> bootstrap({
  ApiMode? mode,
  String? scenarioId,
  List<Override> overrides = const [],
  bool installErrorHandlers = true,
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  ensureTimeZonesInitialized();
  if (!_fontLicensesRegistered) {
    registerFontLicenses();
    _fontLicensesRegistered = true;
  }

  final resolvedMode = mode ?? apiModeFromEnvironment();
  final scenario = resolvedMode == ApiMode.fake
      ? await _pickScenario(scenarioId)
      : null;

  final container = ProviderContainer(
    overrides: [
      apiModeProvider.overrideWithValue(resolvedMode),
      ...entryOverrides,
      if (scenario != null) ...[
        scenarioProvider.overrideWithValue(scenario),
        fakeServerProvider.overrideWith(
          (ref) => ref.watch(fakeServerInterceptorProvider),
        ),
      ],
      ...overrides,
    ],
  );

  if (installErrorHandlers) {
    _installErrorHandlers(container.read(crashReporterProvider));
  }
  // 로컬 DB를 첫 화면 전에 엽니다(마이그레이션 실패를 시작 때 드러냅니다).
  container.read(appDatabaseProvider);
  if (scenario != null) {
    await _restoreScenarioSession(container, scenario);
  }
  return container;
}

Future<Scenario> _pickScenario(String? requestedId) async {
  final id = requestedId ?? _scenarioIdFromEnvironment();
  final scenarios = await loadScenarios(rootBundle);
  return scenarios.firstWhere(
    (scenario) => scenario.id == id,
    orElse: () => throw StateError(
      '없는 시나리오입니다: $id (있는 것: ${scenarios.map((s) => s.id).join(', ')})',
    ),
  );
}

String _scenarioIdFromEnvironment() => _scenarioFromEnvironment.isEmpty
    ? defaultScenarioId
    : _scenarioFromEnvironment;

/// 시나리오가 로그인 상태면 fixture의 refresh token을 심어, 앱을 다시 켠 것처럼
/// 세션 복원(refresh)이 일어나게 합니다. 아니면 토큰을 비웁니다.
Future<void> _restoreScenarioSession(
  ProviderContainer container,
  Scenario scenario,
) async {
  final tokens = container.read(tokenStoreProvider);
  if (!scenario.signedIn) {
    await tokens.clear();
    return;
  }
  await tokens.seedRefreshToken(await _fixtureRefreshToken(scenario));
}

Future<String> _fixtureRefreshToken(Scenario scenario) async {
  final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
  final assets = manifest.listAssets().toSet();
  for (final id in scenario.lineage) {
    final key = 'fixtures/$id/refreshToken.json';
    if (!assets.contains(key)) {
      continue;
    }
    final json = jsonDecode(await rootBundle.loadString(key));
    final body = json is Map<String, Object?> ? json['body'] : null;
    if (body is Map<String, Object?> && body['refreshToken'] is String) {
      return body['refreshToken']! as String;
    }
  }
  throw StateError('${scenario.id} 시나리오에 refreshToken fixture가 없습니다.');
}

/// 처리되지 않은 오류를 [CrashReporter]에 요약만 보냅니다(원본 오류는 넘기지 않음, D64).
void _installErrorHandlers(CrashReporter reporter) {
  FlutterError.onError = (details) {
    if (kDebugMode) {
      FlutterError.presentError(details);
    }
    reporter.record(
      CrashSummary.from(details.exception),
      details.stack ?? StackTrace.empty,
    );
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    reporter.record(CrashSummary.from(error), stack);
    return true;
  };
}
