// 스토어 이미지(#1203, D133) 명세 읽기와 틀 합성. 생성(`store_images_test.dart`)과 계약 검사
// (`store_spec_test.dart`)가 함께 씁니다.
//
// 명세는 design `docs/identity/design/store/store.json`(장면, 틀, 글 규칙, Play 그래픽 이미지), 글은 writing
// `docs/identity/writing/generated/store/listing.json`의 `<언어>."store.screenshot.caption"`입니다.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

/// design 스토어 이미지 명세(계약).
const String storeSpecPath = '../docs/identity/design/store/store.json';

/// writing 스토어 등록정보 원고(계약). 스크린샷 위 글이 들어 있습니다.
const String storeListingPath =
    '../docs/identity/writing/generated/store/listing.json';

/// 스크린샷 위 글의 원고 슬롯.
const String captionSlot = 'store.screenshot.caption';

/// 스크린샷 장면 하나(`store.json` `scenes[]`).
final class StoreScene {
  /// 명세의 장면 값을 담습니다.
  const new({
    required this.order,
    required this.id,
    required this.screen,
    required this.state,
    required this.scenario,
  });

  /// 스토어에 보이는 순서(1부터).
  final int order;

  /// 장면 키(원고 글의 키).
  final String id;

  /// IA 화면 id.
  final String screen;

  /// 화면 렌더 사례의 상태 이름.
  final String state;

  /// 명세가 적은 대역 시나리오(`member`, `evidence-unlocked`).
  final String scenario;

  /// [language] 화면을 찍을 시나리오. 명세의 시나리오와 같은 상태(근거 잠김, 열림)의 그 언어 데모
  /// 응답입니다(`store-<언어>`, `store-<언어>-unlocked`, `tool/store_fixtures.sh`).
  String scenarioFor(String language) => switch (scenario) {
    'member' => 'store-$language',
    'evidence-unlocked' => 'store-$language-unlocked',
    _ => throw StateError('스토어 장면 $id의 시나리오 $scenario에 언어별 데모 응답이 없습니다'),
  };
}

/// 틀 하나(`store.json` `frames.<키>`). 길이는 모두 픽셀입니다.
final class StoreFrame {
  /// 명세의 틀 값을 담습니다.
  const new({
    required this.key,
    required this.size,
    required this.captionTop,
    required this.captionSide,
    required this.captionSize,
    required this.screenTop,
    required this.screenWidth,
    required this.screenRadius,
    required this.shadowY,
    required this.shadowBlur,
    required this.shadowColor,
  });

  /// 틀 키(`appStore`, `play`). 산출물 폴더 이름입니다.
  final String key;

  /// 그림 크기.
  final Size size;

  /// 글 자리 위 여백.
  final double captionTop;

  /// 글 자리 좌우 여백.
  final double captionSide;

  /// 글 크기.
  final double captionSize;

  /// 화면 판 위 여백.
  final double screenTop;

  /// 화면 판 폭(가운데).
  final double screenWidth;

  /// 화면 판 모서리.
  final double screenRadius;

  /// 화면 판 그림자 아래 거리.
  final double shadowY;

  /// 화면 판 그림자 흐림(CSS blur 반경).
  final double shadowBlur;

  /// 화면 판 그림자 색.
  final Color shadowColor;

  /// 글 자리 폭.
  double get captionWidth => size.width - captionSide * 2;
}

/// 스토어 이미지 명세 전체.
final class StoreSpec {
  /// 명세 값을 담습니다.
  const new({
    required this.logicalSize,
    required this.pixelRatio,
    required this.locales,
    required this.scenes,
    required this.frames,
    required this.captionWeight,
    required this.captionTracking,
    required this.captionLineHeight,
    required this.captionColor,
    required this.captionMaxLines,
    required this.featureSize,
    required this.featureLogoPath,
    required this.featureLogoWidth,
  });

