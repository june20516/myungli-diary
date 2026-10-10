"""화면·하루 묶음의 빈도·밀도 검사.

하루 데일리 화면에 함께 나올 수 있는 문장 조합을 엔진 규칙대로 모두 만들어 limits.yaml 상한을 확인합니다.
묶음 검사는 존재하는 원고만 셉니다. 빠진 원고는 완결성 검사의 몫입니다.
"""

from collections import Counter
from collections.abc import Iterable, Iterator, Mapping, Sequence
from dataclasses import dataclass
from datetime import date, timedelta
from itertools import product
from pathlib import Path

from mlw.model import SENTENCE_TYPES, Entry, Finding, Limit, RuleSet, Slot
from mlw.placeholders import parse, parse_tokens
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
RUSH_PREFIX = "ten_god_rush."
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
WEEK_LENGTH = 7
ROTATION_OFFSETS: tuple[int, ...] = (0, 1, 2)
FIXTURE_PATH = Path("fixtures/week_samples.json")
STALE_RULE_ID = "week.fixture_stale"

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


def _tags_for(kind: str, group: str) -> list[str]:
    """일진 천간과 지지 정기의 십성 그룹이 같을 때만 그 그룹의 쏠림 태그가 나옵니다."""
    tags = [tag for tag in COMMON_TAGS if not tag.startswith(RUSH_PREFIX) or tag == f"{RUSH_PREFIX}{group}"]
    if kind in KIND_ONLY_TAGS:
        tags.append(KIND_ONLY_TAGS[kind])
    return tags


def enumerate_days() -> Iterator[DayKeys]:
    """날의 성격 x 십성 그룹 x 대표 태그(없음 포함) x 집중 시간 키를 모두 만듭니다."""
    for kind in DAY_KINDS:
        for group in TEN_GOD_GROUPS:
            for tag in (None, *_tags_for(kind, group)):
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


def _entry_count(entry: Entry, limit: Limit, rules: RuleSet) -> int:
    selector = limit.count
    if selector.type is not None:
        return int(entry.type == selector.type)
    if selector.placeholder is not None:
        try:
            return sum(placeholder.name == selector.placeholder for placeholder in parse(entry.text))
        except ValueError:
            # 문법 오류는 문장 단위 검사가 보고합니다.
            return 0
    if selector.rule is not None:
        return int(_hits_rule(entry, selector.rule, rules))
    if selector.lexicon is not None:
        words = selector.lexicon
        normalized = _normalized_or_none(entry)
        return int(normalized is not None and any(word in normalized for word in words))
    if selector.token is not None or selector.token_entries is not None:
        count = _token_count(entry)
        return count if selector.token is not None else int(count > 0)
    return 0


def _normalized_or_none(entry: Entry) -> str | None:
    try:
        return normalize_for_detection(entry.text)
    except ValueError:
        # 문법 오류는 문장 단위 검사가 보고합니다.
        return None


def _token_count(entry: Entry) -> int:
    try:
        return len(parse_tokens(entry.text))
    except ValueError:
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
    rules: RuleSet,
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
    rules: RuleSet,
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


def week_windows[T](days: Sequence[T], length: int) -> list[Sequence[T]]:
    """날 목록을 `length`일 연속 창으로 한 칸씩 밀며 자릅니다."""
    return [days[start : start + length] for start in range(len(days) - length + 1)]


def _day_from_fixture(raw: Mapping[str, object]) -> DayKeys:
    def text(name: str) -> str | None:
        value = raw.get(name)
        return value if isinstance(value, str) else None

    return DayKeys(
        head=text("head") or "",
        tag_sentence=text("tag_sentence"),
        guide=text("guide") or "",
        color=text("color") or "",
        direction=text("direction") or "",
        number=text("number") or "",
        focus=text("focus") or "",
        tag_label=text("tag_label"),
    )


