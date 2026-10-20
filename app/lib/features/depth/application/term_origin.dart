import 'package:flutter/foundation.dart' show immutable;
import 'package:myungli_diary/features/depth/application/evidence_unlock_controller.dart';
import 'package:myungli_diary/features/depth/application/personal_reading_key.dart';

/// 풀이 시트를 연 용어의 출처: 용어가 눌린 writing 슬롯과 그 슬롯을 담은 응답.
///
/// 풀이 시트는 오늘 그런 이유를 [subject]에서만 읽고, "근거 보기"는 [slotId]의 근거 시트를
/// 엽니다. 여는 화면이 자기 응답을 넣습니다(오늘 화면은 [DailyEvidenceSubject], 계획 6의 사주
/// 표 계열은 그 응답의 subject). 출처가 없으면(그날 시트처럼 근거로 이어지지 않는 곳) 풀이 시트는
/// 응답을 보지 않습니다.
///
/// 사주 표·만세력·대운 표의 칸 용어는 writing 슬롯이 아니라 표 칸이므로 [personal]에 누른 칸의
/// 자리를 담고, "근거 보기"가 연 근거 시트는 그 자리의 원국 개인 해석을 보입니다(A58).
@immutable
final class TermOrigin {
  /// [slotId] 슬롯과 그 슬롯을 담은 [subject]입니다. [personal]은 누른 표 칸의 자리입니다.
  const new({required this.slotId, required this.subject, this.personal});

  /// 용어가 눌린 writing 슬롯 id.
  final String slotId;

  /// 그 슬롯을 담은 응답.
  final EvidenceSubject subject;

  /// 표 칸 용어의 자리. 문장 안 용어는 null입니다.
  final PersonalReadingKey? personal;

  @override
  bool operator ==(Object other) =>
      other is TermOrigin &&
      other.slotId == slotId &&
      other.subject == subject &&
      other.personal == personal;

  @override
  int get hashCode => Object.hash(slotId, subject, personal);
}
