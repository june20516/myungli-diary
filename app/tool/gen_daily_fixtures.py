"""오늘 화면 fixture(`fixtures/<시나리오>/getDaily.json`)의 엔진 값을 채웁니다.

member 프로필(`fixtures/member/updateProfile.json`: 양력 1990-05-15 14:30, 여성, Asia/Seoul)로 core
`compose_daily`를 돌립니다. 엔진은 규칙 2026.11.7(덕일, 밤 집중 시간, 색 둘)을 냅니다.

기존 시나리오(`member`, `member-time-unknown`, `evidence-unlocked`, `reward-unlock`, 오늘 2026-10-13)
* 손으로 쓴 응답은 그대로 두고 REST 1.11.0에서 더한 값만 엔진으로 채웁니다. 시나리오의 오늘은
  `dayKind: yongsin_day`, 행운 색 초록처럼 화면을 보이려고 고른 값이라 엔진 값(보통의 날)과 다릅니다
  (`gen_calendar_fixtures.py`의 2026-10-13 설명과 같음).
* `dayVirtues`: 엔진 판정 그대로입니다(2026-10-13은 덕일이 없어 빈 배열).
* `cards.focusTime`: 낮 시진은 화면에 보이던 사시(09:30~11:30)를 그대로 두고, 그 시진을 엔진 규칙
  (`grade_hour`, `_focus_judgment`)으로 판정해 `dayDate`, `dayPillar`, `huangdaoLucky`, 문장, 근거를 채웁니다.
  엔진의 낮 1등 시진(신시)과는 다릅니다. `picks`는 1개, `fallback` false, `reasons` 빈 배열입니다
  (규칙 2026.11.4 이후, `FocusTimeCard`, `FocusSlot` 설명).
* `cards.nightFocusTime`, `cards.previousNightFocusTime`: 엔진의 그날 밤, 전날 밤 1등 시진입니다.
  시나리오의 오늘이 요청 날짜라 전날 밤도 담습니다(server `previousNight`).

새 시나리오 `daily-pair-virtue`(오늘 2026-10-19, 근거 잠김)
* 색이 둘인 날(`secondColor`)이면서 천덕일과 월덕일이 함께 드는 날입니다(戌월 丙寅일). 응답 전체가 엔진 값이고,
  문장은 writing ko 원고를 이 도구가 대신 렌더한 것입니다. 변주를 고르는 server 선택 기록은 흉내 내지 않고
  총운은 `advice`, 총운 아래 문장은 `state`, 질문은 `1`을 씁니다. server 렌더와 같은 결과를 보장하지는 않습니다.

문장과 근거(두 경우 모두)
* 문장은 writing ko 원고(`docs/identity/writing/content/ko/`)의 틀에 매개변수를 넣은 것입니다. 값 이름은
  `glossary.yaml`의 `glossary.value_name`, 조사는 받침으로 고릅니다.
* 근거는 server 규칙을 따릅니다. 잠긴 응답은 근거마다 판정 근거와 원전 문장의 앞부분(ko 띄어쓰기 단어 3개,
  `evidencePreview`), 열린 응답은 근거 전부(`evidence`)입니다. 오늘 그런 이유(`todayReason`)는 근거 규칙 중
  `reason.<ruleId>` 원고가 있는 첫 규칙의 문장입니다.

core/에서 실행합니다(엔진 가상환경을 씁니다).
    uv run python ../app/tool/gen_daily_fixtures.py ../app/fixtures
"""

from __future__ import annotations

import json
import re
import sys
from datetime import date, time, timedelta
from pathlib import Path

from myungli_engine.calendar_core import lunar_adapter
from myungli_engine.calendar_core.birth import BirthInput
from myungli_engine.composers.chart import prepare_natal
from myungli_engine.composers.daily import _focus_judgment, compose_daily
from myungli_engine.domain.enums import Branch, CalendarType, Gender, TenGod
from myungli_engine.domain.models import Judgment
from myungli_engine.rules.focus_time import FocusPeriod, FocusPick, grade_hour

