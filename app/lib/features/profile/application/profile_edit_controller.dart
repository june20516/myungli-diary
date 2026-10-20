import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show NotifierProviderFamily;
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/gen/model/birth.dart';
import 'package:myungli_diary/core/api/gen/model/birth_place.dart';
import 'package:myungli_diary/core/api/gen/model/birth_time.dart';
import 'package:myungli_diary/core/api/gen/model/calendar_type.dart';
import 'package:myungli_diary/core/api/gen/model/city.dart';
import 'package:myungli_diary/core/api/gen/model/lunar_or_solar_date.dart';
import 'package:myungli_diary/core/api/gen/model/profile.dart';
import 'package:myungli_diary/core/api/gen/model/profile_patch.dart';
import 'package:myungli_diary/core/platform/crash_reporter.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';
import 'package:myungli_diary/design/components/input/date_picker.dart';
import 'package:myungli_diary/features/profile/application/profile_providers.dart';

/// 바꾸면 사주를 다시 계산하는 무거운 항목(A62). 순서는 화면 줄과 확인 창 본문의 순서입니다.
enum BirthField {
  /// 생일(양력·음력, 윤달 포함).
  date,

  /// 태어난 시간(모름 포함).
  time,

  /// 성별.
  gender,

  /// 출생지.
  place,
}

/// 출생지 값. 도시를 고르지 않았으면(묻지 않음·건너뜀) 한국 기준입니다(D29).
///
/// 같은지는 도시 id로만 봅니다. 사본에는 이름(`Profile.birthCity`)이 없을 수 있습니다.
@immutable
final class BirthplaceValue {
  /// 한국 기준(도시 없음).
  const new korea() : cityId = null, city = null;

  /// [cityId] 도시. 이름을 알면 [city]를 함께 둡니다.
  const new city(String this.cityId, {this.city});

  /// 도시 id. null이면 한국 기준입니다.
  final String? cityId;

  /// 도시 정보. 이름을 모르면 null입니다.
  final City? city;

  @override
  bool operator ==(Object other) =>
      other is BirthplaceValue && other.cityId == cityId;

  @override
  int get hashCode => cityId.hashCode;
}

/// 정보 수정 화면에서 돌아온 무거운 항목 값(화면 안 변경, 아직 저장하지 않음). null은 손대지
/// 않은 항목입니다.
@immutable
final class BirthEdits {
  /// 화면 안 변경을 만듭니다.
  const new({this.date, this.time, this.gender, this.city});

  /// 바꾼 생일.
  final BirthDateValue? date;

  /// 바꾼 태어난 시간.
  final BirthTime? time;

  /// 바꾼 성별.
  final BirthGenderEnum? gender;

  /// 고른 출생 도시.
  final City? city;

  /// 일부 항목만 바꾼 사본입니다.
  BirthEdits copyWith({
    BirthDateValue? date,
    BirthTime? time,
    BirthGenderEnum? gender,
    City? city,
  }) => BirthEdits(
    date: date ?? this.date,
    time: time ?? this.time,
    gender: gender ?? this.gender,
    city: city ?? this.city,
  );
}

/// 무거운 항목의 값 묶음. 사본([BirthValues.of])이나 사본에 화면 안 변경을 더한 값입니다.
@immutable
final class BirthValues {
  /// 값을 만듭니다.
  const new({
    required this.date,
    required this.time,
    required this.gender,
    required this.place,
  });

  /// 프로필 [profile]의 값입니다.
  factory of(Profile profile) {
    final birth = profile.birth;
    final cityId = birth.place.status == BirthPlaceStatusEnum.city
        ? birth.place.cityId
        : null;
    final city = profile.birthCity;
    return BirthValues(
      date: BirthDateValue(
        calendar: birth.calendar == CalendarType.lunar
            ? BirthCalendar.lunar
            : BirthCalendar.solar,
        year: birth.date.year,
        month: birth.date.month,
        day: birth.date.day,
        isLeapMonth: birth.calendar == CalendarType.lunar && birth.isLeapMonth,
      ),
      time: birth.time,
      gender: birth.gender,
      place: cityId == null
          ? const BirthplaceValue.korea()
          : BirthplaceValue.city(
              cityId,
              city: city?.id == cityId ? city : null,
            ),
    );
  }

