import 'package:flutter_test/flutter_test.dart';

import '../../tool/import_writing_arb.dart';

void main() {
  // writing 생성 ARB(ko)의 작은 대역. 메타데이터는 ko에만 있습니다.
  const writingKo = <String, Object?>{
    '@@locale': 'ko',
    '@@x-generated': 'mlw gen-docs로 생성',
    'welcomeCtaStart': '시작하기',
    '@welcomeCtaStart': {'description': 'welcome.cta.start: 시작하기 버튼'},
    'adFreeOfferPrice': '{price} · 1개월',
    '@adFreeOfferPrice': {
      'description': 'ad-free.offer.price: 가격',
      'placeholders': {
        'price': {'type': 'String'},
      },
    },
  };

  // app ARB(ko). welcomeCtaStart는 임시 문구, errorOffline은 app에만 있는 키입니다.
  const appKo = <String, Object?>{
    '@@locale': 'ko',
    'errorOffline': '인터넷에 연결되어 있지 않아요.',
    '@errorOffline': {'description': '임시. 오프라인 오류'},
    'welcomeCtaStart': '시작',
    '@welcomeCtaStart': {'description': '임시. 시작 버튼'},
  };

  Map<String, Object?> mergeKo(Map<String, Object?> app) => mergeWritingArb(
    app: app,
    writing: writingKo,
    writingTemplate: writingKo,
    isTemplate: true,
  );

  group('기준 언어(ko)', () {
    test('writing에 있는 키는 값과 메타데이터를 writing 것으로 바꿉니다', () {
      final merged = mergeKo(appKo);

      expect(merged['welcomeCtaStart'], '시작하기');
      expect(merged['@welcomeCtaStart'], {
        'description': 'welcome.cta.start: 시작하기 버튼',
      });
    });

    test('app에 없는 writing 키는 메타데이터(placeholder 포함)와 함께 끝에 더합니다', () {
      final merged = mergeKo(appKo);

      expect(merged.keys.toList(), [
        '@@locale',
        'errorOffline',
        '@errorOffline',
        'welcomeCtaStart',
        '@welcomeCtaStart',
        'adFreeOfferPrice',
        '@adFreeOfferPrice',
      ]);
      expect(merged['@adFreeOfferPrice'], writingKo['@adFreeOfferPrice']);
    });

    test('app에만 있는 키는 값과 임시 표시를 그대로 둡니다', () {
      final merged = mergeKo(appKo);

      expect(merged['errorOffline'], '인터넷에 연결되어 있지 않아요.');
      expect(merged['@errorOffline'], {'description': '임시. 오프라인 오류'});
    });

    test('@@locale은 app 것을 두고 writing의 다른 전역 속성은 가져오지 않습니다', () {
      final merged = mergeKo(appKo);

      expect(merged['@@locale'], 'ko');
      expect(merged.containsKey('@@x-generated'), isFalse);
    });

    test('writing에 `@키` 메타데이터가 없으면 null을 쓰지 않고 app 메타데이터를 둡니다', () {
      const writingNoMeta = <String, Object?>{
        '@@locale': 'ko',
        'welcomeCtaStart': '시작하기',
        'newKey': '새 문구',
      };
      final merged = mergeWritingArb(
        app: appKo,
        writing: writingNoMeta,
        writingTemplate: writingNoMeta,
        isTemplate: true,
      );

      expect(merged['@welcomeCtaStart'], {'description': '임시. 시작 버튼'});
      expect(merged.containsKey('@newKey'), isFalse);
      expect(merged.values, isNot(contains(isNull)));
    });
  });

  group('번역 언어(en·ja)', () {
    const writingEn = <String, Object?>{
      '@@locale': 'en',
      '@@x-generated': 'mlw gen-docs로 생성',
      'welcomeCtaStart': 'Get started',
    };
    const appEn = <String, Object?>{
      '@@locale': 'en',
      'errorOffline': 'You are not connected to the internet.',
      'welcomeCtaStart': 'Start',
      '@welcomeCtaStart': {'description': '임시. 시작 버튼'},
    };

    Map<String, Object?> mergeEn(Map<String, Object?> app) => mergeWritingArb(
      app: app,
      writing: writingEn,
      writingTemplate: writingKo,
      isTemplate: false,
    );

    test('writing 번역이 있는 키는 그 값으로 바꾸고 메타데이터는 두지 않습니다', () {
      final merged = mergeEn(appEn);

      expect(merged['welcomeCtaStart'], 'Get started');
      expect(merged.containsKey('@welcomeCtaStart'), isFalse);
    });

    test('writing 번역이 없는 키는 ko 문구로 채웁니다', () {
      final merged = mergeEn(appEn);

      expect(merged['adFreeOfferPrice'], '{price} · 1개월');
      expect(merged.containsKey('@adFreeOfferPrice'), isFalse);
    });

    test('app에만 있는 키의 `@키` 메타데이터도 지웁니다(메타데이터는 ko에만)', () {
      final merged = mergeEn({
        ...appEn,
        '@errorOffline': {'description': '임시. 오프라인 오류'},
      });

      expect(merged['errorOffline'], 'You are not connected to the internet.');
      expect(merged.containsKey('@errorOffline'), isFalse);
    });

    test('같은 입력으로 두 번 돌려도 결과가 같습니다(멱등)', () {
      final once = mergeEn(appEn);

      expect(encodeArb(mergeEn(once)), encodeArb(once));
    });

    test('app에만 있는 키와 전역 속성은 그대로 둡니다', () {
      final merged = mergeEn(appEn);

      expect(merged['errorOffline'], 'You are not connected to the internet.');
      expect(merged['@@locale'], 'en');
      expect(merged.containsKey('@@x-generated'), isFalse);
    });
  });

  test('같은 입력으로 두 번 돌려도 결과가 같습니다(멱등)', () {
    final once = mergeKo(appKo);
    final twice = mergeKo(once);

    expect(encodeArb(twice), encodeArb(once));
  });

  test('encodeArb는 두 칸 들여쓰기 JSON에 끝 줄바꿈을 붙이고 한글을 그대로 씁니다', () {
    expect(
      encodeArb(const {'@@locale': 'ko', 'a': '가'}),
      '{\n  "@@locale": "ko",\n  "a": "가"\n}\n',
    );
  });
}