SEOUL = "Asia/Seoul"
KNOWN = BirthInput(CalendarType.SOLAR, False, date(1990, 5, 15), time(14, 30), Gender.FEMALE, SEOUL, None)
UNKNOWN = BirthInput(CalendarType.SOLAR, False, date(1990, 5, 15), None, Gender.FEMALE, SEOUL, None)

# 기존 시나리오의 오늘과 화면에 보이던 낮 시진(위 설명).
TODAY = date(2026, 10, 13)
TODAY_DAY_BRANCH = Branch.SA
# 새 시나리오의 오늘: 색 둘, 천덕일과 월덕일(위 설명).
PAIR_DAY = date(2026, 10, 19)
# 시나리오의 다른 fixture와 같은 규칙 버전 값입니다(`gen_chart_fixtures.py`의 RULESET 설명).
RULESET = "r1"

# 이 도구 기준 저장소 경로(app/tool/ → 저장소 뿌리).
REPO = Path(__file__).resolve().parents[2]
CONTENT = REPO / "docs/identity/writing/content/ko"

SLOTS = REPO / "docs/identity/writing/slots/content"

# 조사 표지 → (받침 있을 때, 받침 없을 때). `(으)로`는 ㄹ 받침도 받침 없음과 같습니다.
JOSA = {
    "(이)에요": ("이에요", "예요"),
    "(이)가": ("이", "가"),
    "(을)를": ("을", "를"),
    "(은)는": ("은", "는"),
    "(와)과": ("과", "와"),
    "(으)로": ("으로", "로"),
}
# 숫자를 한국어로 읽었을 때의 받침(0 영, 1 일, 3 삼, 6 육, 7 칠, 8 팔).
DIGIT_FINAL = {"0": "ㅇ", "1": "ㄹ", "3": "ㅁ", "6": "ㄱ", "7": "ㄹ", "8": "ㄹ"}

PREVIEW_WORDS = 3

TAG_POLARITY = {
    # server `internal/fortune/polarity.go`의 표(엔진 spec §7.7)입니다.
    "tag.big_change": "bad",
    "tag.clash": "bad",
    "tag.clash_day_branch": "bad",
    "tag.clash_month_branch": "bad",
    "tag.harmony": "good",
    "tag.ten_god_rush.bigyeop": "neutral",
    "tag.ten_god_rush.siksang": "good",
    "tag.ten_god_rush.jaeseong": "good",
    "tag.ten_god_rush.gwanseong": "bad",
    "tag.ten_god_rush.inseong": "good",
    "tag.cheoneul_gwiin": "good",
    "tag.dohwa": "good",
    "tag.yeokma": "neutral",
    "tag.hwagae": "neutral",
    "tag.gongmang": "bad",
    "tag.gosin": "bad",
    "tag.gwasuk": "bad",
    "tag.wonjin": "bad",
    "tag.yongsin_day": "good",
    "tag.gwiin_day": "good",
}


# ---------- writing 원고 ----------

_FIELD = re.compile(r'(\w+): ("(?:[^"\\]|\\.)*"|[^,}]+)')


def _load_lines() -> dict[tuple[str, str, str], str]:
    """원고 줄 `{slot, key, (type|variant), text}` → (slot, key, 변주) → 문장. 변주가 없으면 single입니다."""
    out: dict[tuple[str, str, str], str] = {}
    for path in sorted(CONTENT.glob("*.yaml")):
        for line in path.read_text(encoding="utf-8").splitlines():
            if not line.startswith("- {"):
                continue
            fields = {name: value.strip() for name, value in _FIELD.findall(line)}
            if "slot" not in fields or "text" not in fields:
                continue
            unquote = lambda v: json.loads(v) if v.startswith('"') else v  # noqa: E731
            variant = unquote(fields.get("type") or fields.get("variant") or "single")
            out[(unquote(fields["slot"]), unquote(fields["key"]), str(variant))] = unquote(fields["text"])
    return out


LINES = _load_lines()

_PARAMS_LINE = re.compile(r"^\s*- params: \{(?P<body>.*)\}\s*$")
_PARAM_ENTRY = re.compile(r"(\w+): (\[[^\]]*\]|\w+)")


