import 'package:myungli_diary/core/api/gen/model/branch.dart';
import 'package:myungli_diary/core/api/gen/model/five_element.dart';
import 'package:myungli_diary/core/api/gen/model/stem.dart';

/// 천간·지지의 한자와 오행(결정 A65).
///
/// 언어와 상관없는 고정 값이라 app 표로 둡니다. 칸의 독음·이름은 용어 사전에서 읽습니다.

/// [stem]의 한자.
String stemHanja(Stem stem) => switch (stem) {
  Stem.gap => '甲',
  Stem.eul => '乙',
  Stem.byeong => '丙',
  Stem.jeong => '丁',
  Stem.mu => '戊',
  Stem.gi => '己',
  Stem.gyeong => '庚',
  Stem.sin => '辛',
  Stem.im => '壬',
  Stem.gye => '癸',
};

/// [stem]의 오행.
FiveElement stemElement(Stem stem) => switch (stem) {
  Stem.gap || Stem.eul => FiveElement.wood,
  Stem.byeong || Stem.jeong => FiveElement.fire,
  Stem.mu || Stem.gi => FiveElement.earth,
  Stem.gyeong || Stem.sin => FiveElement.metal,
  Stem.im || Stem.gye => FiveElement.water,
};

/// [branch]의 한자.
String branchHanja(Branch branch) => switch (branch) {
  Branch.ja => '子',
  Branch.chuk => '丑',
  Branch.in_ => '寅',
  Branch.myo => '卯',
  Branch.jin => '辰',
  Branch.sa => '巳',
  Branch.o => '午',
  Branch.mi => '未',
  Branch.shin => '申',
  Branch.yu => '酉',
  Branch.sul => '戌',
  Branch.hae => '亥',
};

/// [branch]의 오행(본기).
FiveElement branchElement(Branch branch) => switch (branch) {
  Branch.in_ || Branch.myo => FiveElement.wood,
  Branch.sa || Branch.o => FiveElement.fire,
  Branch.chuk || Branch.jin || Branch.mi || Branch.sul => FiveElement.earth,
  Branch.shin || Branch.yu => FiveElement.metal,
  Branch.hae || Branch.ja => FiveElement.water,
};
