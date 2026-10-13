import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/gen/model/birth.dart';
import 'package:myungli_diary/core/api/gen/model/birth_place.dart';
import 'package:myungli_diary/core/api/gen/model/birth_time.dart';
import 'package:myungli_diary/core/api/gen/model/calendar_type.dart';
import 'package:myungli_diary/core/api/gen/model/language.dart';
import 'package:myungli_diary/core/api/gen/model/lunar_or_solar_date.dart';
import 'package:myungli_diary/core/api/gen/model/notification_setting.dart';
import 'package:myungli_diary/core/api/gen/model/profile.dart';
import 'package:myungli_diary/core/storage/saju_fingerprint.dart';

Birth _birth() => Birth(
  calendar: CalendarType.solar,
  date: LunarOrSolarDate(year: 1990, month: 5, day: 17),
  isLeapMonth: false,
  time: BirthTime(status: BirthTimeStatusEnum.known, value: '09:30'),
  gender: BirthGenderEnum.female,
  timezone: 'Asia/Seoul',
  place: BirthPlace(status: BirthPlaceStatusEnum.notAsked),
);

Profile _profile({
  Birth? birth,
  String honorific = '하늘',
  Language language = Language.ko,
  String timezone = 'Asia/Seoul',
}) => Profile(
  honorific: honorific,
  language: language,
  currentTimezone: timezone,
  birth: birth ?? _birth(),
  notification: NotificationSetting(
    status: NotificationSettingStatusEnum.enabled,
    time: '08:00',
  ),
);

void main() {
  test('호칭·언어가 달라도 지문은 같다', () {
    final a = _profile();
    final b = _profile(honorific: '바다', language: Language.en);

    expect(sajuFingerprint(a), sajuFingerprint(b));
    expect(sajuFingerprint(a), matches(RegExp(r'^[0-9a-f]{64}$')));
  });

  test('출생 시간만 달라도 지문이 다르다', () {
    final other = _birth().copyWith(
      time: BirthTime(status: BirthTimeStatusEnum.known, value: '09:31'),
    );

    expect(
      sajuFingerprint(_profile()),
      isNot(sajuFingerprint(_profile(birth: other))),
    );
  });

  test('성별·출생지·윤달·현재 시간대도 지문에 들어간다', () {
    final base = sajuFingerprint(_profile());

    expect(
      sajuFingerprint(
        _profile(birth: _birth().copyWith(gender: BirthGenderEnum.male)),
      ),
      isNot(base),
    );
    expect(
      sajuFingerprint(
        _profile(
          birth: _birth().copyWith(
            place: BirthPlace(
              status: BirthPlaceStatusEnum.city,
              cityId: 'tokyo',
            ),
          ),
        ),
      ),
      isNot(base),
    );
    expect(
      sajuFingerprint(_profile(birth: _birth().copyWith(isLeapMonth: true))),
      isNot(base),
    );
    expect(
      sajuFingerprint(_profile(timezone: 'America/Los_Angeles')),
      isNot(base),
    );
  });

  test('정규화 형식이 바뀌지 않는다(golden)', () {
    expect(
      sajuFingerprint(_profile()),
      '624074eb40d9edbbd010014cf2374c93b66f010dd26ceb5c45fd2f052a6b8ed2',
    );
  });

  test('중첩 맵의 삽입 순서만 달라도 같은 정규화 결과다', () {
    final a = {
      'b': {
        'y': 1,
        'x': [
          2,
          {'q': 1, 'p': 2},
        ],
      },
      'a': 'v',
    };
    final b = {
      'a': 'v',
      'b': {
        'x': [
          2,
          {'p': 2, 'q': 1},
        ],
        'y': 1,
      },
    };

    expect(fingerprintCanonicalJson(a), fingerprintCanonicalJson(b));
    expect(
      fingerprintCanonicalJson(a),
      '{"a":"v","b":{"x":[2,{"p":2,"q":1}],"y":1}}',
    );
  });
}