def _load_param_kinds() -> dict[str, dict[str, str | None]]:
    """슬롯 명세의 키 → 매개변수 → 기본 glossary 범주(값 종류 `text`, `number`, `none`이면 None)."""
    out: dict[str, dict[str, str | None]] = {}
    for path in sorted(SLOTS.glob("*.yaml")):
        lines = path.read_text(encoding="utf-8").splitlines()
        for index, text in enumerate(lines):
            match = _PARAMS_LINE.match(text)
            if match is None:
                continue
            kinds = {
                name: (kind.strip("[]").split(",")[0].strip() if kind.startswith("[") else None)
                for name, kind in _PARAM_ENTRY.findall(match["body"])
            }
            keys: list[str] = []
            following = lines[index + 1].strip()
            if following.startswith("keys: ["):
                keys = [k.strip().strip('"') for k in following[len("keys: [") : -1].split(",")]
            elif following == "keys:":
                for item in lines[index + 2 :]:
                    item = item.strip()
                    if not item.startswith("- ") or item.startswith("- params:"):
                        break
                    keys.append(item[2:].strip().strip('"'))
            for key in keys:
                out[key] = kinds
    return out


PARAM_KINDS = _load_param_kinds()


def line(slot: str, key: str, variant: str = "single") -> str | None:
    return LINES.get((slot, key, variant))


def value_name(category: str, key: str) -> str:
    name = line("glossary.value_name", f"{category}.{key}")
    if name is None:
        raise KeyError(f"glossary 값 이름이 없습니다: {category}.{key}")
    return name


# ---------- 렌더 ----------


def _has_final(word: str, *, rieul_as_open: bool = False) -> bool:
    last = word[-1]
    if last in DIGIT_FINAL or last.isdigit():
        final = DIGIT_FINAL.get(last)
        return final is not None and not (rieul_as_open and final == "ㄹ")
    code = ord(last) - 0xAC00
    if not 0 <= code <= 11171:
        return False
    jong = code % 28
    return jong != 0 and not (rieul_as_open and jong == 8)


def _apply_josa(text: str) -> str:
    for marker, (closed, opened) in JOSA.items():
        while marker in text:
            index = text.index(marker)
            before = text[:index]
            closed_word = _has_final(before, rieul_as_open=marker == "(으)로")
            text = before + (closed if closed_word else opened) + text[index + len(marker) :]
    return text


def _param(name: str, category: str | None, params: dict[str, str], kinds: dict[str, str | None]) -> tuple[str, str | None]:
    """(표시 글자, 용어 id). 범주가 없으면(값 종류 `text`, `number`) 값을 그대로 씁니다."""
    raw = str(params[name])
    if kinds.get(name) is None and category is None:
        return raw, None
    category = category or kinds[name]
    if category is None:
        return raw, None
    key = raw.lower()
    if category == "ten_god_group" and raw in TenGod.__members__:
        # 십성 값을 묶음 범주로 고르면 그 십성의 묶음 이름입니다(`{ten_god:ten_god_group}`).
        key = TenGod[raw].group.name.lower()
    return value_name(category, key), f"{category}.{key}"


_TOKEN = re.compile(r"\[\[(?P<term_text>[^\]|]+)\|(?P<term>[^\]]+)\]\]|\[\[\{(?P<term_param>\w+)(?::(?P<term_cat>\w+))?\}\]\]|\{(?P<param>\w+)(?::(?P<cat>\w+))?\}")


def render(template: str, params: dict[str, str], key: str = "") -> list[dict]:
    """원고 틀을 조각 배열로 렌더합니다. `[[글자|용어]]`, `[[{p}]]`는 용어 조각, `{p}`, `{p:범주}`는 글자입니다."""
    kinds = PARAM_KINDS.get(key, {})
    segments: list[dict] = []
    buffer = ""
    position = 0
    for match in _TOKEN.finditer(template):
        buffer += template[position : match.start()]
        position = match.end()
        if match["term"]:
            text, term = match["term_text"], match["term"]
        elif match["term_param"]:
            text, term = _param(match["term_param"], match["term_cat"], params, kinds)
        else:
            text, _ = _param(match["param"], match["cat"], params, kinds)
            buffer += text
            continue
        if buffer:
            segments.append({"text": buffer})
            buffer = ""
        segments.append({"text": text, "term": term})
    buffer += template[position:]
    if buffer:
        segments.append({"text": buffer})
    # 조사는 앞 조각의 끝 글자로 고르므로 조각을 이어 고른 뒤 다시 나눕니다.
    return _josa_segments(segments)


