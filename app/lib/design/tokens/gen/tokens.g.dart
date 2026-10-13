// 생성 코드: dart run tool/gen_tokens.dart. 손으로 고치지 않습니다.

import 'dart:ui';

import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';
import 'package:myungli_diary/design/tokens/css_gradient.dart';

/// 의미 역할 색. 라이트·다크가 같은 이름을 씁니다.
final class ColorTokens {
  const ColorTokens({
    required this.ohaengWoodSwatch,
    required this.ohaengFireSwatch,
    required this.ohaengEarthSwatch,
    required this.ohaengMetalSwatch,
    required this.ohaengWaterSwatch,
    required this.bgBase,
    required this.bgSheet,
    required this.textPrimary,
    required this.textSecondary,
    required this.line,
    required this.actionPrimary,
    required this.actionOnPrimary,
    required this.termBg,
    required this.termFg,
    required this.badgeGoodBg,
    required this.badgeGoodFg,
    required this.badgeGwiinBg,
    required this.badgeGwiinFg,
    required this.badgeGisinBg,
    required this.badgeGisinFg,
    required this.badgeOrdinaryBorder,
    required this.badgeOrdinaryFg,
    required this.calendarGoodBg,
    required this.calendarCautionBg,
    required this.ohaengFireFg,
    required this.calendarWeekdaySun,
    required this.ohaengEarthFg,
    required this.calendarWeekdaySat,
    required this.inverseBg,
    required this.inverseFg,
    required this.disabledBg,
    required this.disabledFg,
    required this.sealKnock,
    required this.sealOnSoft,
    required this.sealFill,
    required this.sealSoft,
    required this.tagGoodBg,
    required this.tagGoodFg,
    required this.tagBadBg,
    required this.tagBadFg,
    required this.tagNeutralBorder,
    required this.tagNeutralFg,
    required this.chipBg,
    required this.swatchBorder,
    required this.statusBg,
    required this.statusFg,
    required this.timelineLine,
    required this.scrim,
    required this.barBg,
    required this.skeletonBone,
    required this.ohaengWoodBg,
    required this.ohaengWoodFg,
    required this.ohaengFireBg,
    required this.ohaengEarthBg,
    required this.ohaengMetalBg,
    required this.ohaengMetalFg,
    required this.ohaengWaterBg,
    required this.ohaengWaterFg,
  });

  /// 오행 견본: 색 자체를 보여주는 자리. 모드와 관계없이 같은 값이고 항상 swatch.border를 둡니다
  final Color ohaengWoodSwatch;

  /// 오행 견본: 색 자체를 보여주는 자리. 모드와 관계없이 같은 값이고 항상 swatch.border를 둡니다
  final Color ohaengFireSwatch;

  /// 오행 견본: 색 자체를 보여주는 자리. 모드와 관계없이 같은 값이고 항상 swatch.border를 둡니다
  final Color ohaengEarthSwatch;

  /// 오행 견본: 색 자체를 보여주는 자리. 모드와 관계없이 같은 값이고 항상 swatch.border를 둡니다
  final Color ohaengMetalSwatch;

  /// 오행 견본: 색 자체를 보여주는 자리. 모드와 관계없이 같은 값이고 항상 swatch.border를 둡니다
  final Color ohaengWaterSwatch;

  /// 기본 바탕
  final Color bgBase;

  /// 시트·패널 바탕
  final Color bgSheet;

  /// 본문 글자
  final Color textPrimary;

  /// 보조 글자
  final Color textSecondary;

  /// 선
  final Color line;

  /// 주 버튼 바탕
  final Color actionPrimary;

  /// 주 버튼 글자
  final Color actionOnPrimary;

  /// 용어 토큰 바탕 (굵게 하지 않음)
  final Color termBg;

  /// 용어 토큰 글자
  final Color termFg;

  /// 좋은 날(YONGSIN_DAY) 배지 바탕
  final Color badgeGoodBg;

  /// 좋은 날 배지 글자
  final Color badgeGoodFg;

  /// 귀인의 날(GWIIN_DAY) 배지 바탕
  final Color badgeGwiinBg;

  /// 귀인의 날 배지 글자
  final Color badgeGwiinFg;

  /// 기신의 날(GISIN_DAY) 배지 바탕
  final Color badgeGisinBg;

