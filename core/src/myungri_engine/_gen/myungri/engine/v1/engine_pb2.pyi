import datetime

from google.protobuf import timestamp_pb2 as _timestamp_pb2
from google.protobuf.internal import containers as _containers
from google.protobuf.internal import enum_type_wrapper as _enum_type_wrapper
from google.protobuf import descriptor as _descriptor
from google.protobuf import message as _message
from collections.abc import Iterable as _Iterable, Mapping as _Mapping
from typing import ClassVar as _ClassVar, Optional as _Optional, Union as _Union

DESCRIPTOR: _descriptor.FileDescriptor

class CalendarType(int, metaclass=_enum_type_wrapper.EnumTypeWrapper):
    __slots__ = ()
    CALENDAR_TYPE_UNSPECIFIED: _ClassVar[CalendarType]
    CALENDAR_TYPE_SOLAR: _ClassVar[CalendarType]
    CALENDAR_TYPE_LUNAR: _ClassVar[CalendarType]

class Gender(int, metaclass=_enum_type_wrapper.EnumTypeWrapper):
    __slots__ = ()
    GENDER_UNSPECIFIED: _ClassVar[Gender]
    GENDER_MALE: _ClassVar[Gender]
    GENDER_FEMALE: _ClassVar[Gender]

class Element(int, metaclass=_enum_type_wrapper.EnumTypeWrapper):
    __slots__ = ()
    ELEMENT_UNSPECIFIED: _ClassVar[Element]
    ELEMENT_WOOD: _ClassVar[Element]
    ELEMENT_FIRE: _ClassVar[Element]
    ELEMENT_EARTH: _ClassVar[Element]
    ELEMENT_METAL: _ClassVar[Element]
    ELEMENT_WATER: _ClassVar[Element]

class Stem(int, metaclass=_enum_type_wrapper.EnumTypeWrapper):
    __slots__ = ()
    STEM_UNSPECIFIED: _ClassVar[Stem]
    STEM_GAP: _ClassVar[Stem]
    STEM_EUL: _ClassVar[Stem]
    STEM_BYEONG: _ClassVar[Stem]
    STEM_JEONG: _ClassVar[Stem]
    STEM_MU: _ClassVar[Stem]
    STEM_GI: _ClassVar[Stem]
    STEM_GYEONG: _ClassVar[Stem]
    STEM_SIN: _ClassVar[Stem]
    STEM_IM: _ClassVar[Stem]
    STEM_GYE: _ClassVar[Stem]

class Branch(int, metaclass=_enum_type_wrapper.EnumTypeWrapper):
    __slots__ = ()
    BRANCH_UNSPECIFIED: _ClassVar[Branch]
    BRANCH_JA: _ClassVar[Branch]
    BRANCH_CHUK: _ClassVar[Branch]
    BRANCH_IN: _ClassVar[Branch]
    BRANCH_MYO: _ClassVar[Branch]
    BRANCH_JIN: _ClassVar[Branch]
    BRANCH_SA: _ClassVar[Branch]
    BRANCH_O: _ClassVar[Branch]
    BRANCH_MI: _ClassVar[Branch]
    BRANCH_SHIN: _ClassVar[Branch]
    BRANCH_YU: _ClassVar[Branch]
    BRANCH_SUL: _ClassVar[Branch]
    BRANCH_HAE: _ClassVar[Branch]

class TenGod(int, metaclass=_enum_type_wrapper.EnumTypeWrapper):
    __slots__ = ()
    TEN_GOD_UNSPECIFIED: _ClassVar[TenGod]
    TEN_GOD_BIGYEON: _ClassVar[TenGod]
    TEN_GOD_GEOPJAE: _ClassVar[TenGod]
    TEN_GOD_SIKSIN: _ClassVar[TenGod]
    TEN_GOD_SANGGWAN: _ClassVar[TenGod]
    TEN_GOD_PYEONJAE: _ClassVar[TenGod]
    TEN_GOD_JEONGJAE: _ClassVar[TenGod]
    TEN_GOD_PYEONGWAN: _ClassVar[TenGod]
    TEN_GOD_JEONGGWAN: _ClassVar[TenGod]
    TEN_GOD_PYEONIN: _ClassVar[TenGod]
    TEN_GOD_JEONGIN: _ClassVar[TenGod]

class TwelveStage(int, metaclass=_enum_type_wrapper.EnumTypeWrapper):
    __slots__ = ()
    TWELVE_STAGE_UNSPECIFIED: _ClassVar[TwelveStage]
    TWELVE_STAGE_JANGSAENG: _ClassVar[TwelveStage]
    TWELVE_STAGE_MOKYOK: _ClassVar[TwelveStage]
    TWELVE_STAGE_GWANDAE: _ClassVar[TwelveStage]
    TWELVE_STAGE_GEONROK: _ClassVar[TwelveStage]
    TWELVE_STAGE_JEWANG: _ClassVar[TwelveStage]
    TWELVE_STAGE_SOE: _ClassVar[TwelveStage]
    TWELVE_STAGE_BYEONG: _ClassVar[TwelveStage]
    TWELVE_STAGE_SA: _ClassVar[TwelveStage]
    TWELVE_STAGE_MYO: _ClassVar[TwelveStage]
    TWELVE_STAGE_JEOL: _ClassVar[TwelveStage]
    TWELVE_STAGE_TAE: _ClassVar[TwelveStage]
    TWELVE_STAGE_YANG: _ClassVar[TwelveStage]

class Shinsal(int, metaclass=_enum_type_wrapper.EnumTypeWrapper):
    __slots__ = ()
    SHINSAL_UNSPECIFIED: _ClassVar[Shinsal]
    SHINSAL_CHEONEUL_GWIIN: _ClassVar[Shinsal]
    SHINSAL_DOHWA: _ClassVar[Shinsal]
    SHINSAL_YEOKMA: _ClassVar[Shinsal]
    SHINSAL_HWAGAE: _ClassVar[Shinsal]
    SHINSAL_YANGIN: _ClassVar[Shinsal]
    SHINSAL_GONGMANG: _ClassVar[Shinsal]

class Position(int, metaclass=_enum_type_wrapper.EnumTypeWrapper):
    __slots__ = ()
    POSITION_UNSPECIFIED: _ClassVar[Position]
    POSITION_YEAR_STEM: _ClassVar[Position]
    POSITION_YEAR_BRANCH: _ClassVar[Position]
    POSITION_MONTH_STEM: _ClassVar[Position]
    POSITION_MONTH_BRANCH: _ClassVar[Position]
    POSITION_DAY_STEM: _ClassVar[Position]
    POSITION_DAY_BRANCH: _ClassVar[Position]
    POSITION_HOUR_STEM: _ClassVar[Position]
    POSITION_HOUR_BRANCH: _ClassVar[Position]