def _josa_segments(segments: list[dict]) -> list[dict]:
    out: list[dict] = []
    for segment in segments:
        text = segment["text"]
        if "term" not in segment and out and any(text.startswith(m) for m in JOSA):
            marker = next(m for m in JOSA if text.startswith(m))
            prev = out[-1]["text"]
            closed, opened = JOSA[marker]
            word = closed if _has_final(prev, rieul_as_open=marker == "(으)로") else opened
            text = word + text[len(marker) :]
        if "term" not in segment:
            text = _apply_josa(text)
        out.append({**segment, "text": text})
    return out


def preview(segments: list[dict] | None) -> list[dict] | None:
    """잠긴 문장의 앞부분(server `render.Preview` ko 규칙, D106). 자를 수 없으면 None입니다."""
    if not segments:
        return None
    text = "".join(s["text"] for s in segments)
    ends = [m.end() for m in re.finditer(r"\S+", text)]
    count = min(PREVIEW_WORDS, len(ends) - 1)
    if count < 1:
        return None
    cut = ends[count - 1]
    out: list[dict] = []
    offset = 0
    for segment in segments:
        if offset >= cut:
            break
        end = offset + len(segment["text"])
        out.append(segment if end <= cut else {"text": segment["text"][: cut - offset]})
        offset = end
    return out


def rendered(segments: list[dict]) -> dict:
    return {"segments": segments}


def evidence_items(judgment: Judgment) -> list[dict]:
    """근거마다 판정 근거(`basis.<ruleId>`)와 원전(`source.<sourceRef>`) 문장(server `Renderer.evidence`)."""
    items = []
    for evidence in judgment.evidence:
        detail = {k: str(v) for k, v in evidence.detail.items()}
        item: dict = {"ruleId": evidence.rule_id, "sourceRef": evidence.source_ref, "detail": detail}
        basis = line("evidence.basis", f"basis.{evidence.rule_id}")
        if basis is not None:
            item["basis"] = rendered(render(basis, detail, f"basis.{evidence.rule_id}"))
        source = line("evidence.source", f"source.{evidence.source_ref}")
        if source is not None:
            item["source"] = rendered(render(source, {}))
        items.append(item)
    return items


def slot_text(slot: str, judgment: Judgment, *, unlocked: bool, variant: str = "single", name: str = "") -> dict:
    template = line(slot, judgment.message_key, variant)
    if template is None:
        raise KeyError(f"원고가 없습니다: {slot} {judgment.message_key} {variant}")
    params = {k: str(v) for k, v in judgment.params.items()}
    if name:
        params["name"] = name
    out: dict = {
        "slot": slot,
        "messageKey": judgment.message_key,
        "variant": variant,
        # server `content.Reactable`: 총운 두 슬롯만 true입니다.
        "reactable": slot in ("daily.fortune.head", "daily.fortune.tag"),
        "text": rendered(render(template, params, judgment.message_key)),
    }
    for evidence in judgment.evidence:
        reason = line("explain.today_reason", f"reason.{evidence.rule_id}")
        if reason is not None:
            out["todayReason"] = rendered(render(reason, {}))
            break
    items = evidence_items(judgment)
    if unlocked and items:
        out["evidence"] = items
    if not unlocked:
        previews = []
        for item in items:
            head = {
                key: rendered(cut)
                for key in ("basis", "source")
                if key in item and (cut := preview(item[key]["segments"])) is not None
            }
            if head:
                previews.append(head)
        if previews:
            out["evidencePreview"] = previews
    return out


# ---------- REST 모양 ----------


def pillar(p) -> dict:
    return {"stem": p.stem.name.lower(), "branch": p.branch.name.lower()}