  /// 기신의 날 배지 글자
  final Color badgeGisinFg;

  /// 평범한 날(ORDINARY_DAY) 배지 테두리. 바탕은 없음
  final Color badgeOrdinaryBorder;

  /// 평범한 날 배지 글자
  final Color badgeOrdinaryFg;

  /// 캘린더 LuckLevel GOOD 날짜 칸 채우기. NEUTRAL은 채우지 않음
  final Color calendarGoodBg;

  /// 캘린더 LuckLevel CAUTION 날짜 칸 채우기
  final Color calendarCautionBg;

  /// 오행 글자
  final Color ohaengFireFg;

  /// 달력 요일 머리 '일'. 날짜 숫자에는 쓰지 않음
  final Color calendarWeekdaySun;

  /// 오행 글자
  final Color ohaengEarthFg;

  /// 달력 요일 머리 '토'. 날짜 숫자에는 쓰지 않음
  final Color calendarWeekdaySat;

  /// 토스트 바탕 (반전색)
  final Color inverseBg;

  /// 토스트 글자 (반전색)
  final Color inverseFg;

  /// 비활성 버튼 바탕
  final Color disabledBg;

  /// 비활성 글자. 대비 3:1 이상 (WCAG 1.4.3 비활성 예외)
  final Color disabledFg;

  /// 진한 낙관 도장 위에 새기는 날짜 숫자
  final Color sealKnock;

  /// 옅은 낙관 도장 위의 sage 글자 (선택된 날 숫자, 질문 카드 버튼 글자). action.primary 대신
  final Color sealOnSoft;

  /// 진한 낙관 도장 (선택된 탭, 반응, 일기 종이, 달력 오늘 윤곽선)
  final Color sealFill;

  /// 옅은 낙관 도장 (달력 일기 쓴 날, 일기 목록, 질문 카드 버튼 뒤)
  final Color sealSoft;

  /// 좋은 태그 칩 바탕 (배지 귀인과 같은 톤)
  final Color tagGoodBg;

  /// 좋은 태그 칩 글자
  final Color tagGoodFg;

  /// 나쁜 태그 칩 바탕
  final Color tagBadBg;

  /// 나쁜 태그 칩 글자
  final Color tagBadFg;

  /// 중립 태그 칩 테두리. 바탕은 없음
  final Color tagNeutralBorder;

  /// 중립 태그 칩 글자
  final Color tagNeutralFg;

  /// 칩 바탕 (반투명 흰색)
  final Color chipBg;

  /// 오행 견본 테두리
  final Color swatchBorder;

  /// 상태 꼬리표 바탕 (진행 중·다음·지금·올해)
  final Color statusBg;

  /// 상태 꼬리표 글자
  final Color statusFg;

  /// 일기 목록 세로 흐름 줄
  final Color timelineLine;

  /// 시트·확인 창 바깥 덮개
  final Color scrim;

  /// 반투명 탭 바 바탕. 투명도 줄이기가 켜지면 bg.sheet
  final Color barBg;

  /// skeleton 자리
  final Color skeletonBone;

  /// 원국표 칸처럼 글자가 얹히는 오행 바탕
  final Color ohaengWoodBg;

  /// 오행 글자
  final Color ohaengWoodFg;

  /// 원국표 칸처럼 글자가 얹히는 오행 바탕
  final Color ohaengFireBg;

  /// 원국표 칸처럼 글자가 얹히는 오행 바탕
  final Color ohaengEarthBg;

  /// 원국표 칸처럼 글자가 얹히는 오행 바탕
  final Color ohaengMetalBg;

  /// 오행 글자
  final Color ohaengMetalFg;

  /// 원국표 칸처럼 글자가 얹히는 오행 바탕
  final Color ohaengWaterBg;

  /// 오행 글자
  final Color ohaengWaterFg;
}

