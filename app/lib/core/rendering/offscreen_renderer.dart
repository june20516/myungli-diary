import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 위젯을 화면 밖에서 그려 PNG로 만드는 일반 도구입니다(위젯 종류를 가리지 않습니다).
///
/// 공유 이미지뿐 아니라 다른 화면(계획 4~6)과 테스트도 같은 모양으로 씁니다. 방향·언어·
/// 테마는 그리는 위젯이 스스로 갖추거나 호출한 쪽이 감싸 넘깁니다.
abstract interface class OffscreenRenderer {
  /// [widget]을 [logicalSize] 논리 크기로 그린 PNG 바이트를 돌려줍니다.
  ///
  /// 그리다 위젯 build가 실패하면 [OffscreenRenderFailure]를 던집니다.
  Future<Uint8List> render(Widget widget, Size logicalSize);
}

/// 화면 밖 위젯 build가 실패해 오류 위젯으로 바뀐 경우.
///
/// 오류 자체는 Flutter 기본 경로(`FlutterError.onError`)로도 보고됩니다.
final class OffscreenRenderFailure implements Exception {
  /// 오류 위젯의 [message]를 담습니다.
  const new(this.message);

  /// 오류 위젯이 보인 설명.
  final String message;

  @override
  String toString() => 'OffscreenRenderFailure: $message';
}

/// 렌더 전체(대기·캡처·인코딩)가 상한을 넘겨 포기한 경우.
final class OffscreenRenderTimeout implements Exception {
  /// 시간 초과 오류를 만듭니다.
  const new();

  @override
  String toString() => 'OffscreenRenderTimeout';
}

/// 화면 밖 `RepaintBoundary`에 그려 PNG로 만드는 [OffscreenRenderer]입니다.
///
/// 화면 트리와 따로 렌더 트리를 잠깐 만들어 `logicalSize`로 배치하고, 자산·글꼴 같은 비동기
/// 내용이 채워질 때까지(다시 build·layout·paint할 일이 150ms 없을 때, 최대 3초) 기다린 뒤
/// `pixelRatio` 배로 캡처합니다. 폭 360 논리 픽셀 x 3 = 1080입니다. 전역 오류 handler는
/// 건드리지 않고, 그린 뒤 트리에 남은 오류 위젯으로 실패를 판정합니다.
///
/// 실패 판정은 위젯 build 오류(`ErrorWidget`)로만 합니다. layout·paint·이미지 로드 오류는
/// 판정하지 않고 그 상태 그대로 캡처됩니다(전역 오류 handler를 가로채지 않는 절충).
///
/// 렌더는 한 번에 하나씩 차례로 합니다(겹쳐 부르면 앞 렌더가 끝난 뒤에 시작). 렌더 전체에
/// [renderTimeout] 상한이 있어, 끝나지 않는 렌더가 뒤 렌더를 영원히 막지 않습니다.
final class PngOffscreenRenderer implements OffscreenRenderer {
  /// 렌더러를 만듭니다. [pixelRatio]는 논리 픽셀당 실제 픽셀 수입니다.
  const new({
    this.pixelRatio = 3,
    this.renderTimeout = const Duration(seconds: 10),
  });

  /// 논리 픽셀당 실제 픽셀 수.
  final double pixelRatio;

  /// 렌더 전체(대기·캡처·인코딩)의 상한. 넘으면 [OffscreenRenderTimeout]으로 끝납니다.
  final Duration renderTimeout;

  static const Duration _tick = Duration(milliseconds: 25);
  static const int _quietTicks = 6;
  static const Duration _timeout = Duration(seconds: 3);

  /// 직전에 시작한 렌더의 끝(성공이든 실패든). 다음 렌더가 이어서 시작합니다.
  static Future<void> _inFlight = Future<void>.value();

