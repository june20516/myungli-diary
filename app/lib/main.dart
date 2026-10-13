import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myungli_diary/app/bootstrap.dart';
import 'package:myungli_diary/app/bootstrap_failure_app.dart';
import 'package:myungli_diary/app/dev/scenario_picker.dart';
import 'package:myungli_diary/app/myungli_app.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/api/http_client.dart';

Future<void> main() async {
  final ProviderContainer container;
  try {
    container = await bootstrap();
  } on Object catch (error, stack) {
    // 오류 요약 보고는 bootstrap이 합니다(컨테이너가 있을 때). 화면은 안내만 보입니다.
    if (kDebugMode) {
      debugPrint('bootstrap 실패: $error\n$stack');
    }
    runApp(const BootstrapFailureApp());
    return;
  }
  // debug의 fake 모드는 시나리오를 바꿔 다시 시작할 수 있는 개발용 최상위를 씁니다.
  final devMode = kDebugMode && container.read(apiModeProvider) == ApiMode.fake;
  runApp(
    devMode
        ? DevHost(
            initial: container,
            createContainer: (scenarioId) =>
                bootstrap(mode: ApiMode.fake, scenarioId: scenarioId),
          )
        : UncontrolledProviderScope(
            container: container,
            child: const MyungliApp(),
          ),
  );
}
