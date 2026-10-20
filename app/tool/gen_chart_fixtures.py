"""나의 사주 fixture(`fixtures/<시나리오>/getChart.json`)를 만듭니다.

member 프로필(`fixtures/member/updateProfile.json`: 양력 1990-05-15 14:30, 여성, Asia/Seoul)로
core `compose_chart`를 기준일 2026-10-13(시나리오의 오늘)에 돌려 원국·십성·지장간·12운성·신살·공망·
오행 가중치·강약·용신·대운·세운·안내를 엔진 값 그대로 REST `Chart` 모양으로 옮깁니다.

시나리오
* `member`: 근거 열람 권한 없음(`evidenceAccess: locked`). server처럼 잠긴 내용(용신 판정 문장
  `yongsin.basis`, 원국 개인 해석 `personalReadings`)을 담지 않습니다(D60).
* `evidence-unlocked`: 권한 있음. 용신 판정 문장과 근거(엔진 `evidence`의 `ruleId`·`sourceRef`)와
  원국 개인 해석을 담습니다.
* `member-time-unknown`: 태어난 시간을 모르는 같은 사람. 시주가 없고 안내 `time_unknown`이 있습니다(잠김).
* `reward-unlock`: 보상형 광고로 잠금을 푸는 흐름. 첫 응답은 `member`(잠김), 두 번째부터는
  `evidence-unlocked`(열림)인 `sequence`입니다(오늘 `getDaily`와 같은 방식).

엔진 값이 아닌 것
* 문장(`yongsin.basis.text`, 근거의 `basis`, 개인 해석 `text`, 안내 `text`)은 writing 슬롯 형식을 따른
  대역 문장입니다. 개인 해석은 항목 종류마다 같은 틀에 용어 이름을 넣습니다.

core/에서 실행합니다(엔진 가상환경을 씁니다).
    uv run python ../app/tool/gen_chart_fixtures.py ../app/fixtures
"""

from __future__ import annotations

import json
import sys
from datetime import date, time
from pathlib import Path

from myungli_engine.calendar_core.birth import BirthInput
from myungli_engine.composers.chart import compose_chart
from myungli_engine.domain.enums import CalendarType, Gender

SEOUL = "Asia/Seoul"
AS_OF = date(2026, 10, 13)
RULESET = "2026.10.1"

ELEMENT = {"WOOD": "wood", "FIRE": "fire", "EARTH": "earth", "METAL": "metal", "WATER": "water"}

# 용신 산출 방법 문장(writing `chart.yongsin_method` 예시와 같은 틀).
METHOD_TEXT = {
    "johu": "태어난 계절의 온도를 맞추는 오행으로 ",
    "johu_neutral": "계절의 온도가 고른 편이라 기운의 균형을 보고 ",
    "eokbu": "넘치는 기운은 덜고 모자란 기운을 채우는 쪽으로 ",
}

# 개인 해석 대역 문장의 용어(종류별 용어 id 범주).
PERSONAL_PREFIX = {
    "day_master": "일간",
    "ten_god": "십성",
    "hidden_ten_god": "지장간",
    "twelve_stage": "12운성",
    "shinsal": "신살",
    "daeun_stem_ten_god": "대운 천간",
    "daeun_branch_ten_god": "대운 지지",
    "daeun_twelve_stage": "대운 12운성",
    "seun_ten_god": "세운",
}


def lower(member) -> str:
    return member.name.lower()


def pillar(p) -> dict:
    return {"stem": lower(p.stem), "branch": lower(p.branch)}


def rendered(*segments) -> dict:
    return {"segments": list(segments)}