  @override
  Future<Uint8List> render(Widget widget, Size logicalSize) {
    final result = _inFlight.then((_) {
      final run = _renderOnce(widget, logicalSize);
      // 시간 초과 뒤에 이어서 끝나는 렌더의 결과·오류는 버립니다.
      return run.timeout(
        renderTimeout,
        onTimeout: () => throw const OffscreenRenderTimeout(),
      );
    });
    _inFlight = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  Future<Uint8List> _renderOnce(Widget widget, Size logicalSize) async {
    final boundary = RenderRepaintBoundary();
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final positioned = RenderPositionedBox(child: boundary);
    final constraints = BoxConstraints.tight(logicalSize);
    final renderView = RenderView(
      view: view,
      configuration: ViewConfiguration(
        logicalConstraints: constraints,
        physicalConstraints: constraints,
      ),
      child: positioned,
    );
    var visualUpdateRequested = false;
    final pipelineOwner = PipelineOwner(
      onNeedVisualUpdate: () => visualUpdateRequested = true,
    )..rootNode = renderView;
    renderView.prepareInitialFrame();

    var rebuildRequested = false;
    final focusManager = FocusManager();
    final buildOwner = BuildOwner(
      focusManager: focusManager,
      onBuildScheduled: () => rebuildRequested = true,
    );

    RenderObjectToWidgetElement<RenderBox>? root;
    void pumpFrame() {
      buildOwner
        ..buildScope(root!)
        ..finalizeTree();
      pipelineOwner
        ..flushLayout()
        ..flushCompositingBits()
        ..flushPaint();
    }

    try {
      root = RenderObjectToWidgetAdapter<RenderBox>(
        container: boundary,
        child: SizedBox.fromSize(size: logicalSize, child: widget),
      ).attachToRenderTree(buildOwner);
      pumpFrame();

      final deadline = DateTime.now().add(_timeout);
      var quiet = 0;
      while (quiet < _quietTicks) {
        if (!DateTime.now().isBefore(deadline)) {
          if (kDebugMode) {
            debugPrint(
              '화면 밖 렌더가 ${_timeout.inSeconds}초 안에 잠잠해지지 않아 그대로 캡처합니다.',
            );
          }
          break;
        }
        await Future<void>.delayed(_tick);
        if (rebuildRequested || visualUpdateRequested) {
          rebuildRequested = false;
          visualUpdateRequested = false;
          quiet = 0;
          pumpFrame();
        } else {
          quiet++;
        }
      }
      final failure = _findErrorWidget(root);
      if (failure != null) {
        throw OffscreenRenderFailure(failure.message);
      }

      final captured = await boundary.toImage(pixelRatio: pixelRatio);
      try {
        final data = await captured.toByteData(format: ui.ImageByteFormat.png);
        if (data == null) {
          throw StateError('이미지를 PNG로 바꾸지 못했습니다.');
        }
        return data.buffer.asUint8List();
      } finally {
        captured.dispose();
      }
    } finally {
      try {
        // 트리를 걷어 냅니다.
        if (root != null) {
          RenderObjectToWidgetAdapter<RenderBox>(container: boundary)
              .attachToRenderTree(buildOwner, root);
          buildOwner
            ..buildScope(root)
            ..finalizeTree();
        }
      } finally {
        pipelineOwner.rootNode = null;
        boundary.dispose();
        positioned.dispose();
        renderView.dispose();
        pipelineOwner.dispose();
        focusManager.dispose();
      }
    }
  }

  /// [root] 아래에서 build 실패로 바뀐 오류 위젯을 찾습니다.
  static ErrorWidget? _findErrorWidget(Element root) {
    ErrorWidget? found;
    void visit(Element element) {
      if (found != null) {
        return;
      }
      final widget = element.widget;
      if (widget is ErrorWidget) {
        found = widget;
        return;
      }
      element.visitChildren(visit);
    }

    visit(root);
    return found;
  }
}

/// 화면 밖 렌더러. 테스트는 이 provider를 대역으로 바꿉니다.
final offscreenRendererProvider = Provider<OffscreenRenderer>(
  (ref) => const PngOffscreenRenderer(),
);