  /// 생일.
  final BirthDateValue date;

  /// 태어난 시간.
  final BirthTime time;

  /// 성별.
  final BirthGenderEnum gender;

  /// 출생지.
  final BirthplaceValue place;

  /// [edits]를 더한 값입니다.
  BirthValues applying(BirthEdits edits) {
    final city = edits.city;
    return BirthValues(
      date: edits.date ?? date,
      time: edits.time ?? time,
      gender: edits.gender ?? gender,
      place: city == null ? place : BirthplaceValue.city(city.id, city: city),
    );
  }

  /// [before]와 다른 항목입니다([BirthField] 순서).
  List<BirthField> changesFrom(BirthValues before) => [
    for (final field in BirthField.values)
      if (_valueOf(field) != before._valueOf(field)) field,
  ];

  Object _valueOf(BirthField field) => switch (field) {
    BirthField.date => date,
    BirthField.time => time,
    BirthField.gender => gender,
    BirthField.place => place,
  };
}

/// 사본의 출생 정보 [base]에 [edits]를 더한 저장 값입니다.
///
/// 도시를 골랐으면 기기 지역과 상관없이 그 도시와 시간대로 저장합니다. 온보딩의
/// `OnboardingDraft.toBirth`는 한국 기기면 도시를 버리지만(D29), 정보 수정은 해외에서 태어나
/// 한국에 사는 사람이 출생지를 지정하는 곳입니다.
Birth birthWithEdits(Birth base, BirthEdits edits) {
  final date = edits.date;
  final city = edits.city;
  final calendar = date == null
      ? base.calendar
      : date.calendar == BirthCalendar.lunar
      ? CalendarType.lunar
      : CalendarType.solar;
  return Birth(
    calendar: calendar,
    date: date == null
        ? base.date
        : LunarOrSolarDate(year: date.year, month: date.month, day: date.day),
    isLeapMonth: date == null
        ? base.isLeapMonth
        : calendar == CalendarType.lunar && date.isLeapMonth,
    time: edits.time ?? base.time,
    gender: edits.gender ?? base.gender,
    timezone: city?.timezone ?? base.timezone,
    place: city == null
        ? base.place
        : BirthPlace(status: BirthPlaceStatusEnum.city, cityId: city.id),
  );
}

/// `profile-edit` 화면의 상태.
@immutable
final class ProfileEditState {
  /// 상태를 만듭니다.
  const new({
    this.edits = const BirthEdits(),
    this.savingHonorific,
    this.savingBirth = false,
    this.error,
  });

  /// 화면 안 변경(무거운 항목).
  final BirthEdits edits;

  /// 저장 중인 호칭. 저장 중이 아니면 null입니다.
  final String? savingHonorific;

  /// 무거운 변경을 저장 중인지.
  final bool savingBirth;

  /// 마지막 무거운 변경 저장의 실패(`profile-edit:error`). 값을 또 바꾸거나 다시 저장하면
  /// 풀립니다.
  final AppError? error;
}

/// `profile-edit`의 화면 안 변경과 저장(결정 A62).
///
/// * 호칭은 가벼운 변경이라 돌아오면 바로 PATCH합니다([saveHonorific]).
/// * 무거운 항목(생일·시간·성별·출생지)은 [BirthEdits]로 들고 있다가, 화면이 확인 창을 받은 뒤
///   [saveBirth]로 한 번에 PATCH합니다. 성공하면 바뀌기 전 사주의 캐시를 지웁니다
///   (`ProfileRepository.changeBirth`). 실패하면 바꾼 값과 이전 캐시를 그대로 두고 오류를
///   상태에 남깁니다(Review Focus 1).
/// * 같은 저장이 진행 중이면 다시 보내지 않고 진행 중인 시도를 돌려줍니다(두 번 누르기,
///   Review Focus 2).
/// * 예상 밖 오류(플랫폼)는 요약만 crash 기록에 남깁니다(D64: 출생 정보·호칭은 싣지 않음).
class ProfileEditController extends Notifier<ProfileEditState> {
  /// [initialCity]가 있으면 출생지를 그 도시로 바꾼 채 시작합니다(settings 출생지 안내).
  new(this.initialCity);

