"""검사기가 공유하는 데이터 모델."""

from dataclasses import dataclass
from pathlib import Path
from typing import Literal

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
    """셋 중 하나만 채웁니다."""

    placeholder: str | None = None
    type: str | None = None
    rule: str | None = None


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
class NameRules:
    max_length: dict[str, int]
    strip_suffix: dict[str, tuple[str, ...]]
    warn_suffix: dict[str, tuple[str, ...]]


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
