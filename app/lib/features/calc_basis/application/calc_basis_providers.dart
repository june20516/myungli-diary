import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/api/gen/model/birth_place.dart';
import 'package:myungli_diary/core/api/gen/model/birth_time.dart';
import 'package:myungli_diary/core/api/gen/model/calendar_type.dart';
import 'package:myungli_diary/core/api/gen/model/lunar_or_solar_date.dart';
import 'package:myungli_diary/core/api/gen/model/profile.dart';
import 'package:myungli_diary/core/platform/device_locale.dart';
import 'package:myungli_diary/core/storage/installation_id.dart';
import 'package:myungli_diary/features/calc_basis/data/lunar_date_repository.dart';
import 'package:myungli_diary/features/calc_basis/model/time_basis.dart';
import 'package:myungli_diary/features/onboarding/application/onboarding_providers.dart';
import 'package:myungli_diary/features/onboarding/model/onboarding_draft.dart';
import 'package:myungli_diary/features/profile/application/profile_providers.dart';

/// 한국 출생으로 가정할 때의 시간대입니다(D29, 온보딩 `toBirth`와 같음).
const String _koreaTimezone = 'Asia/Seoul';

/// 음력 → 양력 변환 저장소.
final lunarDateRepositoryProvider = Provider<LunarDateRepository>(
  (ref) => LunarDateRepository(
    ref.watch(restClientProvider),
    () => ref.read(installationIdProvider.future),
  ),
);

/// 계산 기준 화면의 경도 보정 기준(A28).
///
/// 입력은 프로필 사본(로그인 뒤), 없으면 온보딩 입력입니다. 도시를 골랐거나(도시 경도를 모름),
/// 생년월일·시간을 아직 받지 않았거나, 음력 변환이 실패하면 null이라 경도 문단을 그리지
/// 않습니다(A29).
final calcBasisTimeBasisProvider = FutureProvider<TimeBasis?>((ref) async {
  final repository = ref.watch(lunarDateRepositoryProvider);
  final profile = await ref.watch(cachedProfileProvider.future);
  // 프로필이 있으면 온보딩 입력은 보지 않습니다(바뀌어도 다시 계산하지 않음).
  final birth = profile != null
      ? _birthOfProfile(profile)
      : _birthOfDraft(
          await ref.watch(onboardingDraftProvider.future),
          deviceRegionIsKorea: ref.watch(deviceRegionIsKoreaProvider),
        );
  if (birth == null) {
    return null;
  }
  final DateTime solarDate;
  try {
    solarDate = await _solarDateOf(birth, repository);
  } on Object {
    // AppError뿐 아니라 예상 밖 예외도 문단을 그리지 않는 것으로 끝냅니다.
    return null;
  }
  return timeBasisOf(
    timezone: birth.timezone,
    solarDate: solarDate,
    time: birth.time,
  );
});

/// 경도 보정에 필요한 출생 입력. 도시를 고른 입력은 담지 않습니다.
typedef _BirthInput = ({
  CalendarType calendar,
  LunarOrSolarDate date,
  bool isLeapMonth,
  BirthTime time,
  String timezone,
});

/// 프로필 사본의 출생 입력. 도시를 골랐으면 null입니다.
_BirthInput? _birthOfProfile(Profile profile) {
  final birth = profile.birth;
  if (birth.place.status == BirthPlaceStatusEnum.city) {
    return null;
  }
  return (
    calendar: birth.calendar,
    date: birth.date,
    isLeapMonth: birth.isLeapMonth,
    time: birth.time,
    timezone: birth.timezone,
  );
}

/// 온보딩 입력의 출생 입력. 도시를 골랐거나 값이 비었으면 null입니다.
///
/// 한국 기기는 남은 도시를 쓰지 않고 서울 기준입니다(`OnboardingDraft.toBirth`와 같음).
_BirthInput? _birthOfDraft(
  OnboardingDraft draft, {
  required bool deviceRegionIsKorea,
}) {
  final calendar = draft.calendar;
  final date = draft.date;
  final time = draft.time;
  final city = deviceRegionIsKorea ? null : draft.city;
  if (city != null || calendar == null || date == null || time == null) {
    return null;
  }
  return (
    calendar: calendar,
    date: date,
    isLeapMonth: calendar == CalendarType.lunar && draft.isLeapMonth,
    time: time,
    timezone: _koreaTimezone,
  );
}

/// [birth]의 양력 날짜. 음력이면 [repository]로 바꿉니다.
Future<DateTime> _solarDateOf(
  _BirthInput birth,
  LunarDateRepository repository,
) async {
  final date = birth.date;
  if (birth.calendar == CalendarType.solar) {
    return DateTime(date.year, date.month, date.day);
  }
  return await repository.toSolar(date, isLeapMonth: birth.isLeapMonth);
}