  /// 화면을 열 때 넘겨받은 도시(`extra`).
  final City? initialCity;

  Future<void>? _honorificAttempt;
  Future<bool>? _birthAttempt;

  @override
  ProfileEditState build() =>
      ProfileEditState(edits: BirthEdits(city: initialCity));

  /// 생일을 [value]로 바꿉니다(저장하지 않음).
  void editDate(BirthDateValue value) =>
      _edit(state.edits.copyWith(date: value));

  /// 태어난 시간을 [value]로 바꿉니다(저장하지 않음).
  void editTime(BirthTime value) => _edit(state.edits.copyWith(time: value));

  /// 성별을 [value]로 바꿉니다(저장하지 않음).
  void editGender(BirthGenderEnum value) =>
      _edit(state.edits.copyWith(gender: value));

  /// 출생지를 [city]로 바꿉니다(저장하지 않음).
  void editCity(City city) => _edit(state.edits.copyWith(city: city));

  /// 값을 바꾸면 이전 실패는 풀리고, 저장은 다시 확인 창부터입니다.
  void _edit(BirthEdits edits) => state = ProfileEditState(
    edits: edits,
    savingHonorific: state.savingHonorific,
    savingBirth: state.savingBirth,
  );

  /// 호칭을 [honorific]으로 저장합니다(PATCH, `honorific`만). 실패하면 [AppError]를 던지고
  /// 사본은 그대로입니다.
  Future<void> saveHonorific(String honorific) {
    final running = _honorificAttempt;
    if (running != null) {
      if (state.savingHonorific != honorific) {
        throw StateError('호칭 저장이 진행 중입니다. 끝난 뒤 다른 값을 저장하세요.');
      }
      return running;
    }
    state = ProfileEditState(
      edits: state.edits,
      savingHonorific: honorific,
      savingBirth: state.savingBirth,
      error: state.error,
    );
    final attempt =
        _guard(
          () => ref
              .read(profileRepositoryProvider)
              .update(ProfilePatch(honorific: honorific)),
        ).whenComplete(() {
          _honorificAttempt = null;
          if (ref.mounted) {
            state = ProfileEditState(
              edits: state.edits,
              savingBirth: state.savingBirth,
              error: state.error,
            );
          }
        });
    return _honorificAttempt = attempt;
  }

  /// 사본 [base]에 화면 안 변경을 더해 저장합니다. 성공하면 true입니다.
  ///
  /// 실패하면 false이고 오류는 [ProfileEditState.error]에 남습니다.
  Future<bool> saveBirth(Profile base) =>
      _birthAttempt ??= _saveBirth(birthWithEdits(base.birth, state.edits));

  Future<bool> _saveBirth(Birth birth) async {
    state = ProfileEditState(
      edits: state.edits,
      savingHonorific: state.savingHonorific,
      savingBirth: true,
    );
    try {
      await _guard(
        () => ref.read(profileRepositoryProvider).changeBirth(birth),
      );
    } on AppError catch (error) {
      if (ref.mounted) {
        state = ProfileEditState(
          edits: state.edits,
          savingHonorific: state.savingHonorific,
          error: error,
        );
      }
      return false;
    } finally {
      _birthAttempt = null;
    }
    if (ref.mounted) {
      // 저장한 값은 이제 사본입니다.
      state = ProfileEditState(savingHonorific: state.savingHonorific);
    }
    return true;
  }

  Future<void> _guard(Future<Object?> Function() action) async {
    try {
      await action();
    } on AppError {
      rethrow;
    } on Object catch (error, stack) {
      ref.read(crashReporterProvider).record(CrashSummary.from(error), stack);
      throw UnexpectedError(error);
    }
  }
}

/// `profile-edit` 화면의 상태. 화면이 보이는 동안만 둡니다. 인자는 열 때 넘겨받은 출생 도시
/// (`extra`, settings 출생지 안내)이고 없으면 null입니다.
final NotifierProviderFamily<ProfileEditController, ProfileEditState, City?>
profileEditControllerProvider = NotifierProvider.autoDispose
    .family<ProfileEditController, ProfileEditState, City?>(
      ProfileEditController.new,
    );
