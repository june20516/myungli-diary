"""오늘 화면 fixture(`fixtures/<시나리오>/getDaily.json`)의 엔진 값을 채웁니다.

member 프로필(`fixtures/member/updateProfile.json`: 양력 1990-05-15 14:30, 여성, Asia/Seoul)로 core
`compose_daily`를 돌립니다. 엔진은 규칙 2026.11.7(덕일, 밤 집중 시간, 색 둘)을 냅니다.

기존 시나리오(`member`, `member-time-unknown`, `evidence-unlocked`, `reward-unlock`, 오늘 2026-10-13)
* 손으로 쓴 응답은 그대로 두고 REST 1.11.0에서 더한 값만 엔진으로 채웁니다. 시나리오의 오늘은
  `dayKind: yongsin_day`, 행운 색 초록처럼 화면을 보이려고 고른 값이라 엔진 값(보통의 날)과 다릅니다
  (`gen_calendar_fixtures.py`의 2026-10-13 설명과 같음).
* `dayVirtues`: 엔진 판정 그대로입니다(2026-10-13은 덕일이 없어 빈 배열).
* `cards.focusTime`, `cards.nightFocusTime`, `cards.previousNightFocusTime`: 엔진의 그날 낮, 그날 밤, 전날 밤
  1등 시진입니다. `picks`는 1개, `fallback` false, `reasons` 빈 배열입니다(규칙 2026.11.4 이후,
  `FocusTimeCard`, `FocusSlot` 설명). 시나리오의 오늘이 요청 날짜라 전날 밤도 담습니다(server `previousNight`).
  집중 시간은 날의 성격과 상관없이 시진 등급으로 정해지므로 손으로 고른 `dayKind`와 함께 있어도 엔진 값 그대로입니다
  (2026-10-13 낮은 신시 15:30~17:30).
* `fortune.head`, `fortune.tag`의 `reactable`은 server 규칙대로 true입니다(`content.Reactable`).

새 시나리오 `daily-pair-virtue`(근거 잠김)와 `daily-pair-virtue-unlocked`(근거 열림), 오늘 2026-10-19
* 기존 짝(`member`, `evidence-unlocked`)처럼 같은 날의 잠긴 응답과 열린 응답입니다.
* 색이 둘인 날(`secondColor`)이면서 천덕일과 월덕일이 함께 드는 날입니다(戌월 丙寅일). 응답 전체가 엔진 값이고,
  문장은 writing ko 원고를 이 도구가 대신 렌더한 것입니다. 변주를 고르는 server 선택 기록은 흉내 내지 않고
  총운은 `advice`, 총운 아래 문장은 `state`, 질문은 `1`을 씁니다. server 렌더와 같은 결과를 보장하지는 않습니다.

문장과 근거(두 경우 모두, 렌더는 `fixture_content.py`)
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
import sys
from datetime import date, time, timedelta
from pathlib import Path

from fixture_content import line, render, rendered, slot_text
from myungli_engine.calendar_core.birth import BirthInput
from myungli_engine.composers.daily import compose_daily
from myungli_engine.domain.enums import CalendarType, Gender
from myungli_engine.domain.models import Judgment
from myungli_engine.rules.focus_time import FocusPick

SEOUL = "Asia/Seoul"
KNOWN = BirthInput(CalendarType.SOLAR, False, date(1990, 5, 15), time(14, 30), Gender.FEMALE, SEOUL, None)
UNKNOWN = BirthInput(CalendarType.SOLAR, False, date(1990, 5, 15), None, Gender.FEMALE, SEOUL, None)

# 새 시나리오의 오늘: 색 둘, 천덕일과 월덕일(위 설명).
PAIR_DAY = date(2026, 10, 19)
# 시나리오의 다른 fixture와 같은 규칙 버전 값입니다(`gen_chart_fixtures.py`의 RULESET 설명).
RULESET = "r1"

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


def patch_existing(body: dict, birth: BirthInput) -> dict:
    """기존 손 fixture에 REST 1.11.0 값을 엔진으로 채웁니다(위 설명)."""
    unlocked = body["evidenceAccess"] == "unlocked"
    target = date.fromisoformat(body["date"])
    view = compose_daily(birth, target, SEOUL)
    previous = compose_daily(birth, target - timedelta(days=1), SEOUL)
    cards = body["cards"]
    day_pick, day_judgment = view.focus[0]
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
    # server는 총운 두 슬롯 모두 반응을 받습니다(`content.Reactable`).
    fortune = {key: {**text, "reactable": True} for key, text in body["fortune"].items()}
    return {
        **body,
        "fortune": fortune,
        "cards": patched_cards,
        "dayVirtues": day_virtues(view, unlocked=unlocked),
    }


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
    for scenario, unlocked in (("daily-pair-virtue", False), ("daily-pair-virtue-unlocked", True)):
        write(
            out / scenario / "getDaily.json",
            response(full_daily(KNOWN, PAIR_DAY, unlocked=unlocked, today=True)),
        )


if __name__ == "__main__":
    main(Path(sys.argv[1]))