class Direction8(int, metaclass=_enum_type_wrapper.EnumTypeWrapper):
    __slots__ = ()
    DIRECTION8_UNSPECIFIED: _ClassVar[Direction8]
    DIRECTION8_N: _ClassVar[Direction8]
    DIRECTION8_NE: _ClassVar[Direction8]
    DIRECTION8_E: _ClassVar[Direction8]
    DIRECTION8_SE: _ClassVar[Direction8]
    DIRECTION8_S: _ClassVar[Direction8]
    DIRECTION8_SW: _ClassVar[Direction8]
    DIRECTION8_W: _ClassVar[Direction8]
    DIRECTION8_NW: _ClassVar[Direction8]

class DayKind(int, metaclass=_enum_type_wrapper.EnumTypeWrapper):
    __slots__ = ()
    DAY_KIND_UNSPECIFIED: _ClassVar[DayKind]
    DAY_KIND_GWIIN_DAY: _ClassVar[DayKind]
    DAY_KIND_YONGSIN_DAY: _ClassVar[DayKind]
    DAY_KIND_GISIN_DAY: _ClassVar[DayKind]
    DAY_KIND_ORDINARY_DAY: _ClassVar[DayKind]

class StrengthLevel(int, metaclass=_enum_type_wrapper.EnumTypeWrapper):
    __slots__ = ()
    STRENGTH_LEVEL_UNSPECIFIED: _ClassVar[StrengthLevel]
    STRENGTH_LEVEL_VERY_WEAK: _ClassVar[StrengthLevel]
    STRENGTH_LEVEL_WEAK: _ClassVar[StrengthLevel]
    STRENGTH_LEVEL_NEUTRAL: _ClassVar[StrengthLevel]
    STRENGTH_LEVEL_STRONG: _ClassVar[StrengthLevel]
    STRENGTH_LEVEL_VERY_STRONG: _ClassVar[StrengthLevel]

class YongsinMethod(int, metaclass=_enum_type_wrapper.EnumTypeWrapper):
    __slots__ = ()
    YONGSIN_METHOD_UNSPECIFIED: _ClassVar[YongsinMethod]
    YONGSIN_METHOD_JOHU: _ClassVar[YongsinMethod]
    YONGSIN_METHOD_JOHU_NEUTRAL: _ClassVar[YongsinMethod]
    YONGSIN_METHOD_EOKBU: _ClassVar[YongsinMethod]

class LuckLevel(int, metaclass=_enum_type_wrapper.EnumTypeWrapper):
    __slots__ = ()
    LUCK_LEVEL_UNSPECIFIED: _ClassVar[LuckLevel]
    LUCK_LEVEL_GOOD: _ClassVar[LuckLevel]
    LUCK_LEVEL_NEUTRAL: _ClassVar[LuckLevel]
    LUCK_LEVEL_CAUTION: _ClassVar[LuckLevel]

class NoticeCode(int, metaclass=_enum_type_wrapper.EnumTypeWrapper):
    __slots__ = ()
    NOTICE_CODE_UNSPECIFIED: _ClassVar[NoticeCode]
    NOTICE_CODE_AMBIGUOUS_LOCAL_TIME: _ClassVar[NoticeCode]
    NOTICE_CODE_NONEXISTENT_LOCAL_TIME: _ClassVar[NoticeCode]
    NOTICE_CODE_ZI_HOUR_NEXT_DAY: _ClassVar[NoticeCode]
    NOTICE_CODE_TIME_UNKNOWN: _ClassVar[NoticeCode]
    NOTICE_CODE_NEAR_SOLAR_TERM: _ClassVar[NoticeCode]
    NOTICE_CODE_DAYUN_START_APPROXIMATE: _ClassVar[NoticeCode]
    NOTICE_CODE_FOCUS_TIME_FALLBACK: _ClassVar[NoticeCode]

class RelationKind(int, metaclass=_enum_type_wrapper.EnumTypeWrapper):
    __slots__ = ()
    RELATION_KIND_UNSPECIFIED: _ClassVar[RelationKind]
    RELATION_KIND_STEM_HAP: _ClassVar[RelationKind]
    RELATION_KIND_BRANCH_HAP: _ClassVar[RelationKind]
    RELATION_KIND_CHUNG: _ClassVar[RelationKind]
    RELATION_KIND_HYEONG: _ClassVar[RelationKind]

class ElementRole(int, metaclass=_enum_type_wrapper.EnumTypeWrapper):
    __slots__ = ()
    ELEMENT_ROLE_UNSPECIFIED: _ClassVar[ElementRole]
    ELEMENT_ROLE_YONGSIN: _ClassVar[ElementRole]
    ELEMENT_ROLE_TONGGWAN: _ClassVar[ElementRole]

class SolarTermKind(int, metaclass=_enum_type_wrapper.EnumTypeWrapper):
    __slots__ = ()
    SOLAR_TERM_KIND_UNSPECIFIED: _ClassVar[SolarTermKind]
    SOLAR_TERM_KIND_SOHAN: _ClassVar[SolarTermKind]
    SOLAR_TERM_KIND_DAEHAN: _ClassVar[SolarTermKind]
    SOLAR_TERM_KIND_IPCHUN: _ClassVar[SolarTermKind]
    SOLAR_TERM_KIND_USU: _ClassVar[SolarTermKind]
    SOLAR_TERM_KIND_GYEONGCHIP: _ClassVar[SolarTermKind]
    SOLAR_TERM_KIND_CHUNBUN: _ClassVar[SolarTermKind]
    SOLAR_TERM_KIND_CHEONGMYEONG: _ClassVar[SolarTermKind]
    SOLAR_TERM_KIND_GOGU: _ClassVar[SolarTermKind]
    SOLAR_TERM_KIND_IPHA: _ClassVar[SolarTermKind]
    SOLAR_TERM_KIND_SOMAN: _ClassVar[SolarTermKind]
    SOLAR_TERM_KIND_MANGJONG: _ClassVar[SolarTermKind]
    SOLAR_TERM_KIND_HAJI: _ClassVar[SolarTermKind]
    SOLAR_TERM_KIND_SOSEO: _ClassVar[SolarTermKind]
    SOLAR_TERM_KIND_DAESEO: _ClassVar[SolarTermKind]
    SOLAR_TERM_KIND_IPCHU: _ClassVar[SolarTermKind]
    SOLAR_TERM_KIND_CHEOSEO: _ClassVar[SolarTermKind]
    SOLAR_TERM_KIND_BAENGNO: _ClassVar[SolarTermKind]
    SOLAR_TERM_KIND_CHUBUN: _ClassVar[SolarTermKind]
    SOLAR_TERM_KIND_HALLO: _ClassVar[SolarTermKind]
    SOLAR_TERM_KIND_SANGGANG: _ClassVar[SolarTermKind]
    SOLAR_TERM_KIND_IPDONG: _ClassVar[SolarTermKind]
    SOLAR_TERM_KIND_SOSEOL: _ClassVar[SolarTermKind]
    SOLAR_TERM_KIND_DAESEOL: _ClassVar[SolarTermKind]
    SOLAR_TERM_KIND_DONGJI: _ClassVar[SolarTermKind]