const lightColors = ColorTokens(
  ohaengWoodSwatch: Color(0xFF418E47),
  ohaengFireSwatch: Color(0xFFD24D45),
  ohaengEarthSwatch: Color(0xFFDEA645),
  ohaengMetalSwatch: Color(0xFFB4BFCA),
  ohaengWaterSwatch: Color(0xFF153E78),
  bgBase: Color(0xFFF7F7F6),
  bgSheet: Color(0xFFFFFFFF),
  textPrimary: Color(0xFF2B2B2A),
  textSecondary: Color(0xFF5B5B57),
  line: Color(0xFFDEDEDC),
  actionPrimary: Color(0xFF47634C),
  actionOnPrimary: Color(0xFFFFFFFF),
  termBg: Color(0xFFE8F2E9),
  termFg: Color(0xFF47634C),
  badgeGoodBg: Color(0xFFA75C53),
  badgeGoodFg: Color(0xFFFFFFFF),
  badgeGwiinBg: Color(0xFFFFE9E5),
  badgeGwiinFg: Color(0xFF814942),
  badgeGisinBg: Color(0xFFEEEEED),
  badgeGisinFg: Color(0xFF5B5B57),
  badgeOrdinaryBorder: Color(0xFFC7C7C5),
  badgeOrdinaryFg: Color(0xFF5B5B57),
  calendarGoodBg: Color(0xFFFFE9E5),
  calendarCautionBg: Color(0xFFEEEEED),
  ohaengFireFg: Color(0xFF733A35),
  calendarWeekdaySun: Color(0xFF733A35),
  ohaengEarthFg: Color(0xFF65470F),
  calendarWeekdaySat: Color(0xFF65470F),
  inverseBg: Color(0xFF2B2B2A),
  inverseFg: Color(0xFFEEEEED),
  disabledBg: Color(0xFFEEEEED),
  disabledFg: Color(0xFF747570),
  sealKnock: Color(0xFFF2F9F3),
  sealOnSoft: Color(0xFF354838),
  sealFill: Color(0xFF47634C),
  sealSoft: Color.from(
    alpha: 0.22,
    red: 0x47 / 255,
    green: 0x63 / 255,
    blue: 0x4c / 255,
  ),
  tagGoodBg: Color(0xFFFFE9E5),
  tagGoodFg: Color(0xFF814942),
  tagBadBg: Color(0xFFEEEEED),
  tagBadFg: Color(0xFF5B5B57),
  tagNeutralBorder: Color(0xFFC7C7C5),
  tagNeutralFg: Color(0xFF5B5B57),
  chipBg: Color.from(
    alpha: 0.7,
    red: 0xff / 255,
    green: 0xff / 255,
    blue: 0xff / 255,
  ),
  swatchBorder: Color.from(
    alpha: 0.18,
    red: 0x2b / 255,
    green: 0x2b / 255,
    blue: 0x2a / 255,
  ),
  statusBg: Color(0xFFE8F2E9),
  statusFg: Color(0xFF47634C),
  timelineLine: Color(0xFFDEDEDC),
  scrim: Color.from(
    alpha: 0.32,
    red: 0x1b / 255,
    green: 0x1b / 255,
    blue: 0x1a / 255,
  ),
  barBg: Color.from(
    alpha: 0.62,
    red: 0xff / 255,
    green: 0xff / 255,
    blue: 0xff / 255,
  ),
  skeletonBone: Color.from(
    alpha: 0.07,
    red: 0x2b / 255,
    green: 0x2b / 255,
    blue: 0x2a / 255,
  ),
  ohaengWoodBg: Color(0xFFDFF1DF),
  ohaengWoodFg: Color(0xFF2F5831),
  ohaengFireBg: Color(0xFFFFE4E0),
  ohaengEarthBg: Color(0xFFF7E9D5),
  ohaengMetalBg: Color(0xFFE8EBEF),
  ohaengMetalFg: Color(0xFF454E58),
  ohaengWaterBg: Color(0xFFE0ECFE),
  ohaengWaterFg: Color(0xFF304D78),
);

