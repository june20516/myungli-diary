import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/l10n/error_messages.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';

import '../../tool/common/openapi_spec.dart';

/// 사용자에게 보이지 않아 문구가 필요 없는 code입니다.
/// `reward.*`는 AdMob이 server에 부르는 SSV 웹훅(`admobRewardCallback`)에서만
/// 나오며 app은 그 operation을 부르지 않습니다.
const _notUserFacing = {'reward.invalid_signature', 'reward.expired'};

/// 계약 draft.3(#165 ⑧)에 들어왔지만 writing 오류 문구(`slots/ui/common.yaml`)가
/// 아직 없는 code입니다. 그동안은 4xx 일반 문구(`errorClient`)로 보입니다.
/// writing이 ARB 키를 더하면 아래 '대기 목록' 테스트가 실패하니, 이 목록에서
/// 지우고 [problemMessages]에 연결합니다.
const _awaitingWriting = {'timezone.invalid', 'city.not_found'};

/// 계약 `Problem.code`의 `x-problem-codes` 목록을 읽습니다.
Set<String> _contractCodes() {
  final spec = loadOpenApi();
  final components = spec['components']! as Map<String, Object?>;
  final schemas = components['schemas']! as Map<String, Object?>;
  final problem = schemas['Problem']! as Map<String, Object?>;
  final properties = problem['properties']! as Map<String, Object?>;
  final code = properties['code']! as Map<String, Object?>;
  final codes = code['x-problem-codes']! as Map<String, Object?>;
  return codes.keys.toSet();
}

Map<String, Object?> _arb(String locale) =>
    jsonDecode(File('lib/core/l10n/arb/app_$locale.arb').readAsStringSync())
        as Map<String, Object?>;

void main() {
  final codes = _contractCodes();
  final userFacing = codes
      .difference(_notUserFacing)
      .difference(_awaitingWriting);

  test('계약에서 x-problem-codes를 읽는다', () {
    expect(codes, contains('auth.exchange_invalid'));
    expect(codes, containsAll(_notUserFacing));
  });

  test('ARB 키 이름 규칙: error + code의 lowerCamelCase', () {
    expect(
      problemMessageKey('auth.exchange_invalid'),
      'errorAuthExchangeInvalid',
    );
    expect(problemMessageKey('not_implemented'), 'errorNotImplemented');
    expect(problemMessageKey('rate_limited'), 'errorRateLimited');
    expect(problemMessageKey('app_check.invalid'), 'errorAppCheckInvalid');
  });

  test('사용자에게 보일 수 있는 code는 모두 problemMessages에 문구가 있다', () {
    final missing = userFacing.difference(problemMessages.keys.toSet());
    expect(missing, isEmpty, reason: '문구 없는 code: $missing');
  });

  test('problemMessages에는 계약 밖 code나 웹훅 전용 code가 없다', () {
    final extra = problemMessages.keys.toSet().difference(userFacing);
    expect(extra, isEmpty, reason: '계약에 없는 code: $extra');
  });

  test('writing 문구 대기 code는 계약에 있고 아직 어느 ARB에도 없다', () {
    expect(codes, containsAll(_awaitingWriting));
    for (final locale in ['ko', 'en', 'ja']) {
      final arb = _arb(locale);
      for (final code in _awaitingWriting) {
        final key = problemMessageKey(code);
        expect(
          arb.containsKey(key),
          isFalse,
          reason: '$locale ARB에 $key가 생겼습니다. 대기 목록에서 지우고 연결하세요',
        );
      }
    }
  });

  for (final locale in ['ko', 'en', 'ja']) {
    test('$locale: code마다 규칙 이름의 ARB 문구를 쓴다', () {
      final arb = _arb(locale);
      final l10n = lookupAppLocalizations(Locale(locale));
      for (final code in userFacing) {
        final key = problemMessageKey(code);
        expect(arb[key], isA<String>(), reason: '$locale ARB에 $key 없음');
        expect(
          problemMessages[code]?.call(l10n),
          arb[key],
          reason: '$code의 문구가 $key가 아님',
        );
      }
    });
  }
}
