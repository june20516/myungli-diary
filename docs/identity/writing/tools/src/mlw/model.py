"""검사기가 공유하는 데이터 모델."""

from dataclasses import dataclass, field
from pathlib import Path
from typing import Final, Literal

Severity = Literal["error", "warn"]
Judge = Literal["rule", "llm"]
DetectKind = Literal["regex", "lexicon", "template"]
Scope = Literal["sentence", "slot", "screen", "day", "week"]

LANGS: tuple[str, ...] = ("ko", "en", "ja")
SENTENCE_TYPES: tuple[str, ...] = ("advice", "state", "care")
PURPOSES: tuple[str, ...] = ("info", "guide", "care")
SEVERITIES: tuple[str, ...] = ("error", "warn")
SCOPES: tuple[str, ...] = ("sentence", "slot", "screen", "day", "week")
JUDGES: tuple[str, ...] = ("rule", "llm")
DETECT_KINDS: tuple[str, ...] = ("regex", "lexicon", "template")


@dataclass(frozen=True)
class Finding:
    file: Path
    line: int
    rule_id: str
    severity: Severity
    message: str

    def format(self) -> str:
        return f"{self.file}:{self.line} {self.rule_id} {self.severity} {self.message}"


class LoadError(Exception):
    """YAML 로드·구조 오류. 문제를 모두 모아 한 번에 던집니다."""

    def __init__(self, findings: list[Finding]) -> None:
        super().__init__("\n".join(finding.format() for finding in findings))
        self.findings = findings


@dataclass(frozen=True)
class Detect:
    kind: DetectKind
    pattern: str | None = None
    words: tuple[str, ...] = ()
    # 비어 있으면 모든 언어에 적용합니다.
    langs: frozenset[str] = frozenset()
    # True면 NFC만 적용한 원문에서 판정합니다(자리표시자 뒤의 글자를 봐야 하는 규칙).
    raw: bool = False


@dataclass(frozen=True)
class Example:
    lang: str
    slot_purpose: str
    text: str


@dataclass(frozen=True)
class Examples:
    hit: tuple[Example, ...] = ()
    pass_: tuple[Example, ...] = ()


@dataclass(frozen=True)
class SlopRule:
    id: str
    name: str
    judge: Judge
    severity: Severity
    detect: Detect | None
    rubric: str | None
    exempt_purposes: frozenset[str]
    examples: Examples
    line: int


@dataclass(frozen=True)
class CountSelector:
    """여섯 중 하나만 채웁니다."""

    placeholder: str | None = None
    type: str | None = None
    rule: str | None = None
    # 정규화 텍스트에 목록 단어가 하나라도 든 원고 수를 셉니다.
    lexicon: tuple[str, ...] | None = None
    # 원고 안의 용어 토큰 개수를 셉니다. `true`만 허용합니다.
    token: bool | None = None
    # 용어 토큰이 하나 이상 든 원고 수를 셉니다. `true`만 허용합니다.
    token_entries: bool | None = None


@dataclass(frozen=True)
class Limit:
    id: str
    name: str
    scope: Scope
    count: CountSelector
    # 언어별 상한. None은 "아직 정하지 않음"이며 검사에서 건너뜁니다.
    max: dict[str, int | None]
    severity: Severity
    line: int
    # scope가 week일 때 검사하는 연속 일수입니다(2~7). 다른 scope에서는 쓰지 않습니다.
    window: int = 7


@dataclass(frozen=True)
class StyleRule:
    id: str
    name: str
    severity: Severity
    detect: Detect
    exempt_purposes: frozenset[str]
    examples: Examples
    line: int


@dataclass(frozen=True)
class JosaPair:
    marker: str
    with_batchim: str
    without_batchim: str
    # 받침을 판정할 수 없을 때 쓰는 병기형입니다.
    fallback: str
    # ㄹ 받침일 때만 다른 값을 쓰는 쌍에 채웁니다.
    rieul: str | None = None


@dataclass(frozen=True)
class JosaReadings:
    """숫자·영문·한자를 한글 독음으로 바꾸는 표."""

    digits: dict[str, str]
    trailing_zeros: dict[int, str]
    latin: dict[str, str]
    hanja: dict[str, str]


@dataclass(frozen=True)
class NameExample:
    """호칭 입력 하나와 기준 구현(`normalize_name`)의 결과입니다. 거부하면 value는 None입니다."""

    lang: str
    input: str
    value: str | None
    codes: tuple[str, ...]


@dataclass(frozen=True)
class NameRules:
    max_length: dict[str, int]
    strip_suffix: dict[str, tuple[str, ...]]
    warn_suffix: dict[str, tuple[str, ...]]
    # 원고 표기(자리표시자·조사·용어 토큰)와 섞이지 않게 호칭에 받지 않는 글자입니다.
    forbidden_chars: tuple[str, ...] = ()
    examples: tuple[NameExample, ...] = ()


