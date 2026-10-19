import 'package:flutter/foundation.dart' show immutable;
import 'package:myungli_diary/features/depth/application/evidence_unlock_controller.dart';

/// 풀이 시트를 연 용어의 출처: 용어가 눌린 writing 슬롯과 그 슬롯을 담은 응답.
///
/// 풀이 시트는 오늘 그런 이유를 [subject]에서만 읽고, "근거 보기"는 [slotId]의 근거 시트를
/// 엽니다. 여는 화면이 자기 응답을 넣습니다(오늘 화면은 [DailyEvidenceSubject], 계획 6의 사주
/// 표 계열은 그 응답의 subject). 출처가 없으면(그날 시트처럼 근거로 이어지지 않는 곳) 풀이 시트는
/// 응답을 보지 않습니다.
@immutable
final class TermOrigin {
  /// [slotId] 슬롯과 그 슬롯을 담은 [subject]입니다.
  const new({required this.slotId, required this.subject});

  /// 용어가 눌린 writing 슬롯 id.
  final String slotId;

  /// 그 슬롯을 담은 응답.
  final EvidenceSubject subject;

  @override
  bool operator ==(Object other) =>
      other is TermOrigin && other.slotId == slotId && other.subject == subject;

  @override
  int get hashCode => Object.hash(slotId, subject);
}
