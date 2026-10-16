import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/gen/model/birth_time.dart';
import 'package:myungli_diary/core/clock/clock.dart';
import 'package:myungli_diary/features/calc_basis/model/time_basis.dart';
import 'package:timezone/timezone.dart' as tz;

BirthTime _at(String value) =>
    BirthTime(status: BirthTimeStatusEnum.known, value: value);

final BirthTime _unknown = BirthTime(status: BirthTimeStatusEnum.unknown);

// 기댓값은 엔진(core `resolve_birth_moment`, Python zoneinfo tzdata)으로
// 같은 입력을 계산해 맞췄습니다.
void main() {
  setUpAll(ensureTimeZonesInitialized);

  group('timeBasisOf', () {
    test('서울은 대표 경도 127.5도, 표준 오프셋 +9라 30분 뺍니다', () {
      expect(
        timeBasisOf(
          timezone: 'Asia/Seoul',
          solarDate: DateTime(1990, 5, 5),
          time: _at('08:00'),
        ),
        const TimeBasis(longitude: 127.5, correctionMinutes: -30),
      );
    });

    test('서머타임은 빼고 표준 오프셋으로 봅니다(1955년 +8:30, 1987년 +9)', () {
      expect(
        timeBasisOf(
          timezone: 'Asia/Seoul',
          solarDate: DateTime(1955, 6, 15),
          time: _at('08:00'),
        ),
        const TimeBasis(longitude: 127.5, correctionMinutes: 0),
      );
      expect(
        timeBasisOf(
          timezone: 'Asia/Seoul',
          solarDate: DateTime(1987, 7, 15),
          time: _at('08:00'),
        ),
        const TimeBasis(longitude: 127.5, correctionMinutes: -30),
      );
    });

    test('서울 밖은 표준 오프셋×15가 대표 경도이고, 도시 경도가 있으면 그 값입니다', () {
      expect(
        timeBasisOf(
          timezone: 'Asia/Tokyo',
          solarDate: DateTime(1990, 5, 5),
          time: _at('08:00'),
        ),
        const TimeBasis(longitude: 135, correctionMinutes: 0),
      );
      expect(
        timeBasisOf(
          timezone: 'Asia/Tokyo',
          solarDate: DateTime(1990, 5, 5),
          time: _at('08:00'),
          cityLongitude: 139.69,
        ),
        const TimeBasis(longitude: 139.69, correctionMinutes: 19),
      );
    });

    test('서쪽 시간대는 음수 경도이고 서머타임을 뺍니다', () {
      expect(
        timeBasisOf(
          timezone: 'America/New_York',
          solarDate: DateTime(1990, 7), // 1990-07-01
          time: _at('08:00'),
        ),
        const TimeBasis(longitude: -75, correctionMinutes: 0),
      );
    });

    test('시각 모름은 12:00으로 봅니다(서울 1954-03-21 전후)', () {
      expect(
        timeBasisOf(
          timezone: 'Asia/Seoul',
          solarDate: DateTime(1954, 3, 20),
          time: _unknown,
        ),
        const TimeBasis(longitude: 127.5, correctionMinutes: -30),
      );
      expect(
        timeBasisOf(
          timezone: 'Asia/Seoul',
          solarDate: DateTime(1954, 3, 21),
          time: _unknown,
        ),
        const TimeBasis(longitude: 127.5, correctionMinutes: 0),
      );
    });

    test('겹친 지역 시각은 앞 시각(전환 전 오프셋)으로 봅니다', () {
      // 1954-03-21 00:00에 +9 → +8:30이라 23:30~24:00이 두 번 있습니다. 엔진은 앞(+9)을 씁니다.
      expect(
        timeBasisOf(
          timezone: 'Asia/Seoul',
          solarDate: DateTime(1954, 3, 20),
          time: _at('23:45'),
        ),
        const TimeBasis(longitude: 127.5, correctionMinutes: -30),
      );
    });

    test('없는 지역 시각은 전환 전 오프셋으로 뒤로 밀어 봅니다', () {
      // 1961-08-10 00:00에 +8:30 → +9라 00:00~00:30이 없습니다. 엔진은 +9 구간 시각으로 봅니다.
      expect(
        timeBasisOf(
          timezone: 'Asia/Seoul',
          solarDate: DateTime(1961, 8, 10),
          time: _at('00:15'),
        ),
        const TimeBasis(longitude: 127.5, correctionMinutes: -30),
      );
      expect(
        timeBasisOf(
          timezone: 'Asia/Seoul',
          solarDate: DateTime(1961, 8, 9),
          time: _at('23:45'),
        ),
        const TimeBasis(longitude: 127.5, correctionMinutes: 0),
      );
    });
  });

  group('standardOffsetHoursAt', () {
    test('서머타임 중이면 직전 표준 오프셋입니다', () {
      final seoul = tz.getLocation('Asia/Seoul');
      expect(standardOffsetHoursAt(seoul, DateTime.utc(1955, 6, 14, 23)), 8.5);
      final newYork = tz.getLocation('America/New_York');
      expect(standardOffsetHoursAt(newYork, DateTime.utc(1990, 7, 1, 12)), -5);
      expect(standardOffsetHoursAt(newYork, DateTime.utc(1990, 1, 1, 12)), -5);
    });
  });

  group('representativeLongitude', () {
    test('Asia/Seoul은 127.5도, 그 밖은 표준 오프셋×15입니다', () {
      expect(representativeLongitude('Asia/Seoul', 9), 127.5);
      expect(representativeLongitude('Asia/Tokyo', 9), 135);
      expect(representativeLongitude('Asia/Kolkata', 5.5), 82.5);
    });
  });

  group('longitudeDegreesText', () {
    test('절댓값을 소수 둘째 자리까지 쓰고 뒤 0을 지웁니다', () {
      expect(longitudeDegreesText(127.5), '127.5');
      expect(longitudeDegreesText(135), '135');
      expect(longitudeDegreesText(-75), '75');
      expect(longitudeDegreesText(139.6917), '139.69');
    });
  });

  test('TimeBasis는 값이 같으면 같습니다', () {
    const a = TimeBasis(longitude: 127.5, correctionMinutes: -30);
    const b = TimeBasis(longitude: 127.5, correctionMinutes: -30);
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a == const TimeBasis(longitude: 127.5, correctionMinutes: 0), false);
  });
}