CALENDAR_TYPE_UNSPECIFIED: CalendarType
CALENDAR_TYPE_SOLAR: CalendarType
CALENDAR_TYPE_LUNAR: CalendarType
GENDER_UNSPECIFIED: Gender
GENDER_MALE: Gender
GENDER_FEMALE: Gender
ELEMENT_UNSPECIFIED: Element
ELEMENT_WOOD: Element
ELEMENT_FIRE: Element
ELEMENT_EARTH: Element
ELEMENT_METAL: Element
ELEMENT_WATER: Element
STEM_UNSPECIFIED: Stem
STEM_GAP: Stem
STEM_EUL: Stem
STEM_BYEONG: Stem
STEM_JEONG: Stem
STEM_MU: Stem
STEM_GI: Stem
STEM_GYEONG: Stem
STEM_SIN: Stem
STEM_IM: Stem
STEM_GYE: Stem
BRANCH_UNSPECIFIED: Branch
BRANCH_JA: Branch
BRANCH_CHUK: Branch
BRANCH_IN: Branch
BRANCH_MYO: Branch
BRANCH_JIN: Branch
BRANCH_SA: Branch
BRANCH_O: Branch
BRANCH_MI: Branch
BRANCH_SHIN: Branch
BRANCH_YU: Branch
BRANCH_SUL: Branch
BRANCH_HAE: Branch
TEN_GOD_UNSPECIFIED: TenGod
TEN_GOD_BIGYEON: TenGod
TEN_GOD_GEOPJAE: TenGod
TEN_GOD_SIKSIN: TenGod
TEN_GOD_SANGGWAN: TenGod
TEN_GOD_PYEONJAE: TenGod
TEN_GOD_JEONGJAE: TenGod
TEN_GOD_PYEONGWAN: TenGod
TEN_GOD_JEONGGWAN: TenGod
TEN_GOD_PYEONIN: TenGod
TEN_GOD_JEONGIN: TenGod
TWELVE_STAGE_UNSPECIFIED: TwelveStage
TWELVE_STAGE_JANGSAENG: TwelveStage
TWELVE_STAGE_MOKYOK: TwelveStage
TWELVE_STAGE_GWANDAE: TwelveStage
TWELVE_STAGE_GEONROK: TwelveStage
TWELVE_STAGE_JEWANG: TwelveStage
TWELVE_STAGE_SOE: TwelveStage
TWELVE_STAGE_BYEONG: TwelveStage
TWELVE_STAGE_SA: TwelveStage
TWELVE_STAGE_MYO: TwelveStage
TWELVE_STAGE_JEOL: TwelveStage
TWELVE_STAGE_TAE: TwelveStage
TWELVE_STAGE_YANG: TwelveStage
SHINSAL_UNSPECIFIED: Shinsal
SHINSAL_CHEONEUL_GWIIN: Shinsal
SHINSAL_DOHWA: Shinsal
SHINSAL_YEOKMA: Shinsal
SHINSAL_HWAGAE: Shinsal
SHINSAL_YANGIN: Shinsal
SHINSAL_GONGMANG: Shinsal
POSITION_UNSPECIFIED: Position
POSITION_YEAR_STEM: Position
POSITION_YEAR_BRANCH: Position
POSITION_MONTH_STEM: Position
POSITION_MONTH_BRANCH: Position
POSITION_DAY_STEM: Position
POSITION_DAY_BRANCH: Position
POSITION_HOUR_STEM: Position
POSITION_HOUR_BRANCH: Position
DIRECTION8_UNSPECIFIED: Direction8
DIRECTION8_N: Direction8
DIRECTION8_NE: Direction8
DIRECTION8_E: Direction8
DIRECTION8_SE: Direction8
DIRECTION8_S: Direction8
DIRECTION8_SW: Direction8
DIRECTION8_W: Direction8
DIRECTION8_NW: Direction8
DAY_KIND_UNSPECIFIED: DayKind
DAY_KIND_GWIIN_DAY: DayKind
DAY_KIND_YONGSIN_DAY: DayKind
DAY_KIND_GISIN_DAY: DayKind
DAY_KIND_ORDINARY_DAY: DayKind
STRENGTH_LEVEL_UNSPECIFIED: StrengthLevel
STRENGTH_LEVEL_VERY_WEAK: StrengthLevel
STRENGTH_LEVEL_WEAK: StrengthLevel
STRENGTH_LEVEL_NEUTRAL: StrengthLevel
STRENGTH_LEVEL_STRONG: StrengthLevel
STRENGTH_LEVEL_VERY_STRONG: StrengthLevel
YONGSIN_METHOD_UNSPECIFIED: YongsinMethod
YONGSIN_METHOD_JOHU: YongsinMethod
YONGSIN_METHOD_JOHU_NEUTRAL: YongsinMethod
YONGSIN_METHOD_EOKBU: YongsinMethod
LUCK_LEVEL_UNSPECIFIED: LuckLevel
LUCK_LEVEL_GOOD: LuckLevel
LUCK_LEVEL_NEUTRAL: LuckLevel
LUCK_LEVEL_CAUTION: LuckLevel
NOTICE_CODE_UNSPECIFIED: NoticeCode
NOTICE_CODE_AMBIGUOUS_LOCAL_TIME: NoticeCode
NOTICE_CODE_NONEXISTENT_LOCAL_TIME: NoticeCode
NOTICE_CODE_ZI_HOUR_NEXT_DAY: NoticeCode
NOTICE_CODE_TIME_UNKNOWN: NoticeCode
NOTICE_CODE_NEAR_SOLAR_TERM: NoticeCode
NOTICE_CODE_DAYUN_START_APPROXIMATE: NoticeCode
NOTICE_CODE_FOCUS_TIME_FALLBACK: NoticeCode
RELATION_KIND_UNSPECIFIED: RelationKind
RELATION_KIND_STEM_HAP: RelationKind
RELATION_KIND_BRANCH_HAP: RelationKind
RELATION_KIND_CHUNG: RelationKind
RELATION_KIND_HYEONG: RelationKind
ELEMENT_ROLE_UNSPECIFIED: ElementRole
ELEMENT_ROLE_YONGSIN: ElementRole
ELEMENT_ROLE_TONGGWAN: ElementRole
SOLAR_TERM_KIND_UNSPECIFIED: SolarTermKind
SOLAR_TERM_KIND_SOHAN: SolarTermKind
SOLAR_TERM_KIND_DAEHAN: SolarTermKind
SOLAR_TERM_KIND_IPCHUN: SolarTermKind
SOLAR_TERM_KIND_USU: SolarTermKind
SOLAR_TERM_KIND_GYEONGCHIP: SolarTermKind
SOLAR_TERM_KIND_CHUNBUN: SolarTermKind
SOLAR_TERM_KIND_CHEONGMYEONG: SolarTermKind
SOLAR_TERM_KIND_GOGU: SolarTermKind
SOLAR_TERM_KIND_IPHA: SolarTermKind
SOLAR_TERM_KIND_SOMAN: SolarTermKind
SOLAR_TERM_KIND_MANGJONG: SolarTermKind
SOLAR_TERM_KIND_HAJI: SolarTermKind
SOLAR_TERM_KIND_SOSEO: SolarTermKind
SOLAR_TERM_KIND_DAESEO: SolarTermKind
SOLAR_TERM_KIND_IPCHU: SolarTermKind
SOLAR_TERM_KIND_CHEOSEO: SolarTermKind
SOLAR_TERM_KIND_BAENGNO: SolarTermKind
SOLAR_TERM_KIND_CHUBUN: SolarTermKind
SOLAR_TERM_KIND_HALLO: SolarTermKind
SOLAR_TERM_KIND_SANGGANG: SolarTermKind
SOLAR_TERM_KIND_IPDONG: SolarTermKind
SOLAR_TERM_KIND_SOSEOL: SolarTermKind
SOLAR_TERM_KIND_DAESEOL: SolarTermKind
SOLAR_TERM_KIND_DONGJI: SolarTermKind

