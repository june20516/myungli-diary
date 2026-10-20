import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/gen/model/lunar_or_solar_date.dart';
import 'package:myungli_diary/features/calc_basis/application/calc_basis_providers.dart';

/// 음력 생일 확인에 묻는 값.
typedef LunarBirthQuery = ({int year, int month, int day, bool leap});

/// 음력 생일 하나를 확인한 결과(V31 목표 모양, A20 ④).
@immutable
final class LunarBirthCheck {
  /// 결과를 만듭니다. [solarDate]와 [dayError] 중 하나만 있습니다.
  const new({required this.monthHasLeap, this.solarDate, this.dayError})
    : assert((solarDate == null) != (dayError == null), '날짜와 오류 중 하나만 있습니다.');

  /// 물은 달에 윤달이 있는지.
  final bool monthHasLeap;

  /// 양력으로 바꾼 날짜.
  final DateTime? solarDate;

  /// 그 달에 없는 날(422 `date.invalid`, 예 작은달의 30일)일 때의 오류.
  final ProblemError? dayError;
}

/// [LunarBirthQuery]를 `convertLunarDate`로 확인합니다.
///
/// 먼저 그 달 1일·평달로 물어 그 달에 윤달이 있는지 알고(server 안내 #165 ②), 고른 날(윤달이면
/// 윤달)로 한 번 더 물어 양력 날짜를 받습니다. 1일·평달이면 한 번으로 끝납니다. 윤달을 골랐는데
/// 그 달에 윤달이 없으면 평달로 바꿔 묻습니다. 그 달에 없는 날이면 [LunarBirthCheck.dayError]이고,
/// 연결 오류·범위 밖 등 그 밖의 실패는 오류 상태입니다. 자동 재시도는 하지 않습니다(휠을 다시
/// 돌리면 다시 묻습니다).
final FutureProviderFamily<LunarBirthCheck, LunarBirthQuery>
lunarBirthCheckProvider = FutureProvider.autoDispose
    .family<LunarBirthCheck, LunarBirthQuery>((ref, query) async {
      final repository = ref.watch(lunarDateRepositoryProvider);
      final first = await repository.convert(
        LunarOrSolarDate(year: query.year, month: query.month, day: 1),
        isLeapMonth: false,
      );
      final leap = query.leap && first.monthHasLeap;
      if (query.day == 1 && !leap) {
        return LunarBirthCheck(
          monthHasLeap: first.monthHasLeap,
          solarDate: first.solarDate,
        );
      }
      try {
        final exact = await repository.convert(
          LunarOrSolarDate(
            year: query.year,
            month: query.month,
            day: query.day,
          ),
          isLeapMonth: leap,
        );
        return LunarBirthCheck(
          monthHasLeap: first.monthHasLeap,
          solarDate: exact.solarDate,
        );
      } on ProblemError catch (error) {
        if (error.code != 'date.invalid') rethrow;
        return LunarBirthCheck(
          monthHasLeap: first.monthHasLeap,
          dayError: error,
        );
      }
    }, retry: (_, _) => null);
