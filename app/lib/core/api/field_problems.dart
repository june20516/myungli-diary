import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/gen/model/language.dart';
import 'package:myungli_diary/core/platform/device_locale.dart';

/// 프로필 입력 칸에 붙이는 필드 오류 위치(JSON Pointer)입니다.
const ({
  String honorific,
  String birthDate,
  String birthTime,
  String birthPlace,
})
profilePointers = (
  honorific: '/honorific',
  birthDate: '/birth/date',
  birthTime: '/birth/time',
  birthPlace: '/birth/place',
);

/// [error]의 필드 오류 중 위치가 [pointer]와 같거나 그 아래인 첫 항목을 돌려줍니다.
///
/// `/birth/time/value`는 `/birth/time` 칸에 붙습니다. `/birth/timezone`처럼
/// 이름만 앞부분이 같은 위치는 포함하지 않습니다.
FieldProblem? fieldProblemAt(AppError error, String pointer) {
  if (error is! ProblemError) {
    return null;
  }
  for (final problem in error.fieldErrors) {
    if (problem.pointer == pointer || problem.pointer.startsWith('$pointer/')) {
      return problem;
    }
  }
  return null;
}

/// 호칭 입력 칸의 글자 수 상한입니다(프로필 언어 기준).
///
/// 스키마 상한은 20이지만 server 규칙(`name.too_long`)이 ko·ja 10, en 20입니다.
/// 모르는 언어는 기본 언어(en)로 봅니다([knownLanguageOf]).
int honorificMaxLength(Language language) =>
    switch (knownLanguageOf(language)) {
      Language.ko || Language.ja => 10,
      Language.en || Language.unknownDefaultOpenApi => 20,
    };
