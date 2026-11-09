@Tags(['contract'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/app/router/placeholder_screen.dart';
import 'package:myungli_diary/app/router/screen_registry.dart';

/// app-bar 제목을 IA 슬롯(`<화면>.bar.title`)으로 그리는 구현 화면과 그 ARB 키.
///
/// 새 화면이 구현되면(registry가 [PlaceholderScreen]을 벗어나면) 여기에 더해야 하고,
/// 그렇지 않으면 아래 목록 대조 테스트가 실패합니다. 화면이 그 슬롯 id로 제목을 그리는지는
/// 각 화면·흐름 테스트가 `expectAppBarTitle`로 확인하며, 아래 대조 테스트가 그 호출이 빠진 화면을 잡습니다.
const Map<String, String> _barTitleKeys = {
  'onboard-call': 'onboardCallBarTitle',
  'onboard-birth': 'onboardBirthBarTitle',
  'onboard-time': 'onboardTimeBarTitle',
  'onboard-gender': 'onboardGenderBarTitle',
  'birthplace': 'birthplaceBarTitle',
  'preview': 'previewBarTitle',
  'login': 'loginBarTitle',
  'consent': 'consentBarTitle',
  'notify-ask': 'notifyAskBarTitle',
  'today': 'todayBarTitle',
  'calendar': 'calendarBarTitle',
  'diary-list': 'diaryListBarTitle',
  'diary-edit': 'diaryEditBarTitle',
  'diary-view': 'diaryViewBarTitle',
  'tag-diary': 'tagDiaryBarTitle',
  'my-saju': 'mySajuBarTitle',
  'saju-chart': 'sajuChartBarTitle',
  'event-edit': 'eventEditBarTitle',
  'calc-basis': 'calcBasisBarTitle',
  'settings': 'settingsBarTitle',
  'profile-edit': 'profileEditBarTitle',
  'account-delete': 'accountDeleteBarTitle',
  'legal': 'legalBarTitle',
  'contact': 'contactBarTitle',
  'ad-free': 'adFreeBarTitle',
  'purchase-history': 'purchaseHistoryBarTitle',
  'login-methods': 'loginMethodsBarTitle',
  'account-merge': 'accountMergeBarTitle',
};

/// ARB에 "임시" 표시가 남아도 되는 키(슬롯이 없는 접근성 라벨·writing 원고 대기 문구).
/// writing R26(PR #709, #331)으로 임시 키가 모두 원고가 되어 지금은 없습니다.
const Set<String> _allowedTemporaryKeys = {};

/// 설명이 app 임시 키 표지인지 봅니다. 임시 키는 설명이 "임시"로 시작합니다(예 "임시, #548 원고 전",
/// "임시. daeun-table ..."). writing 슬롯 접두(`diary-edit.draft.status: `)를 떼고 보며,
/// 정식 원고 설명이 "임시 저장 상태"처럼 낱말로 "임시 저장"을 쓰는 것은 임시 키가 아닙니다.
bool isTemporaryDescription(String description) {
  final body = description.replaceFirst(RegExp(r'^[a-z0-9._-]+:\s*'), '');
  return RegExp(r'^임시(?!\s*저장)').hasMatch(body);
}

Map<String, Object?> _readJson(String path) =>
    jsonDecode(File(path).readAsStringSync())! as Map<String, Object?>;

/// IA 화면이 `<id>.bar.title` 슬롯을 가지는지.
bool _hasBarTitleSlot(Map<String, Object?> screen) =>
    (screen['slots']! as List<Object?>).any(
      (slot) =>
          (slot! as Map<String, Object?>)['id'] == '${screen['id']}.bar.title',
    );

void main() {
  final ia = _readJson('../docs/ia/screens.json');
  final barTitleScreenIds = {
    for (final screen in ia['screens']! as List<Object?>)
      if (_hasBarTitleSlot(screen! as Map<String, Object?>))
        (screen as Map<String, Object?>)['id']! as String,
  };
  final ko = _readJson('lib/core/l10n/arb/app_ko.arb');

  testWidgets('IA에 bar.title 슬롯이 있는 구현 화면은 모두 이 계약의 목록에 있습니다', (tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      Builder(
        builder: (c) {
          context = c;
          return const SizedBox();
        },
      ),
    );

    final implemented = {
      for (final id in barTitleScreenIds)
        if (screenRegistry[id] != null &&
            screenRegistry[id]!.builder(context) is! PlaceholderScreen)
          id,
    };

    expect(implemented, _barTitleKeys.keys.toSet());
  });

  test('목록의 화면은 IA 슬롯과 세 ARB의 제목 키를 모두 가집니다', () {
    for (final entry in _barTitleKeys.entries) {
      expect(barTitleScreenIds, contains(entry.key));
      for (final locale in ['ko', 'en', 'ja']) {
        final arb = _readJson('lib/core/l10n/arb/app_$locale.arb');
        expect(
          arb[entry.value],
          isA<String>(),
          reason: '$locale ${entry.value}',
        );
      }
    }
  });

  test('목록의 화면마다 그 슬롯으로 expectAppBarTitle을 부르는 테스트가 있습니다', () {
    final testSources = [
      for (final entity in Directory('test').listSync(recursive: true))
        if (entity is File &&
            entity.path.endsWith('_test.dart') &&
            !entity.path.endsWith('app_bar_title_contract_test.dart'))
          entity.readAsStringSync(),
    ];

    for (final key in _barTitleKeys.values) {
      final call = RegExp(
        'expectAppBarTitle\\(\\s*tester,\\s*SlotIds\\.$key\\b',
      );
      expect(
        testSources.any(call.hasMatch),
        isTrue,
        reason:
            '$key: expectAppBarTitle(tester, SlotIds.$key, ...)를 부르는 테스트가 없습니다',
      );
    }
  });

  test('임시 키 표지 판정: 슬롯 접두 뒤 "임시"로 시작하는 설명만 임시입니다', () {
    expect(
      isTemporaryDescription('diary-edit.draft.status: 임시 저장 상태. 상단 바'),
      isFalse,
    );
    expect(isTemporaryDescription('임시 저장 상태'), isFalse);
    expect(isTemporaryDescription('임시: 원고 전 문구'), isTrue);
    expect(isTemporaryDescription('임시, #548 원고 전(A7)'), isTrue);
    expect(isTemporaryDescription('임시. daeun-table 글'), isTrue);
    expect(isTemporaryDescription('x.y: 임시. 원고 전'), isTrue);
    expect(isTemporaryDescription('일반 설명, 임시 언급'), isFalse);
  });

  test('ARB에 임시 표시가 남은 키는 허용 목록뿐입니다', () {
    final temporary = {
      for (final entry in ko.entries)
        if (entry.key.startsWith('@') &&
            entry.value is Map<String, Object?> &&
            isTemporaryDescription(
              ((entry.value! as Map<String, Object?>)['description']
                      as String?) ??
                  '',
            ))
          entry.key.substring(1),
    };

    expect(temporary, _allowedTemporaryKeys);
  });

  test('해제된 임시 제목 키(A30)는 세 ARB에 남아 있지 않습니다', () {
    for (final locale in ['ko', 'en', 'ja']) {
      final arb = _readJson('lib/core/l10n/arb/app_$locale.arb');
      expect(arb.containsKey('calcBasisTitle'), isFalse, reason: locale);
      expect(arb.containsKey('@calcBasisTitle'), isFalse, reason: locale);
    }
  });
}