  /// [path]의 명세를 읽습니다.
  factory load([String path = storeSpecPath]) {
    final json =
        jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
    final render = json['render'] as Map<String, dynamic>;
    final caption = json['caption'] as Map<String, dynamic>;
    final feature = json['featureGraphic'] as Map<String, dynamic>;
    final frames = json['frames'] as Map<String, dynamic>;
    return StoreSpec(
      logicalSize: _size(render['logicalSize']),
      pixelRatio: (render['pixelRatio'] as num).toDouble(),
      locales: [for (final locale in render['locales'] as List) '$locale'],
      scenes: [
        for (final scene
            in (json['scenes'] as List).cast<Map<String, dynamic>>())
          StoreScene(
            order: scene['order'] as int,
            id: scene['id'] as String,
            screen: scene['screen'] as String,
            state: scene['state'] as String,
            scenario: scene['scenario'] as String,
          ),
      ]..sort((a, b) => a.order.compareTo(b.order)),
      frames: [
        for (final MapEntry(:key, :value) in frames.entries)
          _frame(key, value as Map<String, dynamic>),
      ],
      captionWeight: caption['weight'] as int,
      captionTracking: (caption['tracking'] as num).toDouble(),
      captionLineHeight: (caption['lineHeight'] as num).toDouble(),
      captionColor: _hex(caption['color'] as String),
      captionMaxLines: caption['maxLines'] as int,
      featureSize: _size(feature['size']),
      featureLogoPath:
          '${File(path).parent.parent.path}/${feature['logo'] as String}',
      featureLogoWidth: (feature['logoWidth'] as num).toDouble(),
    );
  }

  /// 화면 렌더의 논리 크기.
  final Size logicalSize;

  /// 화면 렌더 배율.
  final double pixelRatio;

  /// 찍는 언어.
  final List<String> locales;

  /// 장면(순서대로).
  final List<StoreScene> scenes;

  /// 틀.
  final List<StoreFrame> frames;

  /// 글 굵기.
  final int captionWeight;

  /// 글 자간(글 크기에 대한 비율).
  final double captionTracking;

  /// 글 줄 높이(글 크기에 대한 비율).
  final double captionLineHeight;

  /// 글 색.
  final Color captionColor;

  /// 글 최대 줄 수.
  final int captionMaxLines;

  /// Play 그래픽 이미지 크기.
  final Size featureSize;

  /// Play 그래픽 이미지 가로 조합 로고 파일(app 기준 경로).
  final String featureLogoPath;

  /// Play 그래픽 이미지 로고 폭.
  final double featureLogoWidth;

  /// [language]의 글 스타일([size] 크기). 한글과 영어는 Pretendard, 일본어는 같은 가족의
  /// Pretendard JP입니다(앱의 언어별 글꼴과 같음).
  TextStyle captionStyle(String language, double size) => TextStyle(
    fontFamily: language == 'ja' ? 'Pretendard JP' : 'Pretendard',
    fontWeight: FontWeight.values.firstWhere(
      (weight) => weight.value == captionWeight,
    ),
    fontSize: size,
    letterSpacing: size * captionTracking,
    height: captionLineHeight,
    color: captionColor,
  );

  static StoreFrame _frame(String key, Map<String, dynamic> json) {
    final caption = json['caption'] as Map<String, dynamic>;
    final screen = json['screen'] as Map<String, dynamic>;
    final shadow = screen['shadow'] as Map<String, dynamic>;
    return StoreFrame(
      key: key,
      size: _size(json['size']),
      captionTop: _num(caption['top']),
      captionSide: _num(caption['side']),
      captionSize: _num(caption['size']),
      screenTop: _num(screen['top']),
      screenWidth: _num(screen['width']),
      screenRadius: _num(screen['radius']),
      shadowY: _num(shadow['y']),
      shadowBlur: _num(shadow['blur']),
      shadowColor: _rgba(shadow['color'] as String),
    );
  }
}

/// writing 원고의 스크린샷 위 글: 언어 → 장면 키 → 글(줄바꿈은 원고 그대로).
Map<String, Map<String, String>> loadCaptions([
  String path = storeListingPath,
]) {
  final json =
      jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
  return {
    for (final MapEntry(:key, :value) in json.entries)
      key: {
        for (final MapEntry(key: scene, :value)
            in ((value as Map<String, dynamic>)[captionSlot]
                    as Map<String, dynamic>)
                .entries)
          scene: value as String,
      },
  };
}