const darkColors = ColorTokens(
  ohaengWoodSwatch: Color(0xFF418E47),
  ohaengFireSwatch: Color(0xFFD24D45),
  ohaengEarthSwatch: Color(0xFFDEA645),
  ohaengMetalSwatch: Color(0xFFB4BFCA),
  ohaengWaterSwatch: Color(0xFF153E78),
  bgBase: Color(0xFF1B1B1A),
  bgSheet: Color(0xFF2B2B2A),
  textPrimary: Color(0xFFEEEEED),
  textSecondary: Color(0xFFABABA7),
  line: Color(0xFF424340),
  actionPrimary: Color(0xFFB8CEBC),
  actionOnPrimary: Color(0xFF1B1B1A),
  termBg: Color(0xFF354838),
  termFg: Color(0xFFD4E3D6),
  badgeGoodBg: Color(0xFFE8BBB4),
  badgeGoodFg: Color(0xFF2B2B2A),
  badgeGwiinBg: Color(0xFF5D3631),
  badgeGwiinFg: Color(0xFFF6D5D1),
  badgeGisinBg: Color(0xFF424340),
  badgeGisinFg: Color(0xFFDEDEDC),
  badgeOrdinaryBorder: Color(0xFF5B5B57),
  badgeOrdinaryFg: Color(0xFFABABA7),
  calendarGoodBg: Color(0xFF3B2522),
  calendarCautionBg: Color(0xFF2B2B2A),
  ohaengFireFg: Color(0xFFF7CCC6),
  calendarWeekdaySun: Color(0xFFF7CCC6),
  ohaengEarthFg: Color(0xFFEAD4B3),
  calendarWeekdaySat: Color(0xFFEAD4B3),
  inverseBg: Color(0xFFEEEEED),
  inverseFg: Color(0xFF2B2B2A),
  disabledBg: Color(0xFF424340),
  disabledFg: Color(0xFF8F908B),
  sealKnock: Color(0xFF2B2B2A),
  sealOnSoft: Color(0xFFD4E3D6),
  sealFill: Color(0xFFB8CEBC),
  sealSoft: Color.from(
    alpha: 0.28,
    red: 0xd4 / 255,
    green: 0xe3 / 255,
    blue: 0xd6 / 255,
  ),
  tagGoodBg: Color(0xFF5D3631),
  tagGoodFg: Color(0xFFF6D5D1),
  tagBadBg: Color(0xFF424340),
  tagBadFg: Color(0xFFDEDEDC),
  tagNeutralBorder: Color(0xFF5B5B57),
  tagNeutralFg: Color(0xFFABABA7),
  chipBg: Color.from(
    alpha: 0.08,
    red: 0xff / 255,
    green: 0xff / 255,
    blue: 0xff / 255,
  ),
  swatchBorder: Color.from(
    alpha: 0.28,
    red: 0xee / 255,
    green: 0xee / 255,
    blue: 0xed / 255,
  ),
  statusBg: Color(0xFF354838),
  statusFg: Color(0xFFD4E3D6),
  timelineLine: Color(0xFF424340),
  scrim: Color.from(
    alpha: 0.5,
    red: 0x00 / 255,
    green: 0x00 / 255,
    blue: 0x00 / 255,
  ),
  barBg: Color.from(
    alpha: 0.62,
    red: 0x2b / 255,
    green: 0x2b / 255,
    blue: 0x2a / 255,
  ),
  skeletonBone: Color.from(
    alpha: 0.08,
    red: 0xee / 255,
    green: 0xee / 255,
    blue: 0xed / 255,
  ),
  ohaengWoodBg: Color(0xFF213321),
  ohaengWoodFg: Color(0xFFC4E1C4),
  ohaengFireBg: Color(0xFF402623),
  ohaengEarthBg: Color(0xFF392B16),
  ohaengMetalBg: Color(0xFF2A2E33),
  ohaengMetalFg: Color(0xFFD3D8DE),
  ohaengWaterBg: Color(0xFF212E42),
  ohaengWaterFg: Color(0xFFC4D9F9),
);

/// 글자 스타일. 언어마다 글꼴과 행간·자간이 다릅니다.
final class TypeTokens {
  const TypeTokens({
    required this.sentenceCard,
    required this.sentenceBody,
    required this.display,
    required this.title,
    required this.subtitle,
    required this.labelLg,
    required this.labelMd,
    required this.captionMd,
    required this.captionSm,
    required this.captionLg,
    required this.numericCalendar,
    required this.numericTable,
    required this.hanjaPillar,
    required this.bodyUi,
  });

  /// 카드 문장
  final TextStyle sentenceCard;

  /// 일반 본문 (일기, 풀이)
  final TextStyle sentenceBody;

  /// 큰 제목
  final TextStyle display;

  /// 화면 제목
  final TextStyle title;

  /// 소제목
  final TextStyle subtitle;

  /// 버튼·탭
  final TextStyle labelLg;