def focus_card(pick: FocusPick, judgment: Judgment, *, unlocked: bool) -> dict:
    grade = pick.grade
    slot = grade.slot
    return {
        "picks": [
            {
                "branch": slot.branch.name.lower(),
                "start": slot.start.isoformat(),
                "end": slot.end.isoformat(),
                "huangdaoLucky": slot.huangdao_lucky,
                "dayDate": grade.day_date.isoformat(),
                "dayPillar": pillar(grade.day),
                "reasons": [],
            }
        ],
        "fallback": False,
        "text": slot_text("daily.focus_time", judgment, unlocked=unlocked),
    }


def day_virtues(view, *, unlocked: bool) -> list[dict]:
    """원고가 없는 덕일은 뺍니다(`DayVirtue` 설명, server `renderDayVirtues`)."""
    out = []
    for kind, judgment in view.day_virtues:
        if line("explain.day_virtue", judgment.message_key) is None:
            continue
        out.append(
            {
                "kind": kind.name.lower(),
                "text": slot_text("explain.day_virtue", judgment, unlocked=unlocked),
            }
        )
    return out


def chosen_day_pick(birth: BirthInput, target: date, branch: Branch) -> tuple[FocusPick, Judgment]:
    """[target]의 낮 시진 [branch]를 엔진 규칙으로 판정합니다(기존 시나리오의 손으로 고른 시진)."""
    hours = lunar_adapter.hour_slots(target, SEOUL)
    slot = next(s for s in hours if s.branch is branch)
    day = lunar_adapter.day_pillar(target)
    birth_year = prepare_natal(birth).chart.pillars.year
    grade = grade_hour(slot, day, birth_year, target)
    if grade is None:
        raise ValueError(f"{target} {branch.name} 시진은 엔진이 후보에서 뺍니다")
    pick = FocusPick(FocusPeriod.DAY, grade)
    return pick, _focus_judgment(pick, birth_year)


def patch_existing(body: dict, birth: BirthInput) -> dict:
    """기존 손 fixture에 REST 1.11.0 값을 엔진으로 채웁니다(위 설명)."""
    unlocked = body["evidenceAccess"] == "unlocked"
    target = date.fromisoformat(body["date"])
    view = compose_daily(birth, target, SEOUL)
    previous = compose_daily(birth, target - timedelta(days=1), SEOUL)
    cards = body["cards"]
    day_pick, day_judgment = chosen_day_pick(birth, target, TODAY_DAY_BRANCH)
    night_pick, night_judgment = view.focus[1]
    previous_pick, previous_judgment = previous.focus[1]
    patched_cards = {
        key: value
        for key, value in cards.items()
        if key not in ("focusTime", "nightFocusTime", "previousNightFocusTime")
    }
    patched_cards["focusTime"] = focus_card(day_pick, day_judgment, unlocked=unlocked)
    patched_cards["nightFocusTime"] = focus_card(night_pick, night_judgment, unlocked=unlocked)
    patched_cards["previousNightFocusTime"] = focus_card(previous_pick, previous_judgment, unlocked=unlocked)
    return {**body, "cards": patched_cards, "dayVirtues": day_virtues(view, unlocked=unlocked)}


