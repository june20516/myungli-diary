@Tags(['contract'])
library;

// 스토어 이미지 명세(design `store.json`)와 원고(writing `listing.json`)가
// app 생성 명령과 맞는지(#1203, D133).
// 이미지는 만들지 않습니다. 명세나 원고가 바뀌어 생성이 깨질 일을 PR 검사에서 먼저 알립니다.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../support/golden.dart';
import 'store_frames.dart';
import 'store_scenes.dart';

void main() {
  final spec = StoreSpec.load();
  final captions = loadCaptions();
  final scenarioIds = {
    for (final entry in (jsonDecode(
      File('fixtures/scenarios.json').readAsStringSync(),
    ) as List).cast<Map<String, dynamic>>())
      entry['id'] as String,
  };

  test('장면마다 여는 방법과 언어별 데모 시나리오가 있습니다', () {
    for (final scene in spec.scenes) {
      expect(
        sceneOpeners.containsKey((scene.screen, scene.state)),
        isTrue,
        reason: '${scene.id}: ${scene.screen} ${scene.state}을 여는 방법이 없습니다',
      );
      for (final language in spec.locales) {
        final scenario = scene.scenarioFor(language);
        expect(scenarioIds, contains(scenario), reason: scene.id);
        expect(Directory('fixtures/$scenario').existsSync(), isTrue);
      }
    }
  });

  test('언어마다 장면 글이 모두 있습니다', () {
    for (final language in spec.locales) {
      expect(
        captions[language]?.keys,
        unorderedEquals(spec.scenes.map((scene) => scene.id)),
        reason: language,
      );
    }
  });

  testWidgets('글이 두 틀의 글 자리에 들어갑니다(실제 글꼴로 잼)', (tester) async {
    await tester.runAsync(ensureGoldenFonts);
    final failures = <String>[];
    for (final language in spec.locales) {
      for (final scene in spec.scenes) {
        for (final frame in spec.frames) {
          final overflow = captionOverflow(
            spec,
            frame,
            language,
            captions[language]![scene.id]!,
          );
          if (overflow != null) {
            failures.add('$language ${scene.id} ${frame.key}: $overflow');
          }
        }
      }
    }
    expect(failures, isEmpty);
  });
}
