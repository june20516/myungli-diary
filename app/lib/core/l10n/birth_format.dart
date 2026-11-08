import 'package:intl/intl.dart';
import 'package:myungli_diary/core/api/gen/model/birth.dart';
import 'package:myungli_diary/core/api/gen/model/branch.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';

/// [locale]의 연월일 모양(`yMMMMd`, 예 "1990년 5월 15일")으로 쓰되, 날 칸은 [day] 숫자를
/// 그대로 넣습니다.
///
/// 음력 날은 양력 달력에 없는 날(2월 30일)일 수 있어 날짜 계산 없이 날 숫자를 씁니다.
String formatBirthDay(String locale, int year, int month, int day) =>
    _formatWithDay(
      DateFormat.yMMMMd(locale).pattern!,
      locale,
      year,
      month,
      day,
    );

/// [locale]의 숫자 연월일 모양(`yMd`, 예 ko "1990. 5. 15.")입니다. 날 칸은
/// [formatBirthDay]처럼 [day] 숫자를 그대로 넣습니다(사주 표 출생 정보 줄).
String formatBirthDayNumeric(String locale, int year, int month, int day) =>
    _formatWithDay(DateFormat.yMd(locale).pattern!, locale, year, month, day);

String _formatWithDay(
  String pattern,
  String locale,
  int year,
  int month,
  int day,
) {
  final buffer = StringBuffer();
  var quoted = false;
  for (var i = 0; i < pattern.length; i++) {
    final char = pattern[i];
    if (char == "'") {
      quoted = !quoted;
      buffer.write(char);
    } else if (!quoted && char == 'd') {
      // 날 칸(d, dd)을 글자 그대로의 숫자로 바꿉니다.
      while (i + 1 < pattern.length && pattern[i + 1] == 'd') {
        i++;
      }
      buffer.write("'$day'");
    } else {
      buffer.write(char);
    }
  }
  return DateFormat(buffer.toString(), locale).format(DateTime(year, month));
}

/// 태어난 시각 `HH:mm`([value])을 [locale]의 시각(예 "오후 2:30")으로 씁니다. 형식이 맞지
/// 않으면 받은 값 그대로입니다.
String formatBirthClock(String locale, String value) {
  final parts = value.split(':');
  final hour = int.tryParse(parts.first);
  final minute = parts.length == 2 ? int.tryParse(parts.last) : null;
  if (hour == null || minute == null) return value;
  return DateFormat.jm(locale).format(DateTime(2000, 1, 1, hour, minute));
}

/// 지지 [branch]의 이름(ARB `branch*`, '시' 없이). 시진 확인 줄과 출생 정보 줄 시진 칸이
/// 원고 틀(`{branch}시`)에 넣습니다.
String branchName(AppLocalizations l10n, Branch branch) => switch (branch) {
  Branch.ja => l10n.branchJa,
  Branch.chuk => l10n.branchChuk,
  Branch.in_ => l10n.branchIn,
  Branch.myo => l10n.branchMyo,
  Branch.jin => l10n.branchJin,
  Branch.sa => l10n.branchSa,
  Branch.o => l10n.branchO,
  Branch.mi => l10n.branchMi,
  Branch.shin => l10n.branchShin,
  Branch.yu => l10n.branchYu,
  Branch.sul => l10n.branchSul,
  Branch.hae => l10n.branchHae,
};

/// 성별 글자(출생 정보 입력, 정보 수정, 사주 표 출생 정보 줄).
String genderLabel(AppLocalizations l10n, BirthGenderEnum gender) =>
    switch (gender) {
      BirthGenderEnum.female => l10n.genderFemale,
      BirthGenderEnum.male => l10n.genderMale,
    };
