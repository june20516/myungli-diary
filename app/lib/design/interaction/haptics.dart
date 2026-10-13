import 'package:flutter/services.dart';

/// 햅틱 세기 3가지(`interaction.json` `haptics`). 의미 있는 순간에만 부릅니다.
///
/// 기기의 시스템 햅틱 설정은 플랫폼이 따릅니다.
abstract final class Haptics {
  /// 선택이 바뀜: segmented, 탭, 체크, 날짜·시간 휠 눈금.
  static Future<void> selection() => HapticFeedback.selectionClick();

  /// 저장·완료, 반응(좋아요), 보상형 광고 뒤 근거 열림.
  static Future<void> light() => HapticFeedback.lightImpact();

  /// 되돌릴 수 없는 동작 확인: 일기 삭제, 계정 삭제.
  static Future<void> medium() => HapticFeedback.mediumImpact();
}