def build(birth: BirthInput, *, unlocked: bool) -> dict:
    view = compose_chart(birth, AS_OF)
    chart = view.chart
    pillars = {
        "year": pillar(chart.pillars.year),
        "month": pillar(chart.pillars.month),
        "day": pillar(chart.pillars.day),
    }
    if chart.pillars.hour is not None:
        pillars["hour"] = pillar(chart.pillars.hour)
    yongsin = view.yongsin
    method = lower(yongsin.method)
    body: dict = {
        "rulesetVersion": RULESET,
        "evidenceAccess": "unlocked" if unlocked else "locked",
        "pillars": pillars,
        "tenGods": [
            {"position": lower(pos), "tenGod": lower(god)} for pos, god in chart.ten_gods.items()
        ],
        "hiddenStems": [
            {
                "position": lower(pos),
                "stems": [{"stem": lower(stem), "tenGod": lower(god)} for stem, god in stems],
            }
            for pos, stems in chart.hidden_stems.items()
        ],
        "twelveStages": [
            {"position": lower(pos), "stage": lower(stage)} for pos, stage in chart.twelve_stages.items()
        ],
        "shinsal": [{"kind": lower(hit.kind), "position": lower(hit.position)} for hit in chart.shinsal],
        "gongmang": sorted(lower(b) for b in chart.gongmang),
        "elementWeights": [
            {"element": ELEMENT[e.name], "weight": round(w, 2)}
            for e, w in view.strength.element_weights.items()
        ],
        "strength": {"score": round(view.strength.score, 2), "level": lower(view.strength.level)},
        "yongsin": {
            "yongsin": ELEMENT[yongsin.yongsin.name],
            "huisin": ELEMENT[yongsin.huisin.name],
            "gisin": ELEMENT[yongsin.gisin.name],
            "tonggwan": ELEMENT[yongsin.tonggwan.name],
            "method": method,
        },
        "daeun": {
            "forward": view.luck.forward,
            "startYears": view.luck.start_years,
            "startMonths": view.luck.start_months,
            "periods": [
                {
                    "pillar": pillar(period.pillar),
                    "startAge": period.start_age,
                    "startAgeKorean": period.start_age_korean,
                    "stemTenGod": lower(period.stem_ten_god),
                    "branchTenGod": lower(period.branch_ten_god),
                    "twelveStage": lower(period.twelve_stage),
                }
                for period in view.luck.periods
            ],
        },
        "seun": [
            {
                "year": year.year,
                "pillar": pillar(year.pillar),
                "tenGod": lower(year.ten_god),
                "relationsWithNatal": [r.lower() for r in year.relations_with_natal],
            }
            for year in view.luck.years
        ],
        "notices": [
            {
                "code": lower(notice.code) if hasattr(notice, "code") else lower(notice),
                "text": rendered({"text": "태어난 시간을 몰라 시주는 빼고 계산했어요."}),
            }
            for notice in view.notices
        ],
    }
    if yongsin.johu_stem is not None:
        body["yongsin"]["johuStem"] = lower(yongsin.johu_stem)
    if unlocked:
        body["yongsin"]["basis"] = {
            "slot": "chart.yongsin_method",
            "messageKey": view.yongsin_judgment.message_key,
            "variant": "single",
            "text": rendered(
                {"text": METHOD_TEXT[method]},
                {"text": "용신", "term": "role.yongsin"},
                {"text": "을 정했어요."},
            ),
            "reactable": False,
            "evidence": [
                {
                    "ruleId": evidence.rule_id,
                    "sourceRef": evidence.source_ref,
                    "basis": rendered({"text": "태어난 달의 기운과 오행 비중을 견주어 정했어요."}),
                }
                for evidence in view.yongsin_judgment.evidence
            ],
        }
        body["personalReadings"] = [personal(reading) for reading in view.personal_readings]
    return body


def personal(reading) -> dict:
    kind = lower(reading.kind)
    item: dict = {
        "kind": kind,
        "text": rendered(
            {"text": f"내 사주에서 이 {PERSONAL_PREFIX[kind]} 자리는 "},
            {"text": "기운의 균형", "term": "role.yongsin"},
            {"text": "을 돕는 쪽으로 읽어요."},
        ),
    }
    if reading.position is not None:
        item["position"] = lower(reading.position)
    if reading.index is not None:
        item["index"] = reading.index
    if reading.shinsal is not None:
        item["shinsal"] = lower(reading.shinsal)
    return item


def response(body: dict) -> dict:
    return {"status": 200, "headers": {"Content-Type": "application/json"}, "body": body}


def write(path: Path, fixture: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(fixture, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def main(out: Path) -> None:
    known = BirthInput(CalendarType.SOLAR, False, date(1990, 5, 15), time(14, 30), Gender.FEMALE, SEOUL, None)
    unknown = BirthInput(CalendarType.SOLAR, False, date(1990, 5, 15), None, Gender.FEMALE, SEOUL, None)
    locked = build(known, unlocked=False)
    unlocked = build(known, unlocked=True)
    write(out / "member" / "getChart.json", response(locked))
    write(out / "evidence-unlocked" / "getChart.json", response(unlocked))
    write(out / "member-time-unknown" / "getChart.json", response(build(unknown, unlocked=False)))
    write(out / "reward-unlock" / "getChart.json", {"sequence": [response(locked), response(unlocked)]})


if __name__ == "__main__":
    main(Path(sys.argv[1]))