class LocalDate(_message.Message):
    __slots__ = ("year", "month", "day")
    YEAR_FIELD_NUMBER: _ClassVar[int]
    MONTH_FIELD_NUMBER: _ClassVar[int]
    DAY_FIELD_NUMBER: _ClassVar[int]
    year: int
    month: int
    day: int
    def __init__(self, year: _Optional[int] = ..., month: _Optional[int] = ..., day: _Optional[int] = ...) -> None: ...

class LocalTime(_message.Message):
    __slots__ = ("hour", "minute")
    HOUR_FIELD_NUMBER: _ClassVar[int]
    MINUTE_FIELD_NUMBER: _ClassVar[int]
    hour: int
    minute: int
    def __init__(self, hour: _Optional[int] = ..., minute: _Optional[int] = ...) -> None: ...

class Pillar(_message.Message):
    __slots__ = ("stem", "branch")
    STEM_FIELD_NUMBER: _ClassVar[int]
    BRANCH_FIELD_NUMBER: _ClassVar[int]
    stem: Stem
    branch: Branch
    def __init__(self, stem: _Optional[_Union[Stem, str]] = ..., branch: _Optional[_Union[Branch, str]] = ...) -> None: ...

class FourPillars(_message.Message):
    __slots__ = ("year", "month", "day", "hour")
    YEAR_FIELD_NUMBER: _ClassVar[int]
    MONTH_FIELD_NUMBER: _ClassVar[int]
    DAY_FIELD_NUMBER: _ClassVar[int]
    HOUR_FIELD_NUMBER: _ClassVar[int]
    year: Pillar
    month: Pillar
    day: Pillar
    hour: Pillar
    def __init__(self, year: _Optional[_Union[Pillar, _Mapping]] = ..., month: _Optional[_Union[Pillar, _Mapping]] = ..., day: _Optional[_Union[Pillar, _Mapping]] = ..., hour: _Optional[_Union[Pillar, _Mapping]] = ...) -> None: ...

class BirthInfo(_message.Message):
    __slots__ = ("calendar", "is_leap_month", "date", "time", "gender", "timezone", "longitude")
    CALENDAR_FIELD_NUMBER: _ClassVar[int]
    IS_LEAP_MONTH_FIELD_NUMBER: _ClassVar[int]
    DATE_FIELD_NUMBER: _ClassVar[int]
    TIME_FIELD_NUMBER: _ClassVar[int]
    GENDER_FIELD_NUMBER: _ClassVar[int]
    TIMEZONE_FIELD_NUMBER: _ClassVar[int]
    LONGITUDE_FIELD_NUMBER: _ClassVar[int]
    calendar: CalendarType
    is_leap_month: bool
    date: LocalDate
    time: LocalTime
    gender: Gender
    timezone: str
    longitude: float
    def __init__(self, calendar: _Optional[_Union[CalendarType, str]] = ..., is_leap_month: _Optional[bool] = ..., date: _Optional[_Union[LocalDate, _Mapping]] = ..., time: _Optional[_Union[LocalTime, _Mapping]] = ..., gender: _Optional[_Union[Gender, str]] = ..., timezone: _Optional[str] = ..., longitude: _Optional[float] = ...) -> None: ...

class ChartRequest(_message.Message):
    __slots__ = ("birth", "as_of")
    BIRTH_FIELD_NUMBER: _ClassVar[int]
    AS_OF_FIELD_NUMBER: _ClassVar[int]
    birth: BirthInfo
    as_of: LocalDate
    def __init__(self, birth: _Optional[_Union[BirthInfo, _Mapping]] = ..., as_of: _Optional[_Union[LocalDate, _Mapping]] = ...) -> None: ...

