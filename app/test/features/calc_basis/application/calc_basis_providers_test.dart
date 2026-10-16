import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/api/gen/api/default_api.dart';
import 'package:myungli_diary/core/api/gen/model/birth_time.dart';
import 'package:myungli_diary/core/api/gen/model/calendar_type.dart';
import 'package:myungli_diary/core/api/gen/model/city.dart';
import 'package:myungli_diary/core/api/gen/model/lunar_conversion.dart';
import 'package:myungli_diary/core/api/gen/model/lunar_date_request.dart';
import 'package:myungli_diary/core/api/gen/model/lunar_or_solar_date.dart';
import 'package:myungli_diary/core/api/gen/model/profile.dart';
import 'package:myungli_diary/core/storage/installation_id.dart';
import 'package:myungli_diary/features/calc_basis/application/calc_basis_providers.dart';
import 'package:myungli_diary/features/calc_basis/model/time_basis.dart';
import 'package:myungli_diary/features/onboarding/application/onboarding_providers.dart';
import 'package:myungli_diary/features/onboarding/model/onboarding_draft.dart';
import 'package:myungli_diary/features/profile/application/profile_providers.dart';

/// `convertLunarDate` 요청을 기록하는 대역. [solarDate]가 null이면 실패합니다.
class _FakeApi implements DefaultApi {
  new({this.solarDate});

  final String? solarDate;
  final requests = <LunarDateRequest>[];

  @override
  Future<Response<LunarConversion>> convertLunarDate({
    required LunarDateRequest lunarDateRequest,
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    requests.add(lunarDateRequest);
    final solarDate = this.solarDate;
    if (solarDate == null) {
      throw DioException.connectionError(
        requestOptions: RequestOptions(),
        reason: '연결 실패',
      );
    }
    return Response(
      requestOptions: RequestOptions(),
      data: LunarConversion(solarDate: solarDate, monthHasLeap: false),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// 정해 둔 온보딩 입력을 돌려주는 대역.
class _FixedDraft extends OnboardingDraftController {
  new(this._draft);

  final OnboardingDraft _draft;

  @override
  Future<OnboardingDraft> build() async => _draft;
}

Profile _profile({
  String calendar = 'solar',
  Map<String, Object?> place = const {'status': 'not_asked'},
}) => Profile.fromJson({
  'honorific': '하늘',
  'language': 'ko',
  'currentTimezone': 'Asia/Seoul',
  'birth': {
    'calendar': calendar,
    'date': {'year': 1990, 'month': 5, 'day': 5},
    'isLeapMonth': false,
    'time': {'status': 'known', 'value': '08:00'},
    'gender': 'female',
    'timezone': 'Asia/Seoul',
    'place': place,
  },
  'notification': {'status': 'not_asked'},
});

final City _newYork = City(
  id: '5128581',
  name: 'New York City',
  country: 'US',
  countryName: 'United States',
  timezone: 'America/New_York',
);

/// 서울 1990-05-05 08:00과 같은 입력입니다(뉴욕 08:00과 결과가 다르도록 서울 기준).
final OnboardingDraft _solarDraft = OnboardingDraft(
  calendar: CalendarType.solar,
  date: LunarOrSolarDate(year: 1990, month: 5, day: 5),
  time: BirthTime(status: BirthTimeStatusEnum.known, value: '08:00'),
);

ProviderContainer _container({
  required _FakeApi api,
  Profile? profile,
  OnboardingDraft draft = const OnboardingDraft(),
  String region = 'KR',
}) {
  final container = ProviderContainer(
    overrides: [
      localeProvider.overrideWithValue(Locale('ko', region)),
      restClientProvider.overrideWithValue(api),
      installationIdProvider.overrideWith((ref) async => 'install-1'),
      cachedProfileProvider.overrideWith((ref) async => profile),
      onboardingDraftProvider.overrideWith(() => _FixedDraft(draft)),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

const TimeBasis _seoul0800 = TimeBasis(
  longitude: 127.5,
  correctionMinutes: -30,
);

void main() {
  test('프로필 사본이 있으면 온보딩 입력보다 먼저 씁니다', () async {
    final container = _container(
      api: _FakeApi(),
      profile: _profile(),
      draft: OnboardingDraft(
        calendar: CalendarType.solar,
        date: LunarOrSolarDate(year: 1955, month: 6, day: 15),
        time: BirthTime(status: BirthTimeStatusEnum.known, value: '08:00'),
      ),
    );

    expect(await container.read(calcBasisTimeBasisProvider.future), _seoul0800);
  });

  test('프로필에서 도시를 골랐으면 온보딩 입력으로 넘어가지 않고 null입니다(A29)', () async {
    final container = _container(
      api: _FakeApi(),
      profile: _profile(place: {'status': 'city', 'cityId': '5128581'}),
      draft: _solarDraft,
    );

    expect(await container.read(calcBasisTimeBasisProvider.future), isNull);
  });

  test('프로필이 없으면 온보딩 입력을 씁니다', () async {
    final container = _container(api: _FakeApi(), draft: _solarDraft);

    expect(await container.read(calcBasisTimeBasisProvider.future), _seoul0800);
  });

  test('온보딩 입력에서 도시를 골랐으면 null입니다(A29)', () async {
    final container = _container(
      api: _FakeApi(),
      draft: _solarDraft.copyWith(city: _newYork),
      region: 'US',
    );

    expect(await container.read(calcBasisTimeBasisProvider.future), isNull);
  });

  test('한국 기기에 남은 도시는 프로필처럼 버리고 서울 기준입니다(D29)', () async {
    final container = _container(
      api: _FakeApi(),
      draft: _solarDraft.copyWith(city: _newYork),
    );

    expect(await container.read(calcBasisTimeBasisProvider.future), _seoul0800);
  });

  test('날짜가 없으면 null입니다', () async {
    final container = _container(api: _FakeApi());

    expect(await container.read(calcBasisTimeBasisProvider.future), isNull);
  });

  test('음력이면 양력으로 바꾼 날짜로 계산합니다', () async {
    final api = _FakeApi(solarDate: '1955-06-15');
    final container = _container(
      api: api,
      draft: OnboardingDraft(
        calendar: CalendarType.lunar,
        date: LunarOrSolarDate(year: 1955, month: 4, day: 25),
        isLeapMonth: true,
        time: BirthTime(status: BirthTimeStatusEnum.known, value: '08:00'),
      ),
    );

    expect(
      await container.read(calcBasisTimeBasisProvider.future),
      const TimeBasis(
        longitude: 127.5,
        correctionMinutes: 0,
        daylightSavingMinutes: 60,
      ),
    );
    final request = api.requests.single;
    expect(request.date, LunarOrSolarDate(year: 1955, month: 4, day: 25));
    expect(request.isLeapMonth, isTrue);
  });

  test('음력 변환이 실패하면 null입니다(A29)', () async {
    final container = _container(
      api: _FakeApi(),
      profile: _profile(calendar: 'lunar'),
    );

    expect(await container.read(calcBasisTimeBasisProvider.future), isNull);
  });
}
