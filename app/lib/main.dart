import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myungli_diary/app/bootstrap.dart';
import 'package:myungli_diary/app/dev/scenario_picker.dart';
import 'package:myungli_diary/app/myungli_app.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/api/http_client.dart';

Future<void> main() async {
  final container = await bootstrap();
  // debug의 fake 모드는 시나리오를 바꿔 다시 시작할 수 있는 개발용 최상위를 씁니다.
  final devMode = kDebugMode && container.read(apiModeProvider) == ApiMode.fake;
  runApp(
    devMode
        ? DevHost(initial: container)
        : UncontrolledProviderScope(
            container: container,
            child: const MyungliApp(),
          ),
  );
}