class DailyRequest(_message.Message):
    __slots__ = ("birth", "date", "current_timezone")
    BIRTH_FIELD_NUMBER: _ClassVar[int]
    DATE_FIELD_NUMBER: _ClassVar[int]
    CURRENT_TIMEZONE_FIELD_NUMBER: _ClassVar[int]
    birth: BirthInfo
    date: LocalDate
    current_timezone: str
    def __init__(self, birth: _Optional[_Union[BirthInfo, _Mapping]] = ..., date: _Optional[_Union[LocalDate, _Mapping]] = ..., current_timezone: _Optional[str] = ...) -> None: ...

class MonthRequest(_message.Message):
    __slots__ = ("birth", "year", "month", "current_timezone")
    BIRTH_FIELD_NUMBER: _ClassVar[int]
    YEAR_FIELD_NUMBER: _ClassVar[int]
    MONTH_FIELD_NUMBER: _ClassVar[int]
    CURRENT_TIMEZONE_FIELD_NUMBER: _ClassVar[int]
    birth: BirthInfo
    year: int
    month: int
    current_timezone: str
    def __init__(self, birth: _Optional[_Union[BirthInfo, _Mapping]] = ..., year: _Optional[int] = ..., month: _Optional[int] = ..., current_timezone: _Optional[str] = ...) -> None: ...

class Judgment(_message.Message):
    __slots__ = ("message_key", "params", "evidence")
    class ParamsEntry(_message.Message):
        __slots__ = ("key", "value")
        KEY_FIELD_NUMBER: _ClassVar[int]
        VALUE_FIELD_NUMBER: _ClassVar[int]
        key: str
        value: Param
        def __init__(self, key: _Optional[str] = ..., value: _Optional[_Union[Param, _Mapping]] = ...) -> None: ...
    MESSAGE_KEY_FIELD_NUMBER: _ClassVar[int]
    PARAMS_FIELD_NUMBER: _ClassVar[int]
    EVIDENCE_FIELD_NUMBER: _ClassVar[int]
    message_key: str
    params: _containers.MessageMap[str, Param]
    evidence: _containers.RepeatedCompositeFieldContainer[Evidence]
    def __init__(self, message_key: _Optional[str] = ..., params: _Optional[_Mapping[str, Param]] = ..., evidence: _Optional[_Iterable[_Union[Evidence, _Mapping]]] = ...) -> None: ...

class Param(_message.Message):
    __slots__ = ("text", "integer", "number", "flag")
    TEXT_FIELD_NUMBER: _ClassVar[int]
    INTEGER_FIELD_NUMBER: _ClassVar[int]
    NUMBER_FIELD_NUMBER: _ClassVar[int]
    FLAG_FIELD_NUMBER: _ClassVar[int]
    text: str
    integer: int
    number: float
    flag: bool
    def __init__(self, text: _Optional[str] = ..., integer: _Optional[int] = ..., number: _Optional[float] = ..., flag: _Optional[bool] = ...) -> None: ...

class Evidence(_message.Message):
    __slots__ = ("rule_id", "source_ref", "detail")
    class DetailEntry(_message.Message):
        __slots__ = ("key", "value")
        KEY_FIELD_NUMBER: _ClassVar[int]
        VALUE_FIELD_NUMBER: _ClassVar[int]
        key: str
        value: str
        def __init__(self, key: _Optional[str] = ..., value: _Optional[str] = ...) -> None: ...
    RULE_ID_FIELD_NUMBER: _ClassVar[int]
    SOURCE_REF_FIELD_NUMBER: _ClassVar[int]
    DETAIL_FIELD_NUMBER: _ClassVar[int]
    rule_id: str
    source_ref: str
    detail: _containers.ScalarMap[str, str]
    def __init__(self, rule_id: _Optional[str] = ..., source_ref: _Optional[str] = ..., detail: _Optional[_Mapping[str, str]] = ...) -> None: ...

class Notice(_message.Message):
    __slots__ = ("code", "detail")
    class DetailEntry(_message.Message):
        __slots__ = ("key", "value")
        KEY_FIELD_NUMBER: _ClassVar[int]
        VALUE_FIELD_NUMBER: _ClassVar[int]
        key: str
        value: str
        def __init__(self, key: _Optional[str] = ..., value: _Optional[str] = ...) -> None: ...
    CODE_FIELD_NUMBER: _ClassVar[int]
    DETAIL_FIELD_NUMBER: _ClassVar[int]
    code: NoticeCode
    detail: _containers.ScalarMap[str, str]
    def __init__(self, code: _Optional[_Union[NoticeCode, str]] = ..., detail: _Optional[_Mapping[str, str]] = ...) -> None: ...

class ResponseMeta(_message.Message):
    __slots__ = ("engine_version", "ruleset_version", "notices")
    ENGINE_VERSION_FIELD_NUMBER: _ClassVar[int]
    RULESET_VERSION_FIELD_NUMBER: _ClassVar[int]
    NOTICES_FIELD_NUMBER: _ClassVar[int]
    engine_version: str
    ruleset_version: str
    notices: _containers.RepeatedCompositeFieldContainer[Notice]
    def __init__(self, engine_version: _Optional[str] = ..., ruleset_version: _Optional[str] = ..., notices: _Optional[_Iterable[_Union[Notice, _Mapping]]] = ...) -> None: ...

