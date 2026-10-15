import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';

/// 위젯을 화면 밖에서 그려 PNG로 만드는 곳(공유 이미지 렌더).
///
/// 위젯과 크기를 받는 일반 인터페이스라 공유 미리보기 말고 다른 공유(계획 4~6)나 테스트도
/// 같은 모양으로 씁니다. 화면에 보이는 위젯 트리와는 따로 그립니다.
abstract interface class ShareRenderer {
  /// [image]를 [logicalSize] 논리 크기로 그린 PNG 바이트를 돌려줍니다.
  ///
  /// [image]가 [Directionality]·[Localizations]·테마를 스스로 갖추지 않았다면 그리는 쪽이
  /// [ShareRenderHost] 등으로 감싸 넘깁니다. 그리다 던진 오류는 호출한 쪽으로 전해집니다.
  Future<Uint8List> render(Widget image, Size logicalSize);
}

/// 화면 밖 트리에 방향·기본 [MediaQuery]·언어(글꼴 묶음·문구)를 줍니다. 화면 트리의 값은
/// 이어지지 않으므로 [locale]을 직접 넘깁니다. 기기 글자 배율은 받지 않습니다.
class ShareRenderHost extends StatelessWidget {
  /// [child]를 [locale]로 감쌉니다.
  const new({required this.locale, required this.child, super.key});

  /// 화면과 같은 언어.
  final Locale locale;

  /// 그릴 위젯.
  final Widget child;

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.ltr,
    child: MediaQuery(
      data: const MediaQueryData(),
      child: Localizations(
        locale: locale,
        delegates: AppLocalizations.localizationsDelegates,
        child: child,
      ),
    ),
  );
}

/// 화면 밖 `RepaintBoundary`에 그려 PNG로 만드는 [ShareRenderer]입니다.
///
/// 별도의 렌더 트리를 잠깐 만들어 `logicalSize`로 배치하고, 자산·글꼴 같은 비동기 내용이
/// 다 채워질 때까지(새로 그릴 일이 150ms 동안 없을 때, 최대 3초) 기다린 뒤
/// `pixelRatio` 배로 캡처합니다. 폭 360 논리 픽셀 x 3 = 1080(명세 `canvas.width`)입니다.
/// 테마는 그릴 위젯이 정합니다(공유 이미지는 스스로 라이트로 고정).
final class OffscreenShareRenderer implements ShareRenderer {
  /// 렌더러를 만듭니다. [pixelRatio]는 논리 픽셀당 실제 픽셀 수입니다.
  const new({this.pixelRatio = 3});

  /// 논리 픽셀당 실제 픽셀 수.
  final double pixelRatio;

  static const Duration _tick = Duration(milliseconds: 25);
  static const int _quietTicks = 6;
  static const Duration _timeout = Duration(seconds: 3);

  @override
  Future<Uint8List> render(Widget image, Size logicalSize) async {
    final boundary = RenderRepaintBoundary();
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final constraints = BoxConstraints.tight(logicalSize);
    final renderView = RenderView(
      view: view,
      configuration: ViewConfiguration(
        logicalConstraints: constraints,
        physicalConstraints: constraints,
      ),
      child: RenderPositionedBox(child: boundary),
    );
    final pipelineOwner = PipelineOwner()..rootNode = renderView;
    renderView.prepareInitialFrame();

    var rebuildRequested = false;
    final focusManager = FocusManager();
    final buildOwner = BuildOwner(
      focusManager: focusManager,
      onBuildScheduled: () => rebuildRequested = true,
    );

    // 위젯 오류는 ErrorWidget으로 바뀌어 보고만 되므로, 그리는 동안 가로채 던집니다.
    Object? failure;
    StackTrace? failureStack;
    final previousOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      failure ??= details.exception;
      failureStack ??= details.stack;
    };

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
        child: SizedBox.fromSize(size: logicalSize, child: image),
      ).attachToRenderTree(buildOwner);
      pumpFrame();

      final deadline = DateTime.now().add(_timeout);
      var quiet = 0;
      while (quiet < _quietTicks && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(_tick);
        if (rebuildRequested) {
          rebuildRequested = false;
          quiet = 0;
          pumpFrame();
        } else {
          quiet++;
        }
      }
      final error = failure;
      if (error != null) {
        Error.throwWithStackTrace(error, failureStack ?? StackTrace.current);
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
      FlutterError.onError = previousOnError;
      // 트리를 걷어 내고 자원을 돌려줍니다.
      if (root != null) {
        RenderObjectToWidgetAdapter<RenderBox>(container: boundary)
            .attachToRenderTree(buildOwner, root);
        buildOwner
          ..buildScope(root)
          ..finalizeTree();
      }
      focusManager.dispose();
    }
  }
}

/// 공유 이미지 렌더러. 테스트는 이 provider를 대역으로 바꿉니다.
final shareRendererProvider = Provider<ShareRenderer>(
  (ref) => const OffscreenShareRenderer(),
);
