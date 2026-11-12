import 'package:myungli_diary/core/api/gen/model/branch.dart';
import 'package:myungli_diary/core/api/gen/model/stem.dart';
import 'package:myungli_diary/features/glossary/model/glossary_names.dart';

/// 간지 독음의 원천을 한곳에 모읍니다(결정 A133).
///
/// 사전 값 이름(`Glossary.values`의 `stem`, `branch`)은 "이름"이지 독음이 아닙니다(ko 경금,
/// ja 庚, en Gyeonggeum, 지지는 en Monkey). 그래서 독음으로 쓰지 않습니다. writing에 간지 독음
/// 값을 요청했고(#1069), 그 값이 올 때까지 독음은 없습니다(null). 독음이 없으면 부르는 화면이
/// 한자만 보입니다. #1069 값이 오면 이 두 함수만 그 원천으로 바꿉니다.
abstract final class GanjiReading {
  /// [stem]의 독음. 원천이 없어 늘 null입니다([names]는 #1069 뒤 원천 자리).
  static String? stem(Stem stem, GlossaryNames? names) => null;

  /// [branch]의 독음. 원천이 없어 늘 null입니다([names]는 #1069 뒤 원천 자리).
  static String? branch(Branch branch, GlossaryNames? names) => null;
}