def full_daily(birth: BirthInput, target: date, *, unlocked: bool, today: bool) -> dict:
    """엔진 응답 전체를 REST `Daily`로 옮깁니다(새 시나리오)."""
    view = compose_daily(birth, target, SEOUL)
    first_color, *other_colors = view.colors
    head, tag = view.fortune[0], (view.fortune[1] if len(view.fortune) > 1 else None)
    guide_variants = ("1", "2")

    def color_card(pick, judgment) -> dict:
        return {
            "element": pick.element.name.lower(),
            "role": pick.role.name.lower(),
            "text": slot_text("daily.color", judgment, unlocked=unlocked),
        }

    cards: dict = {"color": color_card(*first_color)}
    if other_colors:
        cards["secondColor"] = color_card(*other_colors[0])
    direction, direction_judgment = view.direction
    number, number_judgment = view.number
    cards["direction"] = {
        "direction": direction.direction.name.lower(),
        "text": slot_text("daily.direction", direction_judgment, unlocked=unlocked),
    }
    cards["number"] = {"number": number, "text": slot_text("daily.number", number_judgment, unlocked=unlocked)}
    (day_pick, day_judgment), (night_pick, night_judgment) = view.focus
    cards["focusTime"] = focus_card(day_pick, day_judgment, unlocked=unlocked)
    cards["nightFocusTime"] = focus_card(night_pick, night_judgment, unlocked=unlocked)
    if today:
        previous = compose_daily(birth, target - timedelta(days=1), SEOUL)
        previous_pick, previous_judgment = previous.focus[1]
        cards["previousNightFocusTime"] = focus_card(previous_pick, previous_judgment, unlocked=unlocked)

    guide = slot_text("daily.guide", view.guide, unlocked=unlocked, variant=guide_variants[0])
    candidates = [guide]
    for variant in guide_variants[1:]:
        if line("daily.guide", view.guide.message_key, variant) is not None:
            candidates.append(slot_text("daily.guide", view.guide, unlocked=unlocked, variant=variant))
    for judgment in view.guide_candidates[1:]:
        if line("daily.guide", judgment.message_key, guide_variants[0]) is not None:
            candidates.append(slot_text("daily.guide", judgment, unlocked=unlocked, variant=guide_variants[0]))

    kind = view.kind.name.lower()
    character = line("character.reason", f"character.reason.{kind}")
    fortune: dict = {"head": slot_text("daily.fortune.head", head, unlocked=unlocked, variant="advice")}
    if tag is not None:
        fortune["tag"] = slot_text("daily.fortune.tag", tag, unlocked=unlocked, variant="state")
    relations = []
    for relation in view.relations:
        item: dict = {
            "kind": relation.kind.name.lower(),
            "natalPosition": relation.natal_position.name.lower(),
            "suppressed": relation.suppressed_by is not None,
        }
        if relation.suppressed_by is not None:
            item["suppressedBy"] = relation.suppressed_by.name.lower()
        relations.append(item)
    return {
        "date": target.isoformat(),
        "rulesetVersion": RULESET,
        "evidenceAccess": "unlocked" if unlocked else "locked",
        "dayPillar": pillar(view.day),
        "lunar": {"month": view.lunar.month, "day": view.lunar.day, "isLeapMonth": view.lunar.is_leap_month},
        "dayStemTenGod": view.day_stem_ten_god.name.lower(),
        "dayStemTenGodGroup": view.day_stem_ten_god.group.name.lower(),
        "dayKind": kind,
        "characterReason": {
            "slot": "character.reason",
            "messageKey": f"character.reason.{kind}",
            "variant": "1",
            "reactable": False,
            "text": rendered(render(character, {})),
        },
        "fortune": fortune,
        "guide": guide,
        "guideCandidates": candidates,
        "cards": cards,
        "tags": {
            "featured": [{"key": k.removeprefix("tag."), "polarity": TAG_POLARITY[k]} for k in view.tags.featured],
            "all": [k.removeprefix("tag.") for k in view.tags.all_keys],
        },
        "relations": relations,
        "notices": [],
        "dayVirtues": day_virtues(view, unlocked=unlocked),
    }


def response(body: dict) -> dict:
    return {"status": 200, "headers": {"Content-Type": "application/json"}, "body": body}


def read(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def write(path: Path, fixture: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(fixture, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(path)


def main(out: Path) -> None:
    for scenario, birth in (
        ("member", KNOWN),
        ("member-time-unknown", UNKNOWN),
        ("evidence-unlocked", KNOWN),
        ("reward-unlock", KNOWN),
    ):
        path = out / scenario / "getDaily.json"
        fixture = read(path)
        if "sequence" in fixture:
            fixture["sequence"] = [
                {**item, "body": patch_existing(item["body"], birth)} for item in fixture["sequence"]
            ]
        else:
            fixture["body"] = patch_existing(fixture["body"], birth)
        write(path, fixture)
    write(
        out / "daily-pair-virtue" / "getDaily.json",
        response(full_daily(KNOWN, PAIR_DAY, unlocked=False, today=True)),
    )


if __name__ == "__main__":
    main(Path(sys.argv[1]))
