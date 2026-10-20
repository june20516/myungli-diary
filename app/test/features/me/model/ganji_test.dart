import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/gen/model/branch.dart';
import 'package:myungli_diary/core/api/gen/model/five_element.dart';
import 'package:myungli_diary/core/api/gen/model/stem.dart';
import 'package:myungli_diary/features/me/model/ganji.dart';

void main() {
  test('천간 열의 한자는 甲乙丙丁戊己庚辛壬癸, 오행은 둘씩 목·화·토·금·수', () {
    expect(Stem.values.map(stemHanja).join(), '甲乙丙丁戊己庚辛壬癸');
    expect(Stem.values.map(stemElement).toList(), [
      for (final element in FiveElement.values) ...[element, element],
    ]);
  });

  test('지지 열둘의 한자와 본기 오행', () {
    expect(Branch.values.map(branchHanja).join(), '子丑寅卯辰巳午未申酉戌亥');
    expect(branchElement(Branch.ja), FiveElement.water);
    expect(branchElement(Branch.in_), FiveElement.wood);
    expect(branchElement(Branch.o), FiveElement.fire);
    expect(branchElement(Branch.sul), FiveElement.earth);
    expect(branchElement(Branch.yu), FiveElement.metal);
  });
}
