import 'dart:math';

import 'package:unorm_dart/unorm_dart.dart' as unorm;

/// 화면에 보이는 문자열 [shown]의 마지막 글자 받침 종류를 돌려줍니다(writing 호칭·조사 규칙 v1.2, D84).
///
/// ko ui ARB의 조사 `select` 인자(`pJosa`)로 넘깁니다. 숫자·날짜·시각은 서식을 적용한 뒤의 문자열을
/// 넘깁니다. 예: `l10n.eventDueNotice(title, josaClass(title))`.
///
/// * `'final'`: 받침 있음(ㄹ 아님)
/// * `'rieul'`: ㄹ 받침
/// * `'none'`: 받침 없음
/// * `'other'`: 판정할 수 없음(ARB는 병기형을 씁니다)
///
/// 판정 순서는 NFC 정규화 → 한글 음절의 받침 → 숫자·영문·천간지지 한자의 읽는 소리 → 그 밖은 `'other'`입니다.
/// 읽기 표의 원본은 `docs/identity/writing/rules/josa.yaml`의 `readings`이고, 테스트가 그 파일의
/// `examples`로 결과를 맞춥니다.
String josaClass(String shown) {
  final text = unorm.nfc(shown);
  if (text.isEmpty) return _other;

  final last = text.runes.last;
  final direct = _hangulJosaClass(last);
  if (direct != null) return direct;

  final reading = _readingOf(text, last);
  if (reading == null) return _other;
  return _hangulJosaClass(reading.runes.last) ?? _other;
}

const String _final = 'final';
const String _rieul = 'rieul';
const String _none = 'none';
const String _other = 'other';

// 한글 음절 = 0xAC00 + (초성 * 21 + 중성) * 28 + 종성. 종성 0은 받침 없음, 8은 ㄹ 받침입니다.
const int _hangulFirst = 0xAC00;
const int _hangulLast = 0xD7A3;
const int _jongseongCount = 28;
const int _jongseongRieul = 8;

/// 한글 음절의 받침 종류입니다. 한글 음절이 아니면 null입니다.
String? _hangulJosaClass(int rune) {
  if (rune < _hangulFirst || rune > _hangulLast) return null;
  return switch ((rune - _hangulFirst) % _jongseongCount) {
    0 => _none,
    _jongseongRieul => _rieul,
    _ => _final,
  };
}

/// 마지막 글자 [last]의 한글 읽기입니다. 읽을 수 없으면 null입니다.
String? _readingOf(String text, int last) {
  if (_isAsciiDigit(last)) return _numberReading(text);
  // 소문자는 ASCII만 대문자로 바꿉니다. toUpperCase()는 ı·ſ 같은 글자도 I·S로 바꿉니다.
  final upper = _isAsciiLowercase(last) ? last - _asciiCaseOffset : last;
  final char = String.fromCharCode(upper);
  return _latinReadings[char] ?? _hanjaReadings[char];
}

const int _asciiCaseOffset = 0x20;

bool _isAsciiDigit(int rune) => rune >= 0x30 && rune <= 0x39;

bool _isAsciiLowercase(int rune) => rune >= 0x61 && rune <= 0x7A;

/// [text] 끝의 숫자 덩어리를 한 수로 보고 읽습니다.
/// 끝자리가 0이 아니거나 전부 0이면 끝자리 숫자를, 끝에 0이 이어지면 0의 개수별 자릿수(상한 만)를 읽습니다.
String _numberReading(String text) {
  var start = text.length;
  while (start > 0 && _isAsciiDigit(text.codeUnitAt(start - 1))) {
    start--;
  }
  final number = text.substring(start);
  final zeros = number.length - number.replaceFirst(RegExp(r'0+$'), '').length;
  if (zeros == 0 || zeros == number.length) {
    return _digitReadings[number[number.length - 1]]!;
  }
  return _trailingZeroReadings[min(zeros, _trailingZeroReadings.length) - 1];
}

// readings.digits
const Map<String, String> _digitReadings = {
  '0': '영',
  '1': '일',
  '2': '이',
  '3': '삼',
  '4': '사',
  '5': '오',
  '6': '육',
  '7': '칠',
  '8': '팔',
  '9': '구',
};

// readings.trailing_zeros. 인덱스 + 1이 끝에서 이어진 0의 개수입니다.
const List<String> _trailingZeroReadings = ['십', '백', '천', '만'];

// readings.latin
const Map<String, String> _latinReadings = {
  'A': '에이',
  'B': '비',
  'C': '씨',
  'D': '디',
  'E': '이',
  'F': '에프',
  'G': '지',
  'H': '에이치',
  'I': '아이',
  'J': '제이',
  'K': '케이',
  'L': '엘',
  'M': '엠',
  'N': '엔',
  'O': '오',
  'P': '피',
  'Q': '큐',
  'R': '알',
  'S': '에스',
  'T': '티',
  'U': '유',
  'V': '브이',
  'W': '더블유',
  'X': '엑스',
  'Y': '와이',
  'Z': '제트',
};

// readings.hanja: 천간 10자, 지지 12자
const Map<String, String> _hanjaReadings = {
  '甲': '갑',
  '乙': '을',
  '丙': '병',
  '丁': '정',
  '戊': '무',
  '己': '기',
  '庚': '경',
  '辛': '신',
  '壬': '임',
  '癸': '계',
  '子': '자',
  '丑': '축',
  '寅': '인',
  '卯': '묘',
  '辰': '진',
  '巳': '사',
  '午': '오',
  '未': '미',
  '申': '신',
  '酉': '유',
  '戌': '술',
  '亥': '해',
};
