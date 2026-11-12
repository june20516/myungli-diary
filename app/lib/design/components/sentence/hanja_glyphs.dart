import 'package:myungli_diary/core/api/gen/model/day_kind.dart';
import 'package:myungli_diary/core/api/gen/model/day_virtue_kind.dart';
import 'package:myungli_diary/core/api/gen/model/ten_god_group.dart';
import 'package:myungli_diary/design/components/sentence/hanja_tag.dart';

/// 사주 용어 한자 글자표(`hanja-tag` `parts.glyphs` 21자, A112, V70 개정).
///
/// 계약은 한자를 이름 기준으로 주고, app이 키 기준 상수 표로 옮깁니다. 표에 없는 키는
/// null이며, 그리지 않고 비치명 오류로 남기는 일은 부르는 쪽 몫입니다. 표의 값 집합은
/// 계약 테스트가 `sentence.json`의 21자와 대조합니다.
abstract final class HanjaGlyphs {
  /// 날의 성격(`glyphs.dayKind`). 모든 enum 값에 글자가 있어 null이 없습니다.
  static const Map<DayKind, String> _dayKind = {
    DayKind.gwiinDay: '貴',
    DayKind.yongsinDay: '用',
    DayKind.gisinDay: '忌',
    DayKind.ordinaryDay: '平',
  };

  /// 십성 묶음(`glyphs.tenGodGroup`).
  static const Map<TenGodGroup, String> _tenGodGroup = {
    TenGodGroup.bigyeop: '比',
    TenGodGroup.siksang: '食',
    TenGodGroup.jaeseong: '財',
    TenGodGroup.gwanseong: '官',
    TenGodGroup.inseong: '印',
  };

  /// 택일 덕일(`glyphs.virtueDay`, V119). 두 덕 모두 德이고 이름으로 구분합니다.
  /// 열린 enum의 모르는 값은 표에 없어 null입니다.
  static const Map<DayVirtueKind, String> _dayVirtue = {
    DayVirtueKind.cheondeokDay: '德',
    DayVirtueKind.woldeokDay: '德',
  };

  /// 십성 몰림 태그 키의 접두어(`ten_god_rush.<묶음>`).
  static const String _tenGodRushPrefix = 'ten_god_rush.';

  /// 태그 키(접두어 `tag.`를 뗀 glossary `tag` 범주 키) → 글자.
  ///
  /// 길흉 표(server `polarity.go`)의 키와 같습니다. `big_change`는 일지 충과 월지 충으로
  /// 나뉘기 전 규칙 버전으로 저장한 일기에 남은 옛 키라 충(沖)으로 둡니다.
  /// `yongsin_day`, `gwiin_day`는 날의 성격과 같은 글자입니다.
  static const Map<String, String> _tagKey = {
    'harmony': '合',
    'clash': '沖',
    'clash_day_branch': '沖',
    'clash_month_branch': '沖',
    'big_change': '沖',
    'hyeong': '刑',
    'cheoneul_gwiin': '天',
    'dohwa': '桃',
    'yeokma': '驛',
    'hwagae': '華',
    'gongmang': '空',
    'gosin': '孤',
    'gwasuk': '寡',
    'wonjin': '元',
    'yongsin_day': '用',
    'gwiin_day': '貴',
  };

  /// 색 규칙 시트 점수 항목 id(server `scoreItems`, A116) → 글자.
  static const Map<String, String> _scoreItem = {
    'yongsin_day': '用',
    'gwiin_day': '貴',
    'hap': '合',
    'gisin_day': '忌',
    'chung_day_or_month': '沖',
    'chung_other': '沖',
    'hyeong': '刑',
  };

  /// 표에 든 글자 전체. 계약 21자와 같아야 합니다(계약 테스트).
  static Set<String> get allGlyphs => {
    ..._dayKind.values,
    ..._dayVirtue.values,
    ..._tenGodGroup.values,
    ..._tagKey.values,
    ..._scoreItem.values,
  };

  /// 날의 성격의 글자.
  static String forDayKind(DayKind kind) => _dayKind[kind]!;

  /// 택일 덕일의 글자. 모르는 값([DayVirtueKind.unknownDefaultOpenApi])은 null입니다.
  static String? forDayVirtue(DayVirtueKind kind) => _dayVirtue[kind];

  /// 십성 묶음의 글자.
  static String forTenGodGroup(TenGodGroup group) => _tenGodGroup[group]!;

  /// 태그 키의 글자. 십성 몰림(`ten_god_rush.<묶음>`)은 그 묶음 글자입니다.
  /// 표에 없는 키는 null입니다.
  static String? forTagKey(String key) {
    if (key.startsWith(_tenGodRushPrefix)) {
      final group = key.substring(_tenGodRushPrefix.length);
      for (final entry in _tenGodGroup.entries) {
        if (entry.key.value == group) return entry.value;
      }
      return null;
    }
    return _tagKey[key];
  }

  /// 점수 항목 id의 글자. 표에 없는 id는 null입니다.
  static String? forScoreItem(String id) => _scoreItem[id];

  /// 날의 성격의 톤(귀인 `gwiin`, 용신 `yongsin`, 기신 `gisin`, 평범 `ordinary`).
  static HanjaTagTone toneOfDayKind(DayKind kind) => switch (kind) {
    DayKind.gwiinDay => HanjaTagTone.gwiin,
    DayKind.yongsinDay => HanjaTagTone.yongsin,
    DayKind.gisinDay => HanjaTagTone.gisin,
    DayKind.ordinaryDay => HanjaTagTone.ordinary,
  };
}
