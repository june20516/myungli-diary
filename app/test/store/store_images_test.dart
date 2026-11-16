@Tags(['contract'])
library;

// 스토어 이미지 생성(#1203, D133). `tool/store_images_linux.sh`가 Docker(golden과 같은 Linux 렌더)에서
// MYUNGLI_STORE=1로 돌려 build/store/에 씁니다. 평소 테스트와 CI에서는 건너뜁니다.
//
// 명세(`store.json`)의 장면을 언어마다 그 언어 데모 응답(`store-<언어>`, `tool/store_fixtures.sh`)으로
// 찍어 두 틀(App Store, Play)에 합성하고, Play 그래픽 이미지 한 장을 만듭니다.
//
// 산출물:
// * build/store/<언어>/<틀>/<순서>-<장면>.png (틀: appStore 1320×2868, play 1080×1920)
// * build/store/play-feature-graphic.png (1024×500, 세 언어 같은 한 장)
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/platform/fakes.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';

import '../support/app_harness.dart';
import '../support/golden.dart';
import 'store_frames.dart';
import 'store_scenes.dart';

final bool _enabled = Platform.environment['MYUNGLI_STORE'] == '1';

/// 산출물 폴더. 스크립트가 이 폴더를 꺼내 갑니다.
const String _outDir = 'build/store';

/// [image]를 [path]에 PNG로 씁니다.
Future<void> _writePng(ui.Image image, String path) async {
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(bytes!.buffer.asUint8List());
}

void main() {
  final spec = StoreSpec.load();
  final captions = loadCaptions();

  for (final language in spec.locales) {
    for (final scene in spec.scenes) {
      testWidgets('${scene.order}-${scene.id} $language', (tester) async {
        await tester.runAsync(ensureGoldenFonts);
        // 산출물에 디버그 띠를 찍지 않습니다.
        WidgetsApp.debugAllowBannerOverride = false;
        addTearDown(() => WidgetsApp.debugAllowBannerOverride = true);
        tester.view
          ..devicePixelRatio = spec.pixelRatio
          ..physicalSize = spec.logicalSize * spec.pixelRatio;
        addTearDown(tester.view.reset);

        final container = await pumpApp(
          tester,
          scenario: scene.scenarioFor(language),
          locale: Locale(language),
          // 탭 화면 아래 배너 광고 자리는 빼고 찍습니다(명세 렌더 조건).
          overrides: [
            adsProvider.overrideWithValue(FakeAds(bannerAvailable: false)),
          ],
        );
        await sceneOpeners[(scene.screen, scene.state)]!(tester, container);

        final caption = captions[language]![scene.id]!;
        final element = tester.element(find.byType(MaterialApp));
        await tester.runAsync(() async {
          final screen = await captureImage(element);
          for (final frame in spec.frames) {
            final image = await composeFrame(
              spec,
              frame,
              language,
              caption,
              screen,
            );
            await _writePng(
              image,
              '$_outDir/$language/${frame.key}/${scene.order}-${scene.id}.png',
            );
            image.dispose();
          }
          screen.dispose();
        });
        // 남은 타이머(toast 등)를 흘려보냅니다.
        await tester.pump(const Duration(seconds: 5));
        await settleWithIo(tester, allowOngoing: true);
      }, skip: !_enabled);
    }
  }

  test('Play 그래픽 이미지', () async {
    final codec = await ui.instantiateImageCodec(
      File(spec.featureLogoPath).readAsBytesSync(),
    );
    final logo = (await codec.getNextFrame()).image;
    final image = await composeFeatureGraphic(spec, logo);
    await _writePng(image, '$_outDir/play-feature-graphic.png');
    image.dispose();
    logo.dispose();
  }, skip: !_enabled);
}
