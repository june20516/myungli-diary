import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/gen/model/birth.dart';
import 'package:myungli_diary/core/api/gen/model/birth_place.dart';
import 'package:myungli_diary/core/api/gen/model/birth_time.dart';
import 'package:myungli_diary/core/api/gen/model/calendar_type.dart';
import 'package:myungli_diary/core/api/gen/model/city.dart';
import 'package:myungli_diary/core/api/gen/model/lunar_or_solar_date.dart';
import 'package:myungli_diary/features/onboarding/data/onboarding_draft.dart';

final _newYork = City(
  id: '5128581',
  name: 'New York',
  country: 'US',
  timezone: 'America/New_York',
);

OnboardingDraft _solar() => OnboardingDraft(
  honorific: '하늘',
  calendar: CalendarType.solar,
  date: LunarOrSolarDate(year: 1990, month: 5, day: 17),
  time: BirthTime(status: BirthTimeStatusEnum.known, value: '09:30'),
  gender: BirthGenderEnum.female,
);

void main() {
  group('toJson/fromJson 왕복', () {
    test('양력 입력이 같다', () {
      final draft = _solar();
      expect(OnboardingDraft.fromJson(draft.toJson()), draft);
    });

    test('음력 윤달·시간 모름·도시가 같다', () {
      final draft = OnboardingDraft(
        honorific: 'Sky',
        calendar: CalendarType.lunar,
        date: LunarOrSolarDate(year: 1985, month: 4, day: 3),
        isLeapMonth: true,
        time: BirthTime(status: BirthTimeStatusEnum.unknown),
        gender: BirthGenderEnum.male,
        city: _newYork,
      );
      expect(OnboardingDraft.fromJson(draft.toJson()), draft);
    });

    test('빈 입력도 같다', () {
      const draft = OnboardingDraft();
      expect(OnboardingDraft.fromJson(draft.toJson()), draft);
    });

    test('형식 버전이 다르거나 값이 깨지면 FormatException이다', () {
      expect(
        () => OnboardingDraft.fromJson(const {'v': 2}),
        throwsFormatException,
      );
      expect(
        () => OnboardingDraft.fromJson(const {'v': 1, 'calendar': 'mars'}),
        throwsFormatException,
      );
      expect(
        () => OnboardingDraft.fromJson(const {'v': 1, 'date': 'x'}),
        throwsFormatException,
      );
    });
  });

  group('toBirth', () {
    test('도시가 없으면 not_asked와 Asia/Seoul이다', () {
      final birth = _solar().toBirth();
      expect(birth.place.status, BirthPlaceStatusEnum.notAsked);
      expect(birth.place.cityId, isNull);
      expect(birth.timezone, 'Asia/Seoul');
    });

    test('도시가 있으면 city와 그 도시의 시간대다', () {
      final birth = _solar().copyWith(city: _newYork).toBirth();
      expect(birth.place.status, BirthPlaceStatusEnum.city);
      expect(birth.place.cityId, '5128581');
      expect(birth.timezone, 'America/New_York');
    });

    test('양력이면 윤달 표시가 있어도 isLeapMonth는 false다', () {
      final birth = _solar().copyWith(isLeapMonth: true).toBirth();
      expect(birth.isLeapMonth, isFalse);
    });

    test('음력이면 윤달을 그대로 둔다', () {
      final birth = _solar()
          .copyWith(calendar: CalendarType.lunar, isLeapMonth: true)
          .toBirth();
      expect(birth.isLeapMonth, isTrue);
      expect(birth.calendar, CalendarType.lunar);
    });

    test('필수 값이 비면 StateError다', () {
      expect(const OnboardingDraft().toBirth, throwsStateError);
    });
  });

  group('isCompleteFor', () {
    test('한국이면 도시 없이 완성이다', () {
      expect(_solar().isCompleteFor(deviceRegionIsKorea: true), isTrue);
    });

    test('한국 밖이면 도시가 없을 때 false, 있으면 true다', () {
      expect(_solar().isCompleteFor(deviceRegionIsKorea: false), isFalse);
      expect(
        _solar()
            .copyWith(city: _newYork)
            .isCompleteFor(deviceRegionIsKorea: false),
        isTrue,
      );
    });

    test('호칭이 비었거나 공백뿐이면 false다', () {
      expect(
        _solar()
            .copyWith(honorific: '  ')
            .isCompleteFor(deviceRegionIsKorea: true),
        isFalse,
      );
      expect(
        const OnboardingDraft().isCompleteFor(deviceRegionIsKorea: true),
        isFalse,
      );
    });

    test('Birth 형식을 쓰는 곳에서 타입이 맞다', () {
      expect(_solar().toBirth(), isA<Birth>());
    });
  });

  test('copyWith(clearCity)는 도시를 지운다', () {
    final draft = _solar().copyWith(city: _newYork).copyWith(clearCity: true);
    expect(draft.city, isNull);
  });
}