@dataclass(frozen=True)
class JosaExample:
    text: str
    expected: str


@dataclass(frozen=True)
class JosaData:
    pairs: tuple[JosaPair, ...]
    readings: JosaReadings
    name_rules: NameRules
    examples: tuple[JosaExample, ...]


@dataclass(frozen=True)
class RuleSet:
    slop: dict[str, SlopRule]
    limits: dict[str, Limit]
    style: dict[str, StyleRule]
    josa: JosaData


ParamKindName = Literal["glossary", "list", "number", "none", "text"]
PARAM_KIND_NUMBER = "number"
PARAM_KIND_NONE = "none"
PARAM_KIND_TEXT = "text"
# `list:<범주>` 표기의 접두어입니다.
PARAM_KIND_LIST_PREFIX = "list:"


@dataclass(frozen=True)
class ParamKind:
    """매개변수 값을 문장에 렌더하는 방식입니다(슬롯 명세 `params` 맵의 값).

    * glossary: 값 이름 사전 범주로 바꿉니다. `categories`의 첫째가 기본 범주, 나머지는 `{p:cat}`로 고르는 범주입니다.
    * list: 목록 값의 원소마다 `categories[0]` 범주 이름으로 바꿔 `, `로 잇습니다.
    * number: 숫자를 그대로 씁니다.
    * none: 문장에 쓸 수 없는 값입니다.
    * text: 렌더하는 쪽이 만든 문자열(날짜, 시각, 가격, 일정 제목)을 그대로 씁니다.
    """

    kind: ParamKindName
    categories: tuple[str, ...] = ()

    @property
    def default_category(self) -> str | None:
        return self.categories[0] if self.categories else None


# 레이아웃이 길이를 막지 않아 상한을 두지 않는 슬롯·키입니다(#191). None(아직 정하지 않음)과 구별합니다.
UNBOUNDED: Final = "unbounded"
# 언어별 글자 수 상한 값: 양의 정수, UNBOUNDED, None(미정)입니다.
LengthLimit = int | Literal["unbounded"] | None


@dataclass(frozen=True)
class Slot:
    """콘텐츠 슬롯 명세 하나(spec §4.1)입니다. 미정 필드는 빈 값으로 읽습니다."""

    id: str
    where: str
    purpose: str
    # 문장 유형을 적용하지 않는 슬롯은 비어 있습니다.
    types: tuple[str, ...]
    # 유형마다(유형이 없으면 키마다) 필요한 변주 수입니다.
    variants: int
    # 메시지 키 또는 식별자 -> 매개변수 이름 -> 값 종류. `name`은 따로 적지 않아도 어느 슬롯에서나 씁니다.
    keys: dict[str, dict[str, ParamKind]]
    co_display: tuple[str, ...]
    # 언어별 글자 수 상한. None은 아직 정하지 않음, UNBOUNDED는 상한을 두지 않음입니다.
    max_length: dict[str, LengthLimit]
    allowed: frozenset[str]
    forbidden: frozenset[str]
    examples: dict[str, list[dict[str, object]]]
    line: int
    file: Path
    user_state: str = ""
    structure: str = ""
    tone: dict[str, int] = field(default_factory=dict)
    endings: tuple[str, ...] = ()
    # 문장이 들어가는 IA 슬롯 id입니다(슬롯 명세 v1.1).
    ia: tuple[str, ...] = ()
    # IA 슬롯이 아니라 컴포넌트 안에 들어가는 이름의 자리(IA 컴포넌트 id)입니다.
    components: tuple[str, ...] = ()
    # 렌더하는 쪽이 키를 고르는 방법입니다. writing 식별자 키를 쓰는 content 슬롯에 적습니다.
    select: str = ""
    # 호칭 자리(D36)입니다. True인 슬롯만 `{name}`을 씁니다.
    vocative: bool = False
    # 키별 언어별 상한입니다. 적힌 언어는 슬롯 상한 대신 씁니다(확인 창의 제목·본문·버튼처럼 칸이 다른 키, #191).
    key_max_length: dict[str, dict[str, LengthLimit]] = field(default_factory=dict)

    def length_limit(self, lang: str, key: str | None = None) -> int | None:
        """검사에 쓸 글자 수 상한입니다. 미정(None)과 상한 없음(UNBOUNDED)은 둘 다 재지 않으므로 None입니다."""
        limits = self.key_max_length.get(key, {}) if key is not None else {}
        value = limits[lang] if lang in limits else self.max_length.get(lang)
        return value if isinstance(value, int) else None


@dataclass(frozen=True)
class Entry:
    """원고 한 문장(변형 하나)입니다."""

    file: Path
    line: int
    slot: str
    key: str
    type: str | None
    variant: int
    lang: str
    text: str