def _fixture_samples(fixture: Mapping[str, object]) -> list[tuple[str, date | None, list[DayKeys]]]:
    start_text = fixture.get("start")
    start = date.fromisoformat(start_text) if isinstance(start_text, str) else None
    raw_samples = fixture.get("samples")
    samples: list[tuple[str, date | None, list[DayKeys]]] = []
    for raw in raw_samples if isinstance(raw_samples, list) else []:
        raw_days = raw.get("days", [])
        days = [_day_from_fixture(day) for day in raw_days]
        samples.append((str(raw.get("birth_id", "")), start, days))
    return samples


def _stale_findings(
    samples: Sequence[tuple[str, date | None, list[DayKeys]]],
    message_keys: Sequence[str],
    fixture_path: Path,
) -> list[Finding]:
    known = set(message_keys)
    unknown = sorted(
        {
            key
            for _, _, days in samples
            for day in days
            for _slot, key in day.bundle().keys
            if key not in known
        }
    )
    return [
        Finding(
            fixture_path,
            1,
            STALE_RULE_ID,
            "error",
            f"고정 자료의 키 {key}가 message_keys.json에 없습니다. 고정 자료를 다시 만드세요",
        )
        for key in unknown
    ]


def _rotate(
    days: Sequence[DayKeys],
    entries_by: EntriesBy,
    lang: str,
    type_offset: int,
    variant_offset: int,
    variants: int,
) -> list[list[Entry]]:
    """표본의 날을 앞에서부터 지나며 키별 출현 횟수로 유형과 가이드 변주를 정합니다.

    유형 시작 위치와 가이드 변주 시작 위치는 서로 독립입니다.
    """
    appearances: Counter[tuple[str, str]] = Counter()
    per_day: list[list[Entry]] = []
    for day in days:
        picked: list[Entry] = []
        for slot, key in day.bundle().keys:
            count = appearances[(slot, key)]
            appearances[(slot, key)] += 1
            guide_variant = (variant_offset + count) % variants + 1
            entry = _pick(entries_by.get((slot, key, lang), ()), slot, type_offset + count, guide_variant)
            if entry is not None:
                picked.append(entry)
        per_day.append(picked)
    return per_day


def check_weeks(
    slots: Mapping[str, Slot],
    entries: Sequence[Entry],
    limits: Iterable[Limit],
    langs: Sequence[str],
    rules: RuleSet,
    fixture: Mapping[str, object],
    message_keys: Sequence[str],
    fixture_path: Path = FIXTURE_PATH,
) -> list[Finding]:
    """고정 자료의 실제 날짜 순서로 유형 순환을 흉내 내 연속 7일 창마다 한 주 상한을 확인합니다.

    순환은 사용자별로 키마다 따로 돌고, 유형 시작 위치 0·1·2와 가이드 변주 시작 위치를 독립으로 모두 조합해 검사합니다.
    같은 (규칙 ID, 파일, 줄)의 finding은 한 번만 냅니다.
    """
    samples = _fixture_samples(fixture)
    findings = _stale_findings(samples, message_keys, fixture_path)
    if findings:
        return findings
    active = [limit for limit in limits if limit.scope == "week"]
    guide_slot = slots.get(SLOT_GUIDE)
    variants = guide_slot.variants if guide_slot is not None else DEFAULT_GUIDE_VARIANTS
    entries_by = _entries_by(entries)
    seen: set[tuple[str, str, int]] = set()
    for lang in langs:
        for birth_id, start, days in samples:
            for offset, variant_offset in product(ROTATION_OFFSETS, range(variants)):
                per_day = _rotate(days, entries_by, lang, offset, variant_offset, variants)
                for first, window in enumerate(week_windows(per_day, WEEK_LENGTH)):
                    when = f"{start + timedelta(days=first)}부터 7일" if start else f"{first + 1}일째부터 7일"
                    where = f"표본 {birth_id} {when} (유형 시작 {offset}, 가이드 변주 시작 {variant_offset + 1})"
                    week_entries = [entry for day_entries in window for entry in day_entries]
                    for finding in check_limits(week_entries, active, "week", lang, where, rules):
                        identity = (finding.rule_id, str(finding.file), finding.line)
                        if identity not in seen:
                            seen.add(identity)
                            findings.append(finding)
    return findings