class ChartResponse(_message.Message):
    __slots__ = ("pillars", "ten_gods", "hidden_stems", "twelve_stages", "shinsal", "gongmang", "element_weights", "strength", "yongsin", "daeun", "seun", "meta")
    PILLARS_FIELD_NUMBER: _ClassVar[int]
    TEN_GODS_FIELD_NUMBER: _ClassVar[int]
    HIDDEN_STEMS_FIELD_NUMBER: _ClassVar[int]
    TWELVE_STAGES_FIELD_NUMBER: _ClassVar[int]
    SHINSAL_FIELD_NUMBER: _ClassVar[int]
    GONGMANG_FIELD_NUMBER: _ClassVar[int]
    ELEMENT_WEIGHTS_FIELD_NUMBER: _ClassVar[int]
    STRENGTH_FIELD_NUMBER: _ClassVar[int]
    YONGSIN_FIELD_NUMBER: _ClassVar[int]
    DAEUN_FIELD_NUMBER: _ClassVar[int]
    SEUN_FIELD_NUMBER: _ClassVar[int]
    META_FIELD_NUMBER: _ClassVar[int]
    pillars: FourPillars
    ten_gods: _containers.RepeatedCompositeFieldContainer[PositionTenGod]
    hidden_stems: _containers.RepeatedCompositeFieldContainer[PositionHiddenStems]
    twelve_stages: _containers.RepeatedCompositeFieldContainer[PositionTwelveStage]
    shinsal: _containers.RepeatedCompositeFieldContainer[ShinsalHit]
    gongmang: _containers.RepeatedScalarFieldContainer[Branch]
    element_weights: _containers.RepeatedCompositeFieldContainer[ElementWeight]
    strength: Strength
    yongsin: YongsinInfo
    daeun: DaeunTable
    seun: _containers.RepeatedCompositeFieldContainer[YearLuck]
    meta: ResponseMeta
    def __init__(self, pillars: _Optional[_Union[FourPillars, _Mapping]] = ..., ten_gods: _Optional[_Iterable[_Union[PositionTenGod, _Mapping]]] = ..., hidden_stems: _Optional[_Iterable[_Union[PositionHiddenStems, _Mapping]]] = ..., twelve_stages: _Optional[_Iterable[_Union[PositionTwelveStage, _Mapping]]] = ..., shinsal: _Optional[_Iterable[_Union[ShinsalHit, _Mapping]]] = ..., gongmang: _Optional[_Iterable[_Union[Branch, str]]] = ..., element_weights: _Optional[_Iterable[_Union[ElementWeight, _Mapping]]] = ..., strength: _Optional[_Union[Strength, _Mapping]] = ..., yongsin: _Optional[_Union[YongsinInfo, _Mapping]] = ..., daeun: _Optional[_Union[DaeunTable, _Mapping]] = ..., seun: _Optional[_Iterable[_Union[YearLuck, _Mapping]]] = ..., meta: _Optional[_Union[ResponseMeta, _Mapping]] = ...) -> None: ...

class PositionTenGod(_message.Message):
    __slots__ = ("position", "ten_god")
    POSITION_FIELD_NUMBER: _ClassVar[int]
    TEN_GOD_FIELD_NUMBER: _ClassVar[int]
    position: Position
    ten_god: TenGod
    def __init__(self, position: _Optional[_Union[Position, str]] = ..., ten_god: _Optional[_Union[TenGod, str]] = ...) -> None: ...

class PositionHiddenStems(_message.Message):
    __slots__ = ("position", "stems")
    POSITION_FIELD_NUMBER: _ClassVar[int]
    STEMS_FIELD_NUMBER: _ClassVar[int]
    position: Position
    stems: _containers.RepeatedCompositeFieldContainer[HiddenStem]
    def __init__(self, position: _Optional[_Union[Position, str]] = ..., stems: _Optional[_Iterable[_Union[HiddenStem, _Mapping]]] = ...) -> None: ...

class HiddenStem(_message.Message):
    __slots__ = ("stem", "ten_god")
    STEM_FIELD_NUMBER: _ClassVar[int]
    TEN_GOD_FIELD_NUMBER: _ClassVar[int]
    stem: Stem
    ten_god: TenGod
    def __init__(self, stem: _Optional[_Union[Stem, str]] = ..., ten_god: _Optional[_Union[TenGod, str]] = ...) -> None: ...

class PositionTwelveStage(_message.Message):
    __slots__ = ("position", "twelve_stage")
    POSITION_FIELD_NUMBER: _ClassVar[int]
    TWELVE_STAGE_FIELD_NUMBER: _ClassVar[int]
    position: Position
    twelve_stage: TwelveStage
    def __init__(self, position: _Optional[_Union[Position, str]] = ..., twelve_stage: _Optional[_Union[TwelveStage, str]] = ...) -> None: ...

class ShinsalHit(_message.Message):
    __slots__ = ("kind", "position")
    KIND_FIELD_NUMBER: _ClassVar[int]
    POSITION_FIELD_NUMBER: _ClassVar[int]
    kind: Shinsal
    position: Position
    def __init__(self, kind: _Optional[_Union[Shinsal, str]] = ..., position: _Optional[_Union[Position, str]] = ...) -> None: ...

class ElementWeight(_message.Message):
    __slots__ = ("element", "weight")
    ELEMENT_FIELD_NUMBER: _ClassVar[int]
    WEIGHT_FIELD_NUMBER: _ClassVar[int]
    element: Element
    weight: float
    def __init__(self, element: _Optional[_Union[Element, str]] = ..., weight: _Optional[float] = ...) -> None: ...

class Strength(_message.Message):
    __slots__ = ("score", "level")
    SCORE_FIELD_NUMBER: _ClassVar[int]
    LEVEL_FIELD_NUMBER: _ClassVar[int]
    score: float
    level: StrengthLevel
    def __init__(self, score: _Optional[float] = ..., level: _Optional[_Union[StrengthLevel, str]] = ...) -> None: ...

class YongsinInfo(_message.Message):
    __slots__ = ("yongsin", "huisin", "gisin", "tonggwan", "method", "johu_stem", "judgment")
    YONGSIN_FIELD_NUMBER: _ClassVar[int]
    HUISIN_FIELD_NUMBER: _ClassVar[int]
    GISIN_FIELD_NUMBER: _ClassVar[int]
    TONGGWAN_FIELD_NUMBER: _ClassVar[int]
    METHOD_FIELD_NUMBER: _ClassVar[int]
    JOHU_STEM_FIELD_NUMBER: _ClassVar[int]
    JUDGMENT_FIELD_NUMBER: _ClassVar[int]
    yongsin: Element
    huisin: Element
    gisin: Element
    tonggwan: Element
    method: YongsinMethod
    johu_stem: Stem
    judgment: Judgment
    def __init__(self, yongsin: _Optional[_Union[Element, str]] = ..., huisin: _Optional[_Union[Element, str]] = ..., gisin: _Optional[_Union[Element, str]] = ..., tonggwan: _Optional[_Union[Element, str]] = ..., method: _Optional[_Union[YongsinMethod, str]] = ..., johu_stem: _Optional[_Union[Stem, str]] = ..., judgment: _Optional[_Union[Judgment, _Mapping]] = ...) -> None: ...

class DaeunTable(_message.Message):
    __slots__ = ("forward", "start_years", "start_months", "periods")
    FORWARD_FIELD_NUMBER: _ClassVar[int]
    START_YEARS_FIELD_NUMBER: _ClassVar[int]
    START_MONTHS_FIELD_NUMBER: _ClassVar[int]
    PERIODS_FIELD_NUMBER: _ClassVar[int]
    forward: bool
    start_years: int
    start_months: int
    periods: _containers.RepeatedCompositeFieldContainer[LuckPeriod]
    def __init__(self, forward: _Optional[bool] = ..., start_years: _Optional[int] = ..., start_months: _Optional[int] = ..., periods: _Optional[_Iterable[_Union[LuckPeriod, _Mapping]]] = ...) -> None: ...