  /// 칩·배지
  final TextStyle labelMd;

  /// 캡션·날짜
  final TextStyle captionMd;

  /// 원국표 칸 아래 표기
  final TextStyle captionSm;

  /// 배너, 이유 한 줄, 도움말, 칩 설명
  final TextStyle captionLg;

  /// 캘린더 날짜 (고정폭 숫자)
  final TextStyle numericCalendar;

  /// 대운·세운 표의 나이·연도 (고정폭 숫자)
  final TextStyle numericTable;

  /// 원국표 한자
  final TextStyle hanjaPillar;

  /// 확인 창 본문, 설정 줄, 일정 줄, 행 머리 표의 값
  final TextStyle bodyUi;
}

const koType = TypeTokens(
  sentenceCard: TextStyle(
    fontFamily: 'Gowun Dodum',
    fontFamilyFallback: ['Pretendard', 'sans-serif'],
    fontSize: 17,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.65,
  ),
  sentenceBody: TextStyle(
    fontFamily: 'Gowun Dodum',
    fontFamilyFallback: ['Pretendard', 'sans-serif'],
    fontSize: 15,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.6,
  ),
  display: TextStyle(
    fontFamily: 'Pretendard',
    fontFamilyFallback: ['sans-serif'],
    fontSize: 24,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.48,
    height: 1.25,
  ),
  title: TextStyle(
    fontFamily: 'Pretendard',
    fontFamilyFallback: ['sans-serif'],
    fontSize: 20,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.4,
    height: 1.3,
  ),
  subtitle: TextStyle(
    fontFamily: 'Pretendard',
    fontFamilyFallback: ['sans-serif'],
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.32,
    height: 1.4,
  ),
  labelLg: TextStyle(
    fontFamily: 'Pretendard',
    fontFamilyFallback: ['sans-serif'],
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.28,
    height: 1.3,
  ),
  labelMd: TextStyle(
    fontFamily: 'Pretendard',
    fontFamilyFallback: ['sans-serif'],
    fontSize: 13,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.26,
    height: 1.3,
  ),
  captionMd: TextStyle(
    fontFamily: 'Pretendard',
    fontFamilyFallback: ['sans-serif'],
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.24,
    height: 1.3,
  ),
  captionSm: TextStyle(
    fontFamily: 'Pretendard',
    fontFamilyFallback: ['sans-serif'],
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.22,
    height: 1.3,
  ),
  captionLg: TextStyle(
    fontFamily: 'Pretendard',
    fontFamilyFallback: ['sans-serif'],
    fontSize: 13,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.26,
    height: 1.45,
  ),
  numericCalendar: TextStyle(
    fontFamily: 'Pretendard',
    fontFamilyFallback: ['sans-serif'],
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
    height: 1.2,
    fontFeatures: [FontFeature.tabularFigures()],
  ),
  numericTable: TextStyle(
    fontFamily: 'Pretendard',
    fontFamilyFallback: ['sans-serif'],
    fontSize: 13,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
    height: 1.3,
    fontFeatures: [FontFeature.tabularFigures()],
  ),
  hanjaPillar: TextStyle(
    fontFamily: 'Pretendard JP',
    fontFamilyFallback: ['sans-serif'],
    fontSize: 17,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
    height: 1,
  ),
  bodyUi: TextStyle(
    fontFamily: 'Pretendard',
    fontFamilyFallback: ['sans-serif'],
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.28,
    height: 1.5,
  ),
);

