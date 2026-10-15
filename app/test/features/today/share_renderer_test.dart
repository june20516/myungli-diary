import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/gen/model/day_kind.dart';
import 'package:myungli_diary/core/api/gen/model/rendered_text.dart';
import 'package:myungli_diary/core/api/gen/model/segment.dart';
import 'package:myungli_diary/design/components/today/share_image.dart';
import 'package:myungli_diary/features/today/application/share_renderer.dart';

const _red = Color(0xFFFF0000);

/// PNG를 디코딩해 크기와 [at] 위치의 색을 돌려줍니다.
Future<({int width, int height, Color pixel})> _decode(
  Uint8List png, {
  required Offset at,
}) async {
  final codec = await ui.instantiateImageCodec(png);
  final frame = await codec.getNextFrame();
  final image = frame.image;
  final data = (await image.toByteData())!;
  final offset = ((at.dy.toInt() * image.width) + at.dx.toInt()) * 4;
  final pixel = Color.fromARGB(
    data.getUint8(offset + 3),
    data.getUint8(offset),
    data.getUint8(offset + 1),
    data.getUint8(offset + 2),
  );
  return (width: image.width, height: image.height, pixel: pixel);
}

/// 정사각 PNG 왼쪽 아래(로고 자리)에 어두운 픽셀이 있는지.
Future<bool> _hasDarkPixel(Uint8List png) async {
  final codec = await ui.instantiateImageCodec(png);
  final image = (await codec.getNextFrame()).image;
  final data = (await image.toByteData())!;
  for (var y = image.height - 120; y < image.height - 60; y++) {
    for (var x = 72; x < 400; x++) {
      final offset = (y * image.width + x) * 4;
      final color = Color.fromARGB(
        255,
        data.getUint8(offset),
        data.getUint8(offset + 1),
        data.getUint8(offset + 2),
      );
      if (color.computeLuminance() < 0.4) return true;
    }
  }
  return false;
}

ShareImage _image(ShareImageVariant variant) => ShareImage(
  variant: variant,
  date: '10월 15일 목요일',
  dayKind: DayKind.yongsinDay,
  dayKindLabel: '좋은 날',
  sentence: RenderedText(segments: [Segment(text: '오늘은 좋은 날이에요.')]),
  items: const [],
  footer: '명리일기',
);

void main() {
  group('OffscreenShareRenderer', () {
    testWidgets('논리 크기에 pixelRatio 3을 곱한 PNG를 만듭니다', (tester) async {
      const renderer = OffscreenShareRenderer();
      final png = (await tester.runAsync(
        () => renderer.render(
          const ColoredBox(color: _red, child: SizedBox.expand()),
          const Size(360, 640),
        ),
      ))!;
      final decoded = (await tester.runAsync(
        () => _decode(png, at: const Offset(540, 960)),
      ))!;
      expect(decoded.width, 1080);
      expect(decoded.height, 1920);
      expect(decoded.pixel, _red);
    });

    testWidgets('pixelRatio를 바꿀 수 있습니다', (tester) async {
      const renderer = OffscreenShareRenderer(pixelRatio: 2);
      final png = (await tester.runAsync(
        () => renderer.render(
          const ColoredBox(color: _red, child: SizedBox.expand()),
          const Size(100, 50),
        ),
      ))!;
      final decoded = (await tester.runAsync(
        () => _decode(png, at: Offset.zero),
      ))!;
      expect((decoded.width, decoded.height), (200, 100));
    });

    testWidgets('비동기로 채워지는 내용(자산 로딩 등)이 끝난 뒤에 그립니다', (tester) async {
      const renderer = OffscreenShareRenderer();
      final png = (await tester.runAsync(
        () => renderer.render(
          FutureBuilder<Color>(
            future: Future<Color>.delayed(
              const Duration(milliseconds: 120),
              () => _red,
            ),
            builder: (_, snapshot) => ColoredBox(
              color: snapshot.data ?? const Color(0xFF00FF00),
              child: const SizedBox.expand(),
            ),
          ),
          const Size(40, 40),
        ),
      ))!;
      final decoded = (await tester.runAsync(
        () => _decode(png, at: const Offset(60, 60)),
      ))!;
      expect(decoded.pixel, _red);
    });

    testWidgets('화면 트리와 따로 그리므로 화면에 있는 위젯 수가 늘지 않습니다', (tester) async {
      await tester.pumpWidget(const SizedBox());
      final before = tester.allWidgets.length;
      await tester.runAsync(
        () => const OffscreenShareRenderer().render(
          const ColoredBox(color: _red),
          const Size(10, 10),
        ),
      );
      expect(tester.allWidgets.length, before);
    });

    for (final variant in ShareImageVariant.values) {
      testWidgets('${variant.name}: 공유 이미지는 폭 1080 PNG이고 기기와 상관없이 라이트입니다', (
        tester,
      ) async {
        // 기기가 다크여도 오프스크린 트리는 기기 설정을 받지 않습니다.
        tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
        addTearDown(tester.platformDispatcher.clearAllTestValues);
        final size = ShareImage.logicalSize(variant);
        final png = (await tester.runAsync(
          () => const OffscreenShareRenderer().render(
            ShareRenderHost(locale: const Locale('ko'), child: _image(variant)),
            size,
          ),
        ))!;
        // 왼쪽 위 모서리 가까이는 그라데이션 바탕입니다(글자 없음).
        final decoded = (await tester.runAsync(
          () => _decode(png, at: const Offset(6, 6)),
        ))!;
        expect(decoded.width, 1080);
        expect(decoded.height, (size.height * 3).round());
        expect(decoded.pixel.computeLuminance(), greaterThan(0.8));
      });
    }

    testWidgets('비동기로 읽는 로고 자산도 그린 뒤에 캡처합니다', (tester) async {
      final png = (await tester.runAsync(
        () => const OffscreenShareRenderer().render(
          ShareRenderHost(
            locale: const Locale('ko'),
            child: _image(ShareImageVariant.square),
          ),
          ShareImage.logicalSize(ShareImageVariant.square),
        ),
      ))!;
      // 로고는 왼쪽 아래에 있고 글자(footer)는 오른쪽에 있습니다. 왼쪽 아래에 어두운 점이 있어야 합니다.
      final dark = (await tester.runAsync(() => _hasDarkPixel(png)))!;
      expect(dark, isTrue);
    });

    testWidgets('렌더 중 던진 오류는 호출한 쪽으로 전해집니다', (tester) async {
      final result = tester.runAsync(
        () => const OffscreenShareRenderer()
            .render(const _Boom(), const Size(10, 10))
            .then<Object?>((_) => null, onError: (Object e) => e),
      );
      expect(await result, isA<StateError>());
    });
  });
}

class _Boom extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => throw StateError('렌더 실패');
}