class LuckPeriod(_message.Message):
    __slots__ = ("pillar", "start_age", "start_age_korean", "stem_ten_god", "branch_ten_god", "twelve_stage")
    PILLAR_FIELD_NUMBER: _ClassVar[int]
    START_AGE_FIELD_NUMBER: _ClassVar[int]
    START_AGE_KOREAN_FIELD_NUMBER: _ClassVar[int]
    STEM_TEN_GOD_FIELD_NUMBER: _ClassVar[int]
    BRANCH_TEN_GOD_FIELD_NUMBER: _ClassVar[int]
    TWELVE_STAGE_FIELD_NUMBER: _ClassVar[int]
    pillar: Pillar
    start_age: int
    start_age_korean: int
    stem_ten_god: TenGod
    branch_ten_god: TenGod
    twelve_stage: TwelveStage
    def __init__(self, pillar: _Optional[_Union[Pillar, _Mapping]] = ..., start_age: _Optional[int] = ..., start_age_korean: _Optional[int] = ..., stem_ten_god: _Optional[_Union[TenGod, str]] = ..., branch_ten_god: _Optional[_Union[TenGod, str]] = ..., twelve_stage: _Optional[_Union[TwelveStage, str]] = ...) -> None: ...

class YearLuck(_message.Message):
    __slots__ = ("year", "pillar", "ten_god", "relations_with_natal")
    YEAR_FIELD_NUMBER: _ClassVar[int]
    PILLAR_FIELD_NUMBER: _ClassVar[int]
    TEN_GOD_FIELD_NUMBER: _ClassVar[int]
    RELATIONS_WITH_NATAL_FIELD_NUMBER: _ClassVar[int]
    year: int
    pillar: Pillar
    ten_god: TenGod
    relations_with_natal: _containers.RepeatedScalarFieldContainer[RelationKind]
    def __init__(self, year: _Optional[int] = ..., pillar: _Optional[_Union[Pillar, _Mapping]] = ..., ten_god: _Optional[_Union[TenGod, str]] = ..., relations_with_natal: _Optional[_Iterable[_Union[RelationKind, str]]] = ...) -> None: ...

class DailyResponse(_message.Message):
    __slots__ = ("day", "kind", "color", "direction", "number", "focus_time", "relations", "featured_tags", "all_tags", "tag_evidence", "fortune", "guide", "meta")
    DAY_FIELD_NUMBER: _ClassVar[int]
    KIND_FIELD_NUMBER: _ClassVar[int]
    COLOR_FIELD_NUMBER: _ClassVar[int]
    DIRECTION_FIELD_NUMBER: _ClassVar[int]
    NUMBER_FIELD_NUMBER: _ClassVar[int]
    FOCUS_TIME_FIELD_NUMBER: _ClassVar[int]
    RELATIONS_FIELD_NUMBER: _ClassVar[int]
    FEATURED_TAGS_FIELD_NUMBER: _ClassVar[int]
    ALL_TAGS_FIELD_NUMBER: _ClassVar[int]
    TAG_EVIDENCE_FIELD_NUMBER: _ClassVar[int]
    FORTUNE_FIELD_NUMBER: _ClassVar[int]
    GUIDE_FIELD_NUMBER: _ClassVar[int]
    META_FIELD_NUMBER: _ClassVar[int]
    day: Pillar
    kind: DayKind
    color: ColorCard
    direction: DirectionCard
    number: NumberCard
    focus_time: FocusTimeCard
    relations: _containers.RepeatedCompositeFieldContainer[Relation]
    featured_tags: _containers.RepeatedScalarFieldContainer[str]
    all_tags: _containers.RepeatedScalarFieldContainer[str]
    tag_evidence: _containers.RepeatedCompositeFieldContainer[Evidence]
    fortune: _containers.RepeatedCompositeFieldContainer[Judgment]
    guide: Judgment
    meta: ResponseMeta
    def __init__(self, day: _Optional[_Union[Pillar, _Mapping]] = ..., kind: _Optional[_Union[DayKind, str]] = ..., color: _Optional[_Union[ColorCard, _Mapping]] = ..., direction: _Optional[_Union[DirectionCard, _Mapping]] = ..., number: _Optional[_Union[NumberCard, _Mapping]] = ..., focus_time: _Optional[_Union[FocusTimeCard, _Mapping]] = ..., relations: _Optional[_Iterable[_Union[Relation, _Mapping]]] = ..., featured_tags: _Optional[_Iterable[str]] = ..., all_tags: _Optional[_Iterable[str]] = ..., tag_evidence: _Optional[_Iterable[_Union[Evidence, _Mapping]]] = ..., fortune: _Optional[_Iterable[_Union[Judgment, _Mapping]]] = ..., guide: _Optional[_Union[Judgment, _Mapping]] = ..., meta: _Optional[_Union[ResponseMeta, _Mapping]] = ...) -> None: ...

class ColorCard(_message.Message):
    __slots__ = ("judgment", "element", "role")
    JUDGMENT_FIELD_NUMBER: _ClassVar[int]
    ELEMENT_FIELD_NUMBER: _ClassVar[int]
    ROLE_FIELD_NUMBER: _ClassVar[int]
    judgment: Judgment
    element: Element
    role: ElementRole
    def __init__(self, judgment: _Optional[_Union[Judgment, _Mapping]] = ..., element: _Optional[_Union[Element, str]] = ..., role: _Optional[_Union[ElementRole, str]] = ...) -> None: ...

class DirectionCard(_message.Message):
    __slots__ = ("judgment", "direction", "rule_id")
    JUDGMENT_FIELD_NUMBER: _ClassVar[int]
    DIRECTION_FIELD_NUMBER: _ClassVar[int]
    RULE_ID_FIELD_NUMBER: _ClassVar[int]
    judgment: Judgment
    direction: Direction8
    rule_id: str
    def __init__(self, judgment: _Optional[_Union[Judgment, _Mapping]] = ..., direction: _Optional[_Union[Direction8, str]] = ..., rule_id: _Optional[str] = ...) -> None: ...

class NumberCard(_message.Message):
    __slots__ = ("judgment", "number")
    JUDGMENT_FIELD_NUMBER: _ClassVar[int]
    NUMBER_FIELD_NUMBER: _ClassVar[int]
    judgment: Judgment
    number: int
    def __init__(self, judgment: _Optional[_Union[Judgment, _Mapping]] = ..., number: _Optional[int] = ...) -> None: ...

