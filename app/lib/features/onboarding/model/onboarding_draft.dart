import 'package:flutter/foundation.dart';
import 'package:myungli_diary/core/api/gen/model/birth.dart';
import 'package:myungli_diary/core/api/gen/model/birth_place.dart';
import 'package:myungli_diary/core/api/gen/model/birth_time.dart';
import 'package:myungli_diary/core/api/gen/model/calendar_type.dart';
import 'package:myungli_diary/core/api/gen/model/city.dart';
import 'package:myungli_diary/core/api/gen/model/lunar_or_solar_date.dart';

/// 한국 출생으로 가정할 때의 시간대입니다(D29).
const _koreaTimezone = 'Asia/Seoul';

/// `HH:MM`(24시간) 형식입니다.
final _timePattern = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');

/// 로컬 저장 형식의 버전입니다.
const _draftFormatVersion = 1;

/// 온보딩에서 받은 값을 모은 입력입니다.
///
/// 단계마다 로컬 DB에 저장합니다. JSON 키는 이 클래스가 정하며, 생성 모델의
/// 필드 이름이 바뀌어도 로컬 형식은 그대로 유지합니다.
@immutable
final class OnboardingDraft {
  /// 입력을 만듭니다. 아직 받지 못한 값은 null입니다.
  const new({
    this.honorific,
    this.calendar,
    this.date,
    this.isLeapMonth = false,
    this.time,
    this.gender,
    this.city,
  });

  /// 저장한 [json]에서 읽습니다. 형식이 다르거나 깨졌으면 [FormatException]입니다.
  factory fromJson(Map<String, Object?> json) {
    if (json['v'] != _draftFormatVersion) {
      throw const FormatException('지원하지 않는 온보딩 입력 형식입니다.');
    }
    try {
      final date = json['date'];
      final time = json['time'];
      final city = json['city'];
      return OnboardingDraft(
        honorific: json['honorific'] as String?,
        calendar: switch (json['calendar']) {
          null => null,
          final String value => CalendarType.values.byName(value),
          _ => throw const FormatException('calendar'),
        },
        date: date == null ? null : _dateFromJson(date as Map<String, Object?>),
        isLeapMonth: json['isLeapMonth'] as bool? ?? false,
        time: time == null ? null : _timeFromJson(time as Map<String, Object?>),
        gender: switch (json['gender']) {
          null => null,
          final String value => BirthGenderEnum.values.byName(value),
          _ => throw const FormatException('gender'),
        },
        city: city == null ? null : _cityFromJson(city as Map<String, Object?>),
      );
    } on FormatException {
      rethrow;
    } on Object catch (error) {
      // 타입 불일치(TypeError)·알 수 없는 enum 이름(ArgumentError)을 하나로 모읍니다.
      throw FormatException('온보딩 입력이 깨졌습니다: $error');
    }
  }

  /// 호칭.
  final String? honorific;

  /// 양력·음력.
  final CalendarType? calendar;

  /// 생년월일(달력 기준에 따른 값).
  final LunarOrSolarDate? date;

  /// 음력 윤달 여부. 양력이면 의미가 없습니다.
  final bool isLeapMonth;

  /// 태어난 시간(모름 포함).
  final BirthTime? time;

  /// 성별.
  final BirthGenderEnum? gender;

  /// 출생 도시. 한국 밖일 때만 받습니다.
  final City? city;

  /// 일부 값만 바꾼 사본을 만듭니다. 값을 null로 되돌리려면 `clear*` 인자를 씁니다.
  OnboardingDraft copyWith({
    String? honorific,
    CalendarType? calendar,
    LunarOrSolarDate? date,
    bool? isLeapMonth,
    BirthTime? time,
    BirthGenderEnum? gender,
    City? city,
    bool clearCity = false,
  }) => OnboardingDraft(
    honorific: honorific ?? this.honorific,
    calendar: calendar ?? this.calendar,
    date: date ?? this.date,
    isLeapMonth: isLeapMonth ?? this.isLeapMonth,
    time: time ?? this.time,
    gender: gender ?? this.gender,
    city: clearCity ? null : city ?? this.city,
  );

