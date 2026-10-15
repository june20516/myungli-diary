import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/rendering/offscreen_renderer.dart';

const _red = Color(0xFFFF0000);
const _green = Color(0xFF00FF00);
const _renderer = PngOffscreenRenderer();

/// PNG를 디코딩해 크기와 [at] 위치의 색을 돌려줍니다.
Future<({int width, int height, Color pixel})> _decode(
  Uint8List png, {
  Offset at = Offset.zero,
}) async {
  final codec = await ui.instantiateImageCodec(png);
  final image = (await codec.getNextFrame()).image;
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

/// [delay] 뒤에 [color]로 바뀌는 위젯(비동기 내용 흉내).
Widget _delayed(Duration delay, Color color) => FutureBuilder<Color>(
  future: Future<Color>.delayed(delay, () => color),
  builder: (_, snapshot) => ColoredBox(
    color: snapshot.data ?? const Color(0xFF0000FF),
    child: const SizedBox.expand(),
  ),
);

/// 오류를 기록만 하는 전역 handler로 바꾸고, 끝나면 원래 함수로 돌립니다.
List<FlutterErrorDetails> _recordErrors() {
  final original = FlutterError.onError;
  final recorded = <FlutterErrorDetails>[];
  FlutterError.onError = recorded.add;
  addTearDown(() => FlutterError.onError = original);
  return recorded;
}

void main() {
  group('PngOffscreenRenderer', () {
    testWidgets('논리 크기에 pixelRatio 3을 곱한 PNG를 만듭니다', (tester) async {
      final png = (await tester.runAsync(
        () => _renderer.render(
          const ColoredBox(color: _red, child: SizedBox.expand()),
          const Size(360, 640),
        ),
      ))!;
      final decoded = (await tester.runAsync(
        () => _decode(png, at: const Offset(540, 960)),
      ))!;
      expect((decoded.width, decoded.height), (1080, 1920));
      expect(decoded.pixel, _red);
    });

    testWidgets('pixelRatio를 바꿀 수 있습니다', (tester) async {
      final png = (await tester.runAsync(
        () => const PngOffscreenRenderer(pixelRatio: 2).render(
          const ColoredBox(color: _red, child: SizedBox.expand()),
          const Size(100, 50),
        ),
      ))!;
      final decoded = (await tester.runAsync(() => _decode(png)))!;
      expect((decoded.width, decoded.height), (200, 100));
    });

    testWidgets('비동기로 채워지는 내용이 끝난 뒤에 그립니다', (tester) async {
      final png = (await tester.runAsync(
        () => _renderer.render(
          _delayed(const Duration(milliseconds: 120), _red),
          const Size(40, 40),
        ),
      ))!;
      final decoded = (await tester.runAsync(
        () => _decode(png, at: const Offset(60, 60)),
      ))!;
      expect(decoded.pixel, _red);
    });

    testWidgets('성공해도 전역 FlutterError.onError는 원래 함수 그대로입니다', (tester) async {
      _recordErrors();
      final before = FlutterError.onError;
      await tester.runAsync(
        () =>
            _renderer.render(const ColoredBox(color: _red), const Size(10, 10)),
      );
      expect(identical(FlutterError.onError, before), isTrue);
    });

    testWidgets(
      'build가 실패하면 OffscreenRenderFailure이고, 오류는 원래 handler로 가며 원복됩니다',
      (tester) async {
        final recorded = _recordErrors();
        final before = FlutterError.onError;
        final result = await tester.runAsync(
          () => _renderer
              .render(const _Boom(), const Size(10, 10))
              .then<Object?>((_) => null, onError: (Object e) => e),
        );
        expect(result, isA<OffscreenRenderFailure>());
        // 가로채지 않으므로 Flutter 기본 경로(원래 handler)가 실패를 받았습니다.
        expect(recorded.map((d) => d.exception), contains(isA<StateError>()));
        expect(identical(FlutterError.onError, before), isTrue);
      },
    );

    testWidgets('겹쳐 부른 렌더는 차례로 끝나고 handler는 그대로입니다', (tester) async {
      _recordErrors();
      final before = FlutterError.onError;
      final finished = <String>[];
      final results = await tester.runAsync(() async {
        // 앞 렌더(느림)가 먼저 끝나야 뒤 렌더(빠름)가 시작됩니다.
        final slow = _renderer
            .render(
              _delayed(const Duration(milliseconds: 150), _red),
              const Size(20, 20),
            )
            .then((png) {
              finished.add('slow');
              return png;
            });
        final fast = _renderer
            .render(_delayed(Duration.zero, _green), const Size(20, 20))
            .then((png) {
              finished.add('fast');
              return png;
            });
        return [await slow, await fast];
      });
      expect(finished, ['slow', 'fast']);
      final slowPixel = (await tester.runAsync(
        () => _decode(results![0], at: const Offset(30, 30)),
      ))!;
      final fastPixel = (await tester.runAsync(
        () => _decode(results![1], at: const Offset(30, 30)),
      ))!;
      expect(slowPixel.pixel, _red);
      expect(fastPixel.pixel, _green);
      expect(identical(FlutterError.onError, before), isTrue);
    });

    testWidgets('앞 렌더가 실패해도 뒤 렌더는 이어서 합니다', (tester) async {
      _recordErrors();
      final outcomes = await tester.runAsync(() async {
        final failed = _renderer
            .render(const _Boom(), const Size(10, 10))
            .then<Object?>((_) => null, onError: (Object e) => e);
        final ok = _renderer.render(
          const ColoredBox(color: _red),
          const Size(10, 10),
        );
        return (await failed, await ok);
      });
      expect(outcomes!.$1, isA<OffscreenRenderFailure>());
      expect(outcomes.$2, isNotEmpty);
    });

    testWidgets('렌더하는 동안 화면 쪽에서 난 오류는 원래 handler로 갑니다', (tester) async {
      final recorded = _recordErrors();
      await tester.runAsync(() async {
        final render = _renderer.render(
          _delayed(const Duration(milliseconds: 100), _red),
          const Size(10, 10),
        );
        await Future<void>.delayed(const Duration(milliseconds: 40));
        FlutterError.reportError(
          const FlutterErrorDetails(exception: '화면 트리에서 난 오류'),
        );
        await render;
      });
      expect(recorded.map((d) => d.exception), ['화면 트리에서 난 오류']);
    });
  });
}

class _Boom extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => throw StateError('렌더 실패');
}
