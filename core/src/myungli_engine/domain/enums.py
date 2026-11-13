"""명리 엔진의 기본 enum. 문자열 표기는 비교 키로 쓰지 않고 enum 멤버로 비교한다."""

from __future__ import annotations

from enum import Enum, auto


class Element(Enum):
    WOOD = auto()
    FIRE = auto()
    EARTH = auto()
    METAL = auto()
    WATER = auto()


_ELEMENT_ORDER: tuple[Element, ...] = tuple(Element)


class Stem(Enum):
    """천간. 정의 순서가 곧 갑(0)~계(9) 순서다."""

    GAP = "甲"
    EUL = "乙"
    BYEONG = "丙"
    JEONG = "丁"
    MU = "戊"
    GI = "己"
    GYEONG = "庚"
    SIN = "辛"
    IM = "壬"
    GYE = "癸"

    @property
    def hanja(self) -> str:
        return str(self.value)

    @property
    def index(self) -> int:
        return list(Stem).index(self)

    @property
    def element(self) -> Element:
        return _ELEMENT_ORDER[self.index // 2]

    @property
    def is_yang(self) -> bool:
        return self.index % 2 == 0

    @classmethod
    def from_hanja(cls, hanja: str) -> Stem:
        for stem in cls:
            if stem.value == hanja:
                return stem
        raise ValueError(f"알 수 없는 천간: {hanja!r}")


_BRANCH_ELEMENTS: dict[str, Element] = {
    "子": Element.WATER,
    "丑": Element.EARTH,
    "寅": Element.WOOD,
    "卯": Element.WOOD,
    "辰": Element.EARTH,
    "巳": Element.FIRE,
    "午": Element.FIRE,
    "未": Element.EARTH,
    "申": Element.METAL,
    "酉": Element.METAL,
    "戌": Element.EARTH,
    "亥": Element.WATER,
}


class Branch(Enum):
    """지지. 정의 순서가 곧 자(0)~해(11) 순서다."""

    JA = "子"
    CHUK = "丑"
    IN = "寅"
    MYO = "卯"
    JIN = "辰"
    SA = "巳"
    O = "午"
    MI = "未"
    SHIN = "申"
    YU = "酉"
    SUL = "戌"
    HAE = "亥"

    @property
    def hanja(self) -> str:
        return str(self.value)

    @property
    def index(self) -> int:
        return list(Branch).index(self)

    @property
    def element(self) -> Element:
        """정기(正氣) 오행."""
        return _BRANCH_ELEMENTS[self.hanja]

    @property
    def is_yang(self) -> bool:
        return self.index % 2 == 0

    @classmethod
    def from_hanja(cls, hanja: str) -> Branch:
        for branch in cls:
            if branch.value == hanja:
                return branch
        raise ValueError(f"알 수 없는 지지: {hanja!r}")


class TenGodGroup(Enum):
    BIGYEOP = auto()
    SIKSANG = auto()
    JAESEONG = auto()
    GWANSEONG = auto()
    INSEONG = auto()


class TenGod(Enum):
    BIGYEON = auto()
    GEOPJAE = auto()
    SIKSIN = auto()
    SANGGWAN = auto()
    PYEONJAE = auto()
    JEONGJAE = auto()
    PYEONGWAN = auto()
    JEONGGWAN = auto()
    PYEONIN = auto()
    JEONGIN = auto()

    @property
    def group(self) -> TenGodGroup:
        groups = tuple(TenGodGroup)
        return groups[list(TenGod).index(self) // 2]


class Gender(Enum):
    MALE = auto()
    FEMALE = auto()


class CalendarType(Enum):
    SOLAR = auto()
    LUNAR = auto()


class Direction8(Enum):
    N = auto()
    NE = auto()
    E = auto()
    SE = auto()
    S = auto()
    SW = auto()
    W = auto()
    NW = auto()


class DayKind(Enum):
    GWIIN_DAY = auto()
    YONGSIN_DAY = auto()
    GISIN_DAY = auto()
    ORDINARY_DAY = auto()


class StrengthLevel(Enum):
    VERY_WEAK = auto()
    WEAK = auto()
    NEUTRAL = auto()
    STRONG = auto()
    VERY_STRONG = auto()


class YongsinMethod(Enum):
    JOHU = auto()
    JOHU_NEUTRAL = auto()
    EOKBU = auto()


class LuckLevel(Enum):
    """순서는 proto 번호 순서다(VERY_GOOD은 #804에서 더함). 수준의 높낮이 순서가 아니다."""

    GOOD = auto()
    NEUTRAL = auto()
    CAUTION = auto()
    VERY_GOOD = auto()


class NoticeCode(Enum):
    AMBIGUOUS_LOCAL_TIME = auto()
    NONEXISTENT_LOCAL_TIME = auto()
    ZI_HOUR_NEXT_DAY = auto()
    TIME_UNKNOWN = auto()
    NEAR_SOLAR_TERM = auto()
    DAYUN_START_APPROXIMATE = auto()
    FOCUS_TIME_FALLBACK = auto()


class Shinsal(Enum):
    CHEONEUL_GWIIN = auto()
    DOHWA = auto()
    YEOKMA = auto()
    HWAGAE = auto()
    YANGIN = auto()
    GONGMANG = auto()
    # D124 (#1028). 원국 표 열셋. 이 가운데 고신, 과숙, 원진만 오늘 태그로도 발동한다.
    CHEONDEOK = auto()
    WOLDEOK = auto()
    GEUMYEO = auto()
    GOSIN = auto()
    GWASUK = auto()
    WONJIN = auto()
    GUGYO = auto()
    CHEONRA_JIMANG = auto()
    GOEGANG = auto()
    SIPAK_DAEPAE = auto()
    EUMCHAK_YANGCHA = auto()
    SAMGI = auto()
    AMROK = auto()


class DayVirtue(Enum):
    """택일 덕일(D124 ⑤). 그날이 속한 달 기준이라 모두에게 같다(D13의 예외)."""

    CHEONDEOK_DAY = auto()
    WOLDEOK_DAY = auto()


class PersonalTermKind(Enum):
    """개인 해석이 풀어 주는 용어의 종류."""

    DAY_MASTER = auto()
    TEN_GOD = auto()
    HIDDEN_TEN_GOD = auto()
    TWELVE_STAGE = auto()
    SHINSAL = auto()
    DAEUN_STEM_TEN_GOD = auto()
    DAEUN_BRANCH_TEN_GOD = auto()
    DAEUN_TWELVE_STAGE = auto()
    SEUN_TEN_GOD = auto()


class TwelveStage(Enum):
    JANGSAENG = auto()
    MOKYOK = auto()
    GWANDAE = auto()
    GEONROK = auto()
    JEWANG = auto()
    SOE = auto()
    BYEONG = auto()
    SA = auto()
    MYO = auto()
    JEOL = auto()
    TAE = auto()
    YANG = auto()


class ElementRelation(Enum):
    """바탕 오행에서 본 결과 오행의 관계(D130). 이름은 변역 원문의 母, 子, 妻, 鬼를 따른다."""

    SAME = auto()  # 같은 오행
    MO = auto()  # 바탕을 생해 주는 오행
    JA = auto()  # 바탕이 생해 주는 오행
    CHEO = auto()  # 바탕이 극하는 오행
    GWI = auto()  # 바탕을 극하는 오행


class ColorShift(Enum):
    """행운 색 변역(變易): 오행이 12운성 자리에 따라 따르는 색 (#937, C33). 정의 순서는 원문 순서."""

    JEONG = auto()  # 正色: 제 색
    MO = auto()  # 母色: 나를 생하는 오행의 색
    CHEO = auto()  # 妻色: 내가 극하는 오행의 색
    GWI = auto()  # 鬼色: 나를 극하는 오행의 색
    JA = auto()  # 子色: 내가 생하는 오행의 색


class ColorBasis(Enum):
    """행운 색 카드의 계산 기준 (D119, C34). 변역 색이 기신이 아닌 날은 SOURCE 카드 하나다."""

    SOURCE = auto()  # 원전 기준: 변역 뒤 색
    BALANCE = auto()  # 내 균형 기준: 바탕 오행의 제 색(변역 없음)


class SolarTermKind(Enum):
    """24절기. 양력 1월의 소한부터 12월의 동지까지 한 해 순서다. 이름은 한국어 로마자 표기."""

    SOHAN = auto()  # 소한 小寒
    DAEHAN = auto()  # 대한 大寒
    IPCHUN = auto()  # 입춘 立春
    USU = auto()  # 우수 雨水
    GYEONGCHIP = auto()  # 경칩 驚蟄
    CHUNBUN = auto()  # 춘분 春分
    CHEONGMYEONG = auto()  # 청명 淸明
    GOGU = auto()  # 곡우 穀雨
    IPHA = auto()  # 입하 立夏
    SOMAN = auto()  # 소만 小滿
    MANGJONG = auto()  # 망종 芒種
    HAJI = auto()  # 하지 夏至
    SOSEO = auto()  # 소서 小暑
    DAESEO = auto()  # 대서 大暑
    IPCHU = auto()  # 입추 立秋
    CHEOSEO = auto()  # 처서 處暑
    BAENGNO = auto()  # 백로 白露
    CHUBUN = auto()  # 추분 秋分
    HALLO = auto()  # 한로 寒露
    SANGGANG = auto()  # 상강 霜降
    IPDONG = auto()  # 입동 立冬
    SOSEOL = auto()  # 소설 小雪
    DAESEOL = auto()  # 대설 大雪
    DONGJI = auto()  # 동지 冬至