/// [caption]이 [frame] 글 자리에 들어가지 않는 까닭. 들어가면 null입니다
/// (`store.json` `caption.overflow`).
///
/// 줄바꿈은 원고 그대로이고, 줄 수가 최대를 넘거나 한 줄 폭이 글 자리 폭을 넘으면 실패입니다. 줄이거나
/// 자르지 않습니다(writing이 글을 줄임).
String? captionOverflow(
  StoreSpec spec,
  StoreFrame frame,
  String language,
  String caption,
) {
  final lines = caption.split('\n');
  if (lines.length > spec.captionMaxLines) {
    return '${lines.length}줄(최대 ${spec.captionMaxLines}줄)';
  }
  final style = spec.captionStyle(language, frame.captionSize);
  for (final line in lines) {
    final painter = TextPainter(
      text: TextSpan(text: line, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    final width = painter.width;
    painter.dispose();
    if (width > frame.captionWidth) {
      return '"$line" 폭 ${width.ceil()} > 글 자리 ${frame.captionWidth.toInt()}';
    }
  }
  return null;
}

/// 화면 렌더 [screen]과 글 [caption]을 [frame] 틀에 합성합니다.
///
/// 바탕은 `gradient.today` 라이트, 글은 위 가운데, 화면은 아래 둥근 판(그림자)이고 그림 아래로 넘치는
/// 부분은 잘립니다. 글이 들어가지 않으면 [StateError]입니다([captionOverflow]).
Future<ui.Image> composeFrame(
  StoreSpec spec,
  StoreFrame frame,
  String language,
  String caption,
  ui.Image screen,
) {
  final overflow = captionOverflow(spec, frame, language, caption);
  if (overflow != null) {
    throw StateError('${frame.key} $language 글이 들어가지 않습니다: $overflow');
  }
  final bounds = Offset.zero & frame.size;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, bounds)
    ..drawRect(
      bounds,
      Paint()..shader = lightGradients.today.createShader(bounds),
    );

  TextPainter(
      text: TextSpan(
        text: caption,
        style: spec.captionStyle(language, frame.captionSize),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )
    ..layout(minWidth: frame.captionWidth, maxWidth: frame.captionWidth)
    ..paint(canvas, Offset(frame.captionSide, frame.captionTop))
    ..dispose();

  final height = frame.screenWidth * screen.height / screen.width;
  final panel = RRect.fromRectAndRadius(
    Rect.fromLTWH(
      (frame.size.width - frame.screenWidth) / 2,
      frame.screenTop,
      frame.screenWidth,
      height,
    ),
    Radius.circular(frame.screenRadius),
  );
  canvas
    ..drawRRect(
      panel.shift(Offset(0, frame.shadowY)),
      Paint()
        ..color = frame.shadowColor
        // CSS blur 반경은 가우스 시그마의 2배입니다.
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, frame.shadowBlur / 2),
    )
    ..save()
    ..clipRRect(panel)
    ..drawImageRect(
      screen,
      Offset.zero & Size(screen.width.toDouble(), screen.height.toDouble()),
      panel.outerRect,
      Paint()..filterQuality = FilterQuality.high,
    )
    ..restore();
  return recorder.endRecording().toImage(
    frame.size.width.toInt(),
    frame.size.height.toInt(),
  );
}

/// Play 그래픽 이미지: `gradient.today` 라이트 바탕 가운데에 가로 조합 [logo]를 명세 폭으로 둡니다.
Future<ui.Image> composeFeatureGraphic(StoreSpec spec, ui.Image logo) {
  final bounds = Offset.zero & spec.featureSize;
  final recorder = ui.PictureRecorder();
  final width = spec.featureLogoWidth;
  final height = width * logo.height / logo.width;
  Canvas(recorder, bounds)
    ..drawRect(
      bounds,
      Paint()..shader = lightGradients.today.createShader(bounds),
    )
    ..drawImageRect(
      logo,
      Offset.zero & Size(logo.width.toDouble(), logo.height.toDouble()),
      Rect.fromCenter(center: bounds.center, width: width, height: height),
      Paint()..filterQuality = FilterQuality.high,
    );
  return recorder.endRecording().toImage(
    spec.featureSize.width.toInt(),
    spec.featureSize.height.toInt(),
  );
}

Size _size(Object? value) {
  final list = (value! as List).cast<num>();
  return Size(list[0].toDouble(), list[1].toDouble());
}

double _num(Object? value) => (value! as num).toDouble();

Color _hex(String value) =>
    Color(0xFF000000 | int.parse(value.substring(1), radix: 16));

/// `rgba(r, g, b, a)` 문자열의 색.
Color _rgba(String value) {
  final parts = RegExp(r'rgba\(([^)]*)\)')
      .firstMatch(value)!
      .group(1)!
      .split(',')
      .map((part) => num.parse(part.trim()))
      .toList();
  return Color.fromRGBO(
    parts[0].toInt(),
    parts[1].toInt(),
    parts[2].toInt(),
    parts[3].toDouble(),
  );
}
