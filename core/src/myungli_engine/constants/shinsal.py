"""신살 매핑 (spec §5.4). 삼합 그룹의 각 지지 → 신살 지지."""

from __future__ import annotations

from collections.abc import Mapping
from typing import Final

from myungli_engine.domain.enums import Branch as B
from myungli_engine.domain.enums import Stem as S

_FIRE_GROUP: Final = (B.IN, B.O, B.SUL)
_WATER_GROUP: Final = (B.SHIN, B.JA, B.JIN)
_METAL_GROUP: Final = (B.SA, B.YU, B.CHUK)
_WOOD_GROUP: Final = (B.HAE, B.MYO, B.MI)


def _by_group(fire: B, water: B, metal: B, wood: B) -> Mapping[B, B]:
    mapping: dict[B, B] = {}
    for group, target in (
        (_FIRE_GROUP, fire),
        (_WATER_GROUP, water),
        (_METAL_GROUP, metal),
        (_WOOD_GROUP, wood),
    ):
        for branch in group:
            mapping[branch] = target
    return mapping


DOHWA: Final[Mapping[B, B]] = _by_group(fire=B.MYO, water=B.YU, metal=B.O, wood=B.JA)
YEOKMA: Final[Mapping[B, B]] = _by_group(fire=B.SHIN, water=B.IN, metal=B.HAE, wood=B.SA)
HWAGAE: Final[Mapping[B, B]] = _by_group(fire=B.SUL, water=B.JIN, metal=B.CHUK, wood=B.MI)

YANGIN: Final[Mapping[S, B]] = {S.GAP: B.MYO, S.BYEONG: B.O, S.MU: B.O, S.GYEONG: B.YU, S.IM: B.JA}


# --- D124 신살 열셋 (#1028). 원문 대조: core/docs/references/shinsal-sources-survey.md ---


def _branches(table: Mapping[str, str]) -> Mapping[B, frozenset[B]]:
    return {
        B.from_hanja(base): frozenset(B.from_hanja(target) for target in targets)
        for base, targets in table.items()
    }


def _stems_to_branch(table: Mapping[str, str]) -> Mapping[S, B]:
    return {S.from_hanja(stem): B.from_hanja(branch) for stem, branch in table.items()}


def _pillars(members: str) -> frozenset[tuple[S, B]]:
    """ "甲辰 乙巳"처럼 띄어 쓴 일주 목록."""
    return frozenset((S.from_hanja(item[0]), B.from_hanja(item[1])) for item in members.split())


# 천덕귀인: 태어난 달(월지) → 천간 또는 지지. 『三命通會』 「論天月徳」, 坤乾艮巽은 "寅中有艮巳中有巽申中有坤亥中有乾".
CHEONDEOK: Final[Mapping[B, S | B]] = {
    B.from_hanja(month): (S.from_hanja(target) if target in "甲乙丙丁戊己庚辛壬癸" else B.from_hanja(target))
    for month, target in zip("寅卯辰巳午未申酉戌亥子丑", "丁申壬辛亥甲癸寅丙乙巳庚", strict=True)
}
# 월덕귀인: 태어난 달의 삼합 → 양간. 寅午戌 丙, 申子辰 壬, 亥卯未 甲, 巳酉丑 庚.
WOLDEOK: Final[Mapping[B, S]] = {
    branch: stem
    for group, stem in (
        (_FIRE_GROUP, S.BYEONG),
        (_WATER_GROUP, S.IM),
        (_WOOD_GROUP, S.GAP),
        (_METAL_GROUP, S.GYEONG),
    )
    for branch in group
}
# 금여록: 태어난 해 천간의 祿 앞 두 자리(「論金轝」 "金轝常居祿前二辰如甲子人祿在寅辰為金轝").
GEUMYEO: Final[Mapping[S, B]] = _stems_to_branch(
    dict(zip("甲乙丙丁戊己庚辛壬癸", "辰巳未申未申戌亥丑寅", strict=True))
)
# 암록: 태어난 해 천간의 祿과 육합하는 지지(『星學大成』 卷二 「論拱禄交禄暗禄」).
AMROK: Final[Mapping[S, B]] = _stems_to_branch(
    dict(zip("甲乙丙丁戊己庚辛壬癸", "亥戌申未申未巳辰寅丑", strict=True))
)
# 고신, 과숙: 태어난 해 지지의 방합 다음 자리, 앞자리(「論孤辰寡宿」).
GOSIN: Final = _branches(
    {
        base: target
        for bases, target in (("亥子丑", "寅"), ("寅卯辰", "巳"), ("巳午未", "申"), ("申酉戌", "亥"))
        for base in bases
    }
)
GWASUK: Final = _branches(
    {
        base: target
        for bases, target in (("亥子丑", "戌"), ("寅卯辰", "丑"), ("巳午未", "辰"), ("申酉戌", "未"))
        for base in bases
    }
)
# 원진: 한국 통용 쌍, 남녀 구분 없이 띠 기준(D124 ③). 원문 「論元辰」은 남녀를 나누며 남명이 이 쌍과 같다.
WONJIN: Final = _branches(
    {
        base: target
        for first, second in (
            ("子", "未"),
            ("丑", "午"),
            ("寅", "酉"),
            ("卯", "申"),
            ("辰", "亥"),
            ("巳", "戌"),
        )
        for base, target in ((first, second), (second, first))
    }
)
# 구교: 태어난 해 지지의 앞뒤 세 자리(「論勾絞」 "命前三辰…命後三辰"). 두 자리는 성별과 무관하다.
GUGYO_OFFSET: Final = 3
# 천라지망: 戌亥(天羅), 辰巳(地網)가 서로 만남(「論天羅地網」).
CHEONRA_JIMANG: Final = _branches({"戌": "亥", "亥": "戌", "辰": "巳", "巳": "辰"})
# 일주 신살. 괴강은 卷六 魁罡, 십악대패는 「論十惡大敗」(元白經 문단의 己丑), 음착양차는 卷三 陰陽差錯煞 十二日.
GOEGANG: Final = _pillars("庚辰 壬辰 戊戌 庚戌")
SIPAK_DAEPAE: Final = _pillars("甲辰 乙巳 丙申 丁亥 戊戌 己丑 庚辰 辛巳 壬申 癸亥")
EUMCHAK_YANGCHA: Final = _pillars("丙子 丁丑 戊寅 辛卯 壬辰 癸巳 丙午 丁未 戊申 辛酉 壬戌 癸亥")
# 삼기: 천간이 이 순서로 연월일 또는 월일시에 놓임(順布). 辛壬癸는 원문이 "其說無據"라 하여 넣지 않는다.
SAMGI: Final[tuple[tuple[S, S, S], ...]] = ((S.EUL, S.BYEONG, S.JEONG), (S.GAP, S.MU, S.GYEONG))