class FocusTimeCard(_message.Message):
    __slots__ = ("judgment", "picks", "fallback")
    JUDGMENT_FIELD_NUMBER: _ClassVar[int]
    PICKS_FIELD_NUMBER: _ClassVar[int]
    FALLBACK_FIELD_NUMBER: _ClassVar[int]
    judgment: Judgment
    picks: _containers.RepeatedCompositeFieldContainer[FocusSlot]
    fallback: bool
    def __init__(self, judgment: _Optional[_Union[Judgment, _Mapping]] = ..., picks: _Optional[_Iterable[_Union[FocusSlot, _Mapping]]] = ..., fallback: _Optional[bool] = ...) -> None: ...

class FocusSlot(_message.Message):
    __slots__ = ("branch", "pillar", "start", "end", "huangdao_lucky", "score", "reasons")
    BRANCH_FIELD_NUMBER: _ClassVar[int]
    PILLAR_FIELD_NUMBER: _ClassVar[int]
    START_FIELD_NUMBER: _ClassVar[int]
    END_FIELD_NUMBER: _ClassVar[int]
    HUANGDAO_LUCKY_FIELD_NUMBER: _ClassVar[int]
    SCORE_FIELD_NUMBER: _ClassVar[int]
    REASONS_FIELD_NUMBER: _ClassVar[int]
    branch: Branch
    pillar: Pillar
    start: _timestamp_pb2.Timestamp
    end: _timestamp_pb2.Timestamp
    huangdao_lucky: bool
    score: int
    reasons: _containers.RepeatedScalarFieldContainer[str]
    def __init__(self, branch: _Optional[_Union[Branch, str]] = ..., pillar: _Optional[_Union[Pillar, _Mapping]] = ..., start: _Optional[_Union[datetime.datetime, _timestamp_pb2.Timestamp, _Mapping]] = ..., end: _Optional[_Union[datetime.datetime, _timestamp_pb2.Timestamp, _Mapping]] = ..., huangdao_lucky: _Optional[bool] = ..., score: _Optional[int] = ..., reasons: _Optional[_Iterable[str]] = ...) -> None: ...

class Relation(_message.Message):
    __slots__ = ("kind", "natal_position", "suppressed_by")
    KIND_FIELD_NUMBER: _ClassVar[int]
    NATAL_POSITION_FIELD_NUMBER: _ClassVar[int]
    SUPPRESSED_BY_FIELD_NUMBER: _ClassVar[int]
    kind: RelationKind
    natal_position: Position
    suppressed_by: RelationKind
    def __init__(self, kind: _Optional[_Union[RelationKind, str]] = ..., natal_position: _Optional[_Union[Position, str]] = ..., suppressed_by: _Optional[_Union[RelationKind, str]] = ...) -> None: ...

class MonthResponse(_message.Message):
    __slots__ = ("days", "meta")
    DAYS_FIELD_NUMBER: _ClassVar[int]
    META_FIELD_NUMBER: _ClassVar[int]
    days: _containers.RepeatedCompositeFieldContainer[MonthDay]
    meta: ResponseMeta
    def __init__(self, days: _Optional[_Iterable[_Union[MonthDay, _Mapping]]] = ..., meta: _Optional[_Union[ResponseMeta, _Mapping]] = ...) -> None: ...

class MonthDay(_message.Message):
    __slots__ = ("date", "pillar", "lunar_month", "lunar_day", "is_leap_month", "solar_term", "kind", "luck_level", "score", "score_items", "featured_tag", "judgment")
    DATE_FIELD_NUMBER: _ClassVar[int]
    PILLAR_FIELD_NUMBER: _ClassVar[int]
    LUNAR_MONTH_FIELD_NUMBER: _ClassVar[int]
    LUNAR_DAY_FIELD_NUMBER: _ClassVar[int]
    IS_LEAP_MONTH_FIELD_NUMBER: _ClassVar[int]
    SOLAR_TERM_FIELD_NUMBER: _ClassVar[int]
    KIND_FIELD_NUMBER: _ClassVar[int]
    LUCK_LEVEL_FIELD_NUMBER: _ClassVar[int]
    SCORE_FIELD_NUMBER: _ClassVar[int]
    SCORE_ITEMS_FIELD_NUMBER: _ClassVar[int]
    FEATURED_TAG_FIELD_NUMBER: _ClassVar[int]
    JUDGMENT_FIELD_NUMBER: _ClassVar[int]
    date: LocalDate
    pillar: Pillar
    lunar_month: int
    lunar_day: int
    is_leap_month: bool
    solar_term: SolarTerm
    kind: DayKind
    luck_level: LuckLevel
    score: int
    score_items: _containers.RepeatedCompositeFieldContainer[ScoreItem]
    featured_tag: str
    judgment: Judgment
    def __init__(self, date: _Optional[_Union[LocalDate, _Mapping]] = ..., pillar: _Optional[_Union[Pillar, _Mapping]] = ..., lunar_month: _Optional[int] = ..., lunar_day: _Optional[int] = ..., is_leap_month: _Optional[bool] = ..., solar_term: _Optional[_Union[SolarTerm, _Mapping]] = ..., kind: _Optional[_Union[DayKind, str]] = ..., luck_level: _Optional[_Union[LuckLevel, str]] = ..., score: _Optional[int] = ..., score_items: _Optional[_Iterable[_Union[ScoreItem, _Mapping]]] = ..., featured_tag: _Optional[str] = ..., judgment: _Optional[_Union[Judgment, _Mapping]] = ...) -> None: ...

class SolarTerm(_message.Message):
    __slots__ = ("name", "at", "kind")
    NAME_FIELD_NUMBER: _ClassVar[int]
    AT_FIELD_NUMBER: _ClassVar[int]
    KIND_FIELD_NUMBER: _ClassVar[int]
    name: str
    at: _timestamp_pb2.Timestamp
    kind: SolarTermKind
    def __init__(self, name: _Optional[str] = ..., at: _Optional[_Union[datetime.datetime, _timestamp_pb2.Timestamp, _Mapping]] = ..., kind: _Optional[_Union[SolarTermKind, str]] = ...) -> None: ...

class ScoreItem(_message.Message):
    __slots__ = ("id", "score")
    ID_FIELD_NUMBER: _ClassVar[int]
    SCORE_FIELD_NUMBER: _ClassVar[int]
    id: str
    score: int
    def __init__(self, id: _Optional[str] = ..., score: _Optional[int] = ...) -> None: ...
