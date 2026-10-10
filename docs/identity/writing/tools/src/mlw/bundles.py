"""화면·하루 묶음의 빈도·밀도 검사.

하루 데일리 화면에 함께 나올 수 있는 문장 조합을 엔진 규칙대로 모두 만들어 limits.yaml 상한을 확인합니다.
묶음 검사는 존재하는 원고만 셉니다. 빠진 원고는 완결성 검사의 몫입니다.
"""

from collections.abc import Iterable, Iterator, Mapping, Sequence
from dataclasses import dataclass

from mlw.model import SENTENCE_TYPES, Entry, Finding, Limit, RuleSet, Slot
from mlw.placeholders import parse
from mlw.sentence import detectable_rules, matches, normalize_for_detection

DAY_KINDS: tuple[str, ...] = ("gwiin_day", "yongsin_day", "gisin_day", "ordinary_day")
TEN_GOD_GROUPS: tuple[str, ...] = ("bigyeop", "siksang", "jaeseong", "gwanseong", "inseong")
FOCUS_KEYS: tuple[str, ...] = (
    "focus_time.fallback",
    "focus_time.gwiin",
    "focus_time.hap",
    "focus_time.huisin",
    "focus_time.yongsin",
)
# 날의 성격과 상관없이 대표 태그가 될 수 있는 태그 접미사입니다.
COMMON_TAGS: tuple[str, ...] = (
    "big_change",
    "cheoneul_gwiin",
    "clash",
    "dohwa",
    "gongmang",
    "harmony",
    "hwagae",
    "ten_god_rush.bigyeop",
    "ten_god_rush.gwanseong",
    "ten_god_rush.inseong",
    "ten_god_rush.jaeseong",
    "ten_god_rush.siksang",
    "yeokma",
)
# 해당 날의 성격에서만 대표 태그가 되는 태그입니다.
KIND_ONLY_TAGS: Mapping[str, str] = {"gwiin_day": "gwiin_day", "yongsin_day": "yongsin_day"}
DEFAULT_GUIDE_VARIANTS = 2

SLOT_HEAD = "daily.fortune.head"
SLOT_TAG = "daily.fortune.tag"
SLOT_GUIDE = "daily.guide"
SLOT_COLOR = "daily.color"
SLOT_DIRECTION = "daily.direction"
SLOT_NUMBER = "daily.number"
SLOT_FOCUS = "daily.focus_time"
SLOT_TAG_LABEL = "daily.tag_label"
# 유형 순환을 따르는 슬롯입니다.
TYPED_SLOTS = frozenset({SLOT_HEAD, SLOT_TAG})
SCREEN_SCOPES: tuple[str, ...] = ("screen", "day")

EntriesBy = Mapping[tuple[str, str, str], Sequence[Entry]]


@dataclass(frozen=True)
class DayKeys:
    """하루 화면에 나오는 메시지 키 조합입니다."""

    head: str
    tag_sentence: str | None
    guide: str
    color: str
    direction: str
    number: str
    focus: str
    tag_label: str | None

    def bundle(self) -> "Bundle":
        pairs: list[tuple[str, str | None]] = [
            (SLOT_HEAD, self.head),
            (SLOT_TAG, self.tag_sentence),
            (SLOT_GUIDE, self.guide),
            (SLOT_COLOR, self.color),
            (SLOT_DIRECTION, self.direction),
            (SLOT_NUMBER, self.number),
            (SLOT_FOCUS, self.focus),
            (SLOT_TAG_LABEL, self.tag_label),
        ]
        return Bundle(tuple((slot, key) for slot, key in pairs if key is not None))


@dataclass(frozen=True)
class Bundle:
    """(슬롯 ID, 키) 나열입니다. 화면에 나오는 순서입니다."""

    keys: tuple[tuple[str, str], ...]


def _tags_for(kind: str) -> list[str]:
    tags = list(COMMON_TAGS)
    if kind in KIND_ONLY_TAGS:
        tags.append(KIND_ONLY_TAGS[kind])
    return tags


def enumerate_days() -> Iterator[DayKeys]:
    """날의 성격 x 십성 그룹 x 대표 태그(없음 포함) x 집중 시간 키를 모두 만듭니다."""
    for kind in DAY_KINDS:
        for group in TEN_GOD_GROUPS:
            for tag in (None, *_tags_for(kind)):
                for focus in FOCUS_KEYS:
                    yield DayKeys(
                        head=f"fortune.{kind}.{group}",
                        tag_sentence=None if tag is None else f"fortune.tag.{tag}",
                        guide=f"guide.ten_god.{group}" if tag is None else f"guide.{tag}",
                        color=f"color.{kind}",
                        direction=f"direction.day_kind.{kind.removesuffix('_day')}",
                        number=f"number.{kind}",
                        focus=focus,
                        tag_label=None if tag is None else f"tag.{tag}",
                    )