const jaType = TypeTokens(
  sentenceCard: TextStyle(
    fontFamily: 'Zen Maru Gothic',
    fontFamilyFallback: ['Pretendard JP', 'sans-serif'],
    fontSize: 17,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.75,
  ),
  sentenceBody: TextStyle(
    fontFamily: 'Zen Maru Gothic',
    fontFamilyFallback: ['Pretendard JP', 'sans-serif'],
    fontSize: 15,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.7,
  ),
  display: TextStyle(
    fontFamily: 'Pretendard JP',
    fontFamilyFallback: ['sans-serif'],
    fontSize: 24,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.25,
  ),
  title: TextStyle(
    fontFamily: 'Pretendard JP',
    fontFamilyFallback: ['sans-serif'],
    fontSize: 20,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.3,
  ),
  subtitle: TextStyle(
    fontFamily: 'Pretendard JP',
    fontFamilyFallback: ['sans-serif'],
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.4,
  ),
  labelLg: TextStyle(
    fontFamily: 'Pretendard JP',
    fontFamilyFallback: ['sans-serif'],
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.3,
  ),
  labelMd: TextStyle(
    fontFamily: 'Pretendard JP',
    fontFamilyFallback: ['sans-serif'],
    fontSize: 13,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
    height: 1.3,
  ),
  captionMd: TextStyle(
    fontFamily: 'Pretendard JP',
    fontFamilyFallback: ['sans-serif'],
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
    height: 1.3,
  ),
  captionSm: TextStyle(
    fontFamily: 'Pretendard JP',
    fontFamilyFallback: ['sans-serif'],
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
    height: 1.3,
  ),
  captionLg: TextStyle(
    fontFamily: 'Pretendard JP',
    fontFamilyFallback: ['sans-serif'],
    fontSize: 13,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.45,
  ),
  numericCalendar: TextStyle(
    fontFamily: 'Pretendard JP',
    fontFamilyFallback: ['sans-serif'],
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
    height: 1.2,
    fontFeatures: [FontFeature.tabularFigures()],
  ),
  numericTable: TextStyle(
    fontFamily: 'Pretendard JP',
    fontFamilyFallback: ['sans-serif'],
    fontSize: 13,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
    height: 1.3,
    fontFeatures: [FontFeature.tabularFigures()],
  ),
  hanjaPillar: TextStyle(
    fontFamily: 'Pretendard JP',
    fontFamilyFallback: ['sans-serif'],
    fontSize: 17,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
    height: 1,
  ),
  bodyUi: TextStyle(
    fontFamily: 'Pretendard JP',
    fontFamilyFallback: ['sans-serif'],
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.5,
  ),
);

/// 그라데이션. 각도는 CSS 기준(0°=위쪽, 시계 방향)이며 박스 크기에 맞춰 변환됩니다.
final class GradientTokens {
  const GradientTokens({required this.today});

  /// 데일리 카드·온보딩·공유 이미지에만 씁니다. 단색으로 바뀌어도 깨지지 않게 씁니다
  final LinearGradient today;
}

const lightGradients = GradientTokens(
  today: LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFFEEF4EF), Color(0xFFFBEFEE)],
    stops: [0, 1],
    transform: CssAngleGradientTransform(160),
  ),
);

const darkGradients = GradientTokens(
  today: LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFF162017), Color(0xFF271818)],
    stops: [0, 1],
    transform: CssAngleGradientTransform(160),
  ),
);

/// 간격(logical px).
abstract final class Space {
  static const double s2 = 2;
  static const double s4 = 4;
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;
  static const double s32 = 32;
  static const double s48 = 48;
}

/// 모서리 반경(logical px).
abstract final class Radii {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 20;
  static const double xl = 28;
  static const double full = 9999;
}

/// 움직임 시간과 곡선.
abstract final class Motion {
  static const Duration short = Duration(milliseconds: 200);
  static const Duration fade = Duration(milliseconds: 280);
  static const Duration medium = Duration(milliseconds: 320);
  static const Duration select = Duration(milliseconds: 340);
  static const Duration long = Duration(milliseconds: 420);
  static const Duration stamp = Duration(milliseconds: 520);
  static const Duration breathe = Duration(milliseconds: 1800);
  static const Duration toastHold = Duration(milliseconds: 2500);
  static const Cubic seep = Cubic(0.2, 0.7, 0.2, 1);
  static const Cubic enter = Cubic(0.2, 0.8, 0.2, 1);
  static const Cubic exit = Cubic(0.4, 0, 1, 1);
  static const Cubic stampPress = Cubic(0.5, 0, 0.9, 0.6);
  static const Cubic standard = Cubic(0.4, 0, 0.2, 1);
}

/// 그림자.
abstract final class Shadows {
  static const List<BoxShadow> raised = [
    BoxShadow(
      color: Color.from(
        alpha: 0.14,
        red: 0x2b / 255,
        green: 0x2b / 255,
        blue: 0x2a / 255,
      ),
      offset: Offset(0, 4),
      blurRadius: 16,
      spreadRadius: 0,
    ),
  ];
}
