import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';

const _arbDir = 'lib/core/l10n/arb';
const _foundationKeys = {
  'errorOffline',
  'errorTimeout',
  'errorClient',
  'errorServer',
  'errorUnexpected',
  'errorNotImplemented',
  'actionRetry',
  'traceIdLabel',
};
const _locales = ['ko', 'en', 'ja'];

/// 메타데이터(`@…`)를 뺀 메시지 키 집합입니다.
Set<String> _messageKeys(String locale) {
  final json = jsonDecode(
    File('$_arbDir/app_$locale.arb').readAsStringSync(),
  ) as Map<String, dynamic>;
  return json.keys.where((key) => !key.startsWith('@')).toSet();
}

void main() {
  test('지원 언어는 ko, en, ja입니다', () {
    expect(
      AppLocalizations.supportedLocales.map((l) => l.languageCode),
      unorderedEquals(_locales),
    );
  });

  test('ja 로케일에서 오류 문구가 비어 있지 않습니다', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('ja'));

    expect(l10n.errorOffline, isNotEmpty);
    expect(l10n.traceIdLabel('abc'), contains('abc'));
  });

  test('세 ARB의 메시지 키 집합이 같습니다', () {
    final ko = _messageKeys('ko');

    expect(ko, containsAll(_foundationKeys));
    expect(_messageKeys('en'), ko);
    expect(_messageKeys('ja'), ko);
  });
}
