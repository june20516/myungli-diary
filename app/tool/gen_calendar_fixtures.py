"""member 시나리오의 달력 fixture(`fixtures/member/getCalendar__<연>-<월>.json`)를 만듭니다.

member 프로필(`fixtures/member/updateProfile.json`: 양력 1990-05-15 14:30, 여성, Asia/Seoul)로
core `compose_month`를 돌려 2026년 9~11월의 날마다 `pillar`·`lunar`(한국 음력, KASI)·`solarTerm`·
`dayKind`·`luckLevel`·`score`를 엔진 값 그대로 옮깁니다. 파일 이름의 월은
생성 클라이언트가 보내는 경로(`/v1/calendar/2026/9`)와 같게 0을 붙이지 않습니다.

엔진 값이 아닌 것
* 문장(`characterReason`, `level`)은 writing 슬롯 형식을 따른 대역 문장입니다.
* **2026-10-13(시나리오의 오늘)만 엔진 값이 아닙니다.** 오늘 화면 fixture(`member/getDaily.json`,
  `dayKind: yongsin_day`)와 같게 보이도록 `dayKind`를 `yongsin_day`로 바꾸고, 점수는 엔진 규칙
  (`rules/calendar_luck.py`)대로 다시 셉니다. 그날의 관계 항목(합 +1, 형 -1)은 엔진 값 그대로 두고
  용신일 +2를 앞에 더해 2점, good 기준(2 이상)이라 `luckLevel: good`, `level`은 `calendar.good`입니다.
  `characterReason`은 getDaily의 것과 같은 문장입니다. 일진(庚申)·음력은 엔진 값입니다.

core/에서 실행합니다(엔진 가상환경을 씁니다).
    uv run python ../app/tool/gen_calendar_fixtures.py ../app/fixtures/member
"""

from __future__ import annotations

import json
import sys
from datetime import date, time
from pathlib import Path

from myungli_engine.calendar_core.birth import BirthInput
from myungli_engine.composers.month import compose_month
from myungli_engine.domain.enums import CalendarType, DayKind, Gender
from myungli_engine.rules.calendar_luck import DAY_KIND_SCORES, GOOD_THRESHOLD

SEOUL = "Asia/Seoul"
BIRTH = BirthInput(CalendarType.SOLAR, False, date(1990, 5, 15), time(14, 30), Gender.FEMALE, SEOUL, None)
MONTHS = ((2026, 9), (2026, 10), (2026, 11))

# 오늘 화면 fixture와 맞추려고 dayKind를 바꾸는 날(위 설명 참고).
DAY_KIND_OVERRIDES = {date(2026, 10, 13): DayKind.YONGSIN_DAY}

REASON = {
    "gwiin_day": [
        {"text": "천을귀인", "term": "tag.cheoneul_gwiin"},
        {"text": "이 들어 도와주는 사람이 곁에 오는 날이에요."},
    ],
    # member/getDaily.json의 characterReason과 같은 문장입니다.
    "yongsin_day": [{"text": "내게 필요한 기운이 들어와 일이 잘 풀리기 쉬운 날이에요."}],
    "gisin_day": [{"text": "기운이 엇갈리기 쉬워 한 박자 쉬어 가면 좋은 날이에요."}],
    "ordinary_day": [{"text": "큰 기복 없이 평소 흐름대로 지내기 좋은 날이에요."}],
}
LEVEL = {"good": "잘 풀리는 날", "neutral": "무난한 날", "caution": "조심할 날"}
DAY_KIND_ITEM_IDS = {item_id for item_id, _ in DAY_KIND_SCORES.values()}


def _slot(slot_id: str, key: str, variant: str, segments: list[dict[str, str]]) -> dict[str, object]:
    return {"slot": slot_id, "messageKey": key, "variant": variant, "reactable": False, "text": {"segments": segments}}


def _luck(day) -> tuple[str, str, int]:
    """(dayKind, luckLevel, score). 바꾸는 날은 엔진 규칙으로 다시 셉니다."""
    kind = DAY_KIND_OVERRIDES.get(day.info.date)
    if kind is None:
        return day.kind.name.lower(), day.luck.level.name.lower(), day.luck.score
    relations = [item for item in day.luck.breakdown if item[0] not in DAY_KIND_ITEM_IDS]
    items = ([DAY_KIND_SCORES[kind]] if kind in DAY_KIND_SCORES else []) + relations
    score = sum(points for _, points in items)
    # 바꾸는 날은 오늘 화면(용신일)과 같은 good이어야 합니다.
    if score < GOOD_THRESHOLD:
        raise ValueError(f"{day.info.date}: 바꾼 날의 점수가 good이 아닙니다: {items}")
    return kind.name.lower(), "good", score


def _day_json(day) -> dict[str, object]:
    info = day.info
    kind, level, score = _luck(day)
    if info.date not in DAY_KIND_OVERRIDES:
        assert day.judgment.message_key == f"calendar.{level}", day.judgment.message_key
    out: dict[str, object] = {
        "date": info.date.isoformat(),
        "pillar": {"stem": info.pillar.stem.name.lower(), "branch": info.pillar.branch.name.lower()},
        "lunar": {"month": info.lunar_month, "day": info.lunar_day, "isLeapMonth": info.is_leap_month},
    }
    if info.solar_term is not None:
        out["solarTerm"] = {
            "kind": info.solar_term.kind.name.lower(),
            "at": info.solar_term.at.replace(microsecond=0).isoformat(),
        }
    out.update(
        {
            "dayKind": kind,
            "characterReason": _slot("character.reason", f"character.reason.{kind}", "1", REASON[kind]),
            "luckLevel": level,
            "score": score,
            "level": _slot("calendar.day_level", f"calendar.{level}", "single", [{"text": LEVEL[level]}]),
        }
    )
    return out


def main(out_dir: Path) -> None:
    for year, month in MONTHS:
        view = compose_month(BIRTH, year, month, SEOUL)
        body = {
            "year": year,
            "month": month,
            "rulesetVersion": "r1",
            "evidenceAccess": "locked",
            "days": [_day_json(day) for day in view.days],
        }
        path = out_dir / f"getCalendar__{year}-{month}.json"
        text = json.dumps({"status": 200, "body": body}, ensure_ascii=False, indent=2)
        path.write_text(text + "\n", encoding="utf-8")
        print(path)


if __name__ == "__main__":
    main(Path(sys.argv[1]))