def _pick(candidates: Sequence[Entry], slot: str, rotation: int, guide_variant: int) -> Entry | None:
    if slot in TYPED_SLOTS:
        wanted = SENTENCE_TYPES[rotation % len(SENTENCE_TYPES)]
        return next((entry for entry in candidates if entry.type == wanted), None)
    if slot == SLOT_GUIDE:
        return next((entry for entry in candidates if entry.variant == guide_variant), None)
    return candidates[0] if candidates else None


def assemble(
    day: DayKeys, entries_by: EntriesBy, lang: str, rotation: int, guide_variant: int
) -> list[Entry]:
    """하루 키 조합에 순환 위치를 적용해 실제 원고를 고릅니다. 없는 원고는 건너뜁니다."""
    picked: list[Entry] = []
    for slot, key in day.bundle().keys:
        entry = _pick(entries_by.get((slot, key, lang), ()), slot, rotation, guide_variant)
        if entry is not None:
            picked.append(entry)
    return picked


def _entry_count(entry: Entry, limit: Limit, rules: RuleSet | None) -> int:
    selector = limit.count
    if selector.type is not None:
        return int(entry.type == selector.type)
    if selector.placeholder is not None:
        try:
            return sum(placeholder.name == selector.placeholder for placeholder in parse(entry.text))
        except ValueError:
            # 문법 오류는 문장 단위 검사가 보고합니다.
            return 0
    if selector.rule is not None and rules is not None:
        return int(_hits_rule(entry, selector.rule, rules))
    return 0


def _hits_rule(entry: Entry, rule_id: str, rules: RuleSet) -> bool:
    try:
        normalized = normalize_for_detection(entry.text)
    except ValueError:
        return False
    return any(
        rule.id == rule_id and rule.detect is not None and matches(rule.detect, entry.lang, normalized)
        for rule in detectable_rules(rules)
    )


def check_limits(
    entries: Sequence[Entry],
    limits: Iterable[Limit],
    scope: str,
    lang: str,
    where: str,
    rules: RuleSet | None = None,
) -> list[Finding]:
    """묶음 하나가 `scope` 범위 상한을 넘는지 봅니다. 상한을 처음 넘게 만든 원고 위치로 보고합니다."""
    findings: list[Finding] = []
    for limit in limits:
        maximum = limit.max.get(lang)
        if limit.scope != scope or maximum is None:
            continue
        total = 0
        for entry in entries:
            total += _entry_count(entry, limit, rules)
            if total > maximum:
                message = f"{limit.name}: {where}에서 {total}회로 상한 {maximum}회를 넘습니다 ({lang})"
                findings.append(Finding(entry.file, entry.line, limit.id, limit.severity, message))
                break
    return findings


def _entries_by(entries: Iterable[Entry]) -> dict[tuple[str, str, str], list[Entry]]:
    result: dict[tuple[str, str, str], list[Entry]] = {}
    for entry in entries:
        result.setdefault((entry.slot, entry.key, entry.lang), []).append(entry)
    return result


def check_days(
    slots: Mapping[str, Slot],
    entries: Sequence[Entry],
    limits: Iterable[Limit],
    langs: Sequence[str],
    rules: RuleSet | None = None,
) -> list[Finding]:
    """모든 하루 조합 x 순환 위치 x 가이드 변주에 화면·하루 상한을 검사합니다.

    같은 (규칙 ID, 파일, 줄)의 finding은 한 번만 냅니다.
    """
    active = [limit for limit in limits if limit.scope in SCREEN_SCOPES]
    if not any(maximum is not None for limit in active for maximum in limit.max.values()):
        return []
    guide_slot = slots.get(SLOT_GUIDE)
    guide_variants = guide_slot.variants if guide_slot is not None else DEFAULT_GUIDE_VARIANTS
    entries_by = _entries_by(entries)
    seen: set[tuple[str, str, int]] = set()
    findings: list[Finding] = []
    for lang in langs:
        for day in enumerate_days():
            where = f"하루 화면 {day.head} / {day.tag_sentence or '대표 태그 없음'} / {day.focus}"
            for rotation in range(len(SENTENCE_TYPES)):
                for guide_variant in range(1, guide_variants + 1):
                    bundle = assemble(day, entries_by, lang, rotation, guide_variant)
                    for scope in SCREEN_SCOPES:
                        for finding in check_limits(bundle, active, scope, lang, where, rules):
                            identity = (finding.rule_id, str(finding.file), finding.line)
                            if identity not in seen:
                                seen.add(identity)
                                findings.append(finding)
    return findings