  /// 로컬 저장용 JSON입니다.
  Map<String, Object?> toJson() => {
    'v': _draftFormatVersion,
    'honorific': honorific,
    'calendar': calendar?.name,
    'date': date == null
        ? null
        : {'year': date!.year, 'month': date!.month, 'day': date!.day},
    'isLeapMonth': isLeapMonth,
    'time': time == null
        ? null
        : {'status': time!.status.name, 'value': time!.value},
    'gender': gender?.name,
    'city': city == null
        ? null
        : {
            'id': city!.id,
            'name': city!.name,
            'country': city!.country,
            'countryName': city!.countryName,
            'regionName': city!.regionName,
            'timezone': city!.timezone,
            'longitude': city!.longitude,
          },
  };

  /// 프로필을 만들 만큼 다 받았는지 봅니다. 한국 밖이면 도시까지 요구합니다.
  bool isCompleteFor({required bool deviceRegionIsKorea}) {
    final name = honorific?.trim() ?? '';
    final hasBirthInputs =
        calendar != null && date != null && time != null && gender != null;
    return name.isNotEmpty &&
        hasBirthInputs &&
        (deviceRegionIsKorea || city != null);
  }

  /// 계약 모델 [Birth]로 바꿉니다. 필수 값이 비었으면 [StateError]입니다.
  ///
  /// 한국 기기([deviceRegionIsKorea])면 도시를 무시하고 `not_asked`·`Asia/Seoul`입니다.
  Birth toBirth({required bool deviceRegionIsKorea}) {
    final calendar = this.calendar;
    final date = this.date;
    final time = this.time;
    final gender = this.gender;
    if (calendar == null || date == null || time == null || gender == null) {
      throw StateError('생년월일·시간·성별을 모두 받기 전에는 Birth를 만들 수 없습니다.');
    }
    // 한국 기기는 출생지를 묻지 않으므로 남은 도시가 있어도 쓰지 않습니다(D29).
    final city = deviceRegionIsKorea ? null : this.city;
    return Birth(
      calendar: calendar,
      date: date,
      isLeapMonth: calendar == CalendarType.lunar && isLeapMonth,
      time: time,
      gender: gender,
      timezone: city?.timezone ?? _koreaTimezone,
      place: city == null
          ? BirthPlace(status: BirthPlaceStatusEnum.notAsked)
          : BirthPlace(status: BirthPlaceStatusEnum.city, cityId: city.id),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OnboardingDraft &&
          other.honorific == honorific &&
          other.calendar == calendar &&
          other.date == date &&
          other.isLeapMonth == isLeapMonth &&
          other.time == time &&
          other.gender == gender &&
          other.city == city;

  @override
  int get hashCode =>
      Object.hash(honorific, calendar, date, isLeapMonth, time, gender, city);
}

LunarOrSolarDate _dateFromJson(Map<String, Object?> json) {
  final year = json['year']! as int;
  final month = json['month']! as int;
  final day = json['day']! as int;
  if (year < 1900 || year > 2099 || month < 1 || month > 12) {
    throw FormatException('날짜 범위를 벗어났습니다: $year-$month');
  }
  if (day < 1 || day > 31) {
    throw FormatException('날짜 범위를 벗어났습니다: $day일');
  }
  return LunarOrSolarDate(year: year, month: month, day: day);
}

BirthTime _timeFromJson(Map<String, Object?> json) {
  final value = json['value'] as String?;
  if (value != null && !_timePattern.hasMatch(value)) {
    throw FormatException('시간 형식이 아닙니다: $value');
  }
  return BirthTime(
    status: BirthTimeStatusEnum.values.byName(json['status']! as String),
    value: value,
  );
}

/// 경도가 없는 옛 입력(계약에 `City.longitude`가 생기기 전 저장분)은 도시를 고르지 않은
/// 것으로 봅니다. 해외 기기는 진입 계산이 `birthplace`로 도시를 다시 받습니다.
City? _cityFromJson(Map<String, Object?> json) {
  final longitude = json['longitude'] as num?;
  if (longitude == null) {
    return null;
  }
  final country = json['country']! as String;
  return City(
    id: json['id']! as String,
    name: json['name']! as String,
    country: country,
    // 계약 draft.3 전에 저장한 입력에는 나라 이름이 없습니다. 다시 고르게 하지 않고
    // 나라 코드로 채웁니다(프로필 저장에는 도시 id와 시간대만 쓰입니다).
    countryName: json['countryName'] as String? ?? country,
    regionName: json['regionName'] as String?,
    timezone: json['timezone']! as String,
    longitude: longitude,
  );
}
