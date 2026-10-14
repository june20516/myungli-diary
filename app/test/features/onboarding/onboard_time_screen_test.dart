import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/gen/model/birth_hour.dart';
import 'package:myungli_diary/core/api/gen/model/birth_time.dart';
import 'package:myungli_diary/core/api/gen/model/branch.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/features/onboarding/presentation/onboard_time_screen.dart';

void main() {
  group('sijinConfirmText', () {
    test('ko: 지지 이름과 시각 범위를 틀에 넣습니다', () async {
      final l10n = await AppLocalizations.delegate.load(const Locale('ko'));
      expect(
        sijinConfirmText(
          l10n,
          BirthHour(branch: Branch.in_, start: '03:30', end: '05:30'),
        ),
        '인시(03:30~05:30)',
      );
    });

    test('지지 12개가 모두 이름을 가지고 세 언어에서 겹치지 않습니다', () async {
      for (final locale in const [Locale('ko'), Locale('en'), Locale('ja')]) {
        final l10n = await AppLocalizations.delegate.load(locale);
        final texts = {
          for (final branch in Branch.values)
            sijinConfirmText(
              l10n,
              BirthHour(branch: branch, start: '00:00', end: '01:00'),
            ),
        };
        expect(texts.length, 12, reason: locale.languageCode);
      }
    });
  });

  group('출생 시각 변환', () {
    test('known 값은 시각이 되고 unknown·없음은 null입니다', () {
      expect(
        timeOfBirthTime(
          BirthTime(status: BirthTimeStatusEnum.known, value: '04:05'),
        ),
        const TimeOfDay(hour: 4, minute: 5),
      );
      expect(
        timeOfBirthTime(BirthTime(status: BirthTimeStatusEnum.unknown)),
        isNull,
      );
      expect(timeOfBirthTime(null), isNull);
    });

    test('birthTimeOf는 HH:MM으로 쓰고 모름이면 값이 없습니다', () {
      expect(
        birthTimeOf(const TimeOfDay(hour: 4, minute: 0), unknown: false),
        BirthTime(status: BirthTimeStatusEnum.known, value: '04:00'),
      );
      expect(
        birthTimeOf(const TimeOfDay(hour: 23, minute: 59), unknown: true),
        BirthTime(status: BirthTimeStatusEnum.unknown),
      );
    });
  });
}
