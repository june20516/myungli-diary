import 'package:myungli_diary/core/api/gen/model/branch.dart';
import 'package:myungli_diary/core/api/gen/model/stem.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';

/// 간지 독음의 원천을 한곳에 모읍니다(결정 A133, W72, #1069).
///
/// 독음은 writing 원고 glossary `stem_reading`, `branch_reading`(ARB `stemReading*`,
/// `branchReading*`)입니다. ko 한글 독음(갑, 자), ja 四柱推命 훈독(きのえ, ね), en 한국어
/// 로마자(Gap, Ja)이고, 사전 값 이름(`Glossary.values`의 `stem`, `branch`, 예 경금, Monkey)과
/// 다릅니다.
/// 두 글자 잇기는 [pillar](틀 `ganjiReading`)이고, 한자 뒤 괄호는 부르는 쪽이 틀
/// `ganjiReadingSuffix`로 붙입니다(한자는 틀에 넣지 않고 한자 글꼴로 따로 그림).
abstract final class GanjiReading {
  /// [stem]의 독음.
  static String stem(Stem stem, AppLocalizations l10n) => switch (stem) {
    Stem.gap => l10n.stemReadingGap,
    Stem.eul => l10n.stemReadingEul,
    Stem.byeong => l10n.stemReadingByeong,
    Stem.jeong => l10n.stemReadingJeong,
    Stem.mu => l10n.stemReadingMu,
    Stem.gi => l10n.stemReadingGi,
    Stem.gyeong => l10n.stemReadingGyeong,
    Stem.sin => l10n.stemReadingSin,
    Stem.im => l10n.stemReadingIm,
    Stem.gye => l10n.stemReadingGye,
  };

  /// [branch]의 독음.
  static String branch(Branch branch, AppLocalizations l10n) =>
      switch (branch) {
        Branch.ja => l10n.branchReadingJa,
        Branch.chuk => l10n.branchReadingChuk,
        Branch.in_ => l10n.branchReadingIn,
        Branch.myo => l10n.branchReadingMyo,
        Branch.jin => l10n.branchReadingJin,
        Branch.sa => l10n.branchReadingSa,
        Branch.o => l10n.branchReadingO,
        Branch.mi => l10n.branchReadingMi,
        Branch.shin => l10n.branchReadingShin,
        Branch.yu => l10n.branchReadingYu,
        Branch.sul => l10n.branchReadingSul,
        Branch.hae => l10n.branchReadingHae,
      };

  /// 천간과 지지 독음을 이은 간지 독음(틀 `ganjiReading`, ko 경신, en Gyeong Sin, ja かのえさる).
  /// 스크린리더가 간지를 읽는 글자입니다.
  static String pillar(Stem stem, Branch branch, AppLocalizations l10n) =>
      l10n.ganjiReading(
        GanjiReading.stem(stem, l10n),
        GanjiReading.branch(branch, l10n),
      );
}
