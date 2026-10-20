import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/register_screenshots.dart';

void main() {
  late Directory source;
  late Directory artifacts;

  setUp(() {
    final root = Directory.systemTemp.createTempSync('register_shots');
    addTearDown(() => root.deleteSync(recursive: true));
    source = Directory('${root.path}/src')..createSync();
    artifacts = Directory('${root.path}/artifacts');
  });

  List<Map<String, Object?>> readIndex() => (jsonDecode(
    File('${artifacts.path}/index.json').readAsStringSync(),
  ) as List<Object?>).cast<Map<String, Object?>>();

  void shot(String name, {int bytes = 10}) =>
      File('${source.path}/$name').writeAsBytesSync(List.filled(bytes, 1));

  test('날짜·화면·상태 이름으로 복사하고 index.json에 등록합니다', () {
    shot('welcome__default.png');

    registerScreenshots(
      sourceDir: source,
      artifactsDir: artifacts,
      date: '2026-10-14',
    );

    expect(
      File('${artifacts.path}/2026-10-14-welcome-default.png').existsSync(),
      isTrue,
    );
    final entry = readIndex().single;
    expect(entry['kind'], 'screenshot');
    expect(entry['file'], '2026-10-14-welcome-default.png');
    expect(entry['screens'], ['welcome']);
    expect(entry['milestone'], 'A1');
    expect(entry['status'], 'draft');
  });

  test('같은 화면·상태를 다시 등록하면 앞 항목이 superseded가 됩니다', () {
    shot('welcome__default.png');
    registerScreenshots(
      sourceDir: source,
      artifactsDir: artifacts,
      date: '2026-10-13',
    );
    registerScreenshots(
      sourceDir: source,
      artifactsDir: artifacts,
      date: '2026-10-14',
    );
    // 같은 날 다시 돌려도 항목이 늘지 않습니다.
    registerScreenshots(
      sourceDir: source,
      artifactsDir: artifacts,
      date: '2026-10-14',
    );

    final entries = readIndex();
    expect(entries, hasLength(2));
    expect(entries[0]['status'], 'superseded');
    expect(entries[1]['status'], 'draft');
    expect(
      File('${artifacts.path}/2026-10-13-welcome-default.png').existsSync(),
      isTrue,
      reason: '이전 파일은 지우지 않습니다',
    );
  });

  test('다른 상태는 서로 대체하지 않습니다', () {
    shot('launch__offline.png');
    shot('launch__default.png');
    registerScreenshots(
      sourceDir: source,
      artifactsDir: artifacts,
      date: '2026-10-14',
    );

    expect(readIndex().map((entry) => entry['status']), everyElement('draft'));
  });

  test('2MB를 넘는 이미지가 있으면 아무것도 등록하지 않고 오류입니다', () {
    shot('welcome__default.png');
    shot('today__default.png', bytes: 2 * 1024 * 1024 + 1);

    expect(
      () => registerScreenshots(
        sourceDir: source,
        artifactsDir: artifacts,
        date: '2026-10-14',
      ),
      throwsA(isA<ScreenshotError>()),
    );
    expect(File('${artifacts.path}/index.json').existsSync(), isFalse);
  });

  test('이름 형식이 틀리거나 IA에 없는 화면이면 오류입니다', () {
    shot('welcome.png');
    expect(
      () => registerScreenshots(
        sourceDir: source,
        artifactsDir: artifacts,
        date: '2026-10-14',
      ),
      throwsA(isA<ScreenshotError>()),
    );
    File('${source.path}/welcome.png').deleteSync();
    shot('ghost__default.png');
    expect(
      () => registerScreenshots(
        sourceDir: source,
        artifactsDir: artifacts,
        date: '2026-10-14',
        knownScreens: {'welcome'},
      ),
      throwsA(isA<ScreenshotError>()),
    );
  });

  test('과거 날짜로 다시 등록해도 더 최신 항목은 대체하지 않습니다', () {
    shot('welcome__default.png');
    registerScreenshots(
      sourceDir: source,
      artifactsDir: artifacts,
      date: '2026-10-14',
    );
    registerScreenshots(
      sourceDir: source,
      artifactsDir: artifacts,
      date: '2026-10-13',
    );

    final byDate = {
      for (final entry in readIndex()) entry['date']: entry['status'],
    };
    expect(byDate, {'2026-10-14': 'draft', '2026-10-13': 'superseded'});
  });

  test('decisions와 source를 index.json에 남기고 없는 결정은 오류입니다', () {
    shot('welcome__default.png');
    registerScreenshots(
      sourceDir: source,
      artifactsDir: artifacts,
      date: '2026-10-14',
      decisions: ['D50'],
      knownDecisions: {'D50'},
      source: 'welcome.html',
    );

    final entry = readIndex().single;
    expect(entry['decisions'], ['D50']);
    expect(entry['source'], 'welcome.html');
    expect(
      () => registerScreenshots(
        sourceDir: source,
        artifactsDir: artifacts,
        date: '2026-10-14',
        decisions: ['D999'],
        knownDecisions: {'D50'},
      ),
      throwsA(isA<ScreenshotError>()),
    );
  });

  group('render 출처(#336)', () {
    void render(String date) => registerScreenshots(
      sourceDir: source,
      artifactsDir: artifacts,
      date: date,
      origin: ScreenshotOrigin.render,
    );

    test('render 접두어 id와 상태 이름 설명으로 등록합니다', () {
      shot('today__loading.png');
      render('2026-10-20');
      final entry = readIndex().single;
      expect(entry['id'], 'render.today.loading.2026-10-20');
      expect(entry['note'], startsWith('loading 상태'));
      expect(entry['screens'], ['today']);
    });

    test('그림이 바뀌면 이전 렌더는 파일과 항목을 지우고 새로 둡니다', () {
      shot('today__default.png');
      render('2026-10-19');
      shot('today__default.png', bytes: 20);
      render('2026-10-20');
      final entry = readIndex().single;
      expect(entry['date'], '2026-10-20');
      expect(
        File('${artifacts.path}/2026-10-19-today-default.png').existsSync(),
        isFalse,
      );
      expect(
        File('${artifacts.path}/2026-10-20-today-default.png').existsSync(),
        isTrue,
      );
    });

    test('그림이 같으면 새로 등록하지 않습니다', () {
      shot('today__default.png');
      render('2026-10-19');
      render('2026-10-20');
      final entry = readIndex().single;
      expect(entry['date'], '2026-10-19');
      expect(
        File('${artifacts.path}/2026-10-20-today-default.png').existsSync(),
        isFalse,
      );
    });

    test('이번 입력에 없는 화면·상태의 이전 렌더는 항목과 파일을 지웁니다', () {
      shot('today__default.png');
      shot('today__loading.png');
      render('2026-10-19');
      File('${source.path}/today__loading.png').deleteSync();
      render('2026-10-20');

      expect(readIndex().map((e) => e['id']), [
        'render.today.default.2026-10-19',
      ]);
      expect(
        File('${artifacts.path}/2026-10-19-today-loading.png').existsSync(),
        isFalse,
      );
      expect(
        File('${artifacts.path}/2026-10-19-today-default.png').existsSync(),
        isTrue,
      );
    });

    test('Patrol 캡처 항목은 입력에 없어도 지우지 않습니다', () {
      shot('welcome__default.png');
      registerScreenshots(
        sourceDir: source,
        artifactsDir: artifacts,
        date: '2026-10-14',
      );
      File('${source.path}/welcome__default.png').deleteSync();
      shot('today__default.png');
      render('2026-10-20');
      expect(readIndex().map((e) => e['id']), [
        'e2e.welcome.default.2026-10-14',
        'render.today.default.2026-10-20',
      ]);
      expect(
        File('${artifacts.path}/2026-10-14-welcome-default.png').existsSync(),
        isTrue,
      );
    });

    test('Patrol 캡처 항목은 건드리지 않습니다', () {
      shot('welcome__default.png');
      registerScreenshots(
        sourceDir: source,
        artifactsDir: artifacts,
        date: '2026-10-14',
      );
      render('2026-10-20');
      expect(readIndex().map((e) => e['id']), [
        'e2e.welcome.default.2026-10-14',
        'render.welcome.default.2026-10-20',
      ]);
    });
  });
}
