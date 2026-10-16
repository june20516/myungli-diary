"""경도 보정 기준(`timeBasisOf`)의 엔진 대조 fixture를 만듭니다.

core 엔진(Python zoneinfo tzdata)으로 대표 입력의 기준 경도·보정 분·서머타임 분을 계산해
`test/features/calc_basis/model/engine_time_basis_cases.json`에 씁니다. 엔진 함수는
`resolve_birth_moment`와 같은 순서로 부릅니다.
    `_local_to_utc`(겹친 시각은 앞, 없는 시각은 뒤로 밂) → `standard_offset_hours`
    → `representative_longitude`, 서머타임 분은 그 시점의 zoneinfo `dst()`입니다.

core/에서 실행합니다(엔진 가상환경을 씁니다).
    uv run python ../app/tool/gen_time_basis_cases.py ../app/test/features/calc_basis/model/engine_time_basis_cases.json

`timezone` 패키지 데이터에 LMT 구간이 없는 1920년 이전 일부 시간대(서울 1908-04 이전 등)는
엔진과 달라 넣지 않습니다.
"""

from __future__ import annotations

import json
import sys
from datetime import datetime

from myungli_engine.calendar_core.birth import _local_to_utc
from myungli_engine.calendar_core.time_basis import load_zone, standard_offset_hours
from myungli_engine.constants.longitudes import representative_longitude

# 시각 모름은 엔진 `UNKNOWN_TIME_FALLBACK`과 같이 12:00으로 봅니다.
UNKNOWN_TIME_FALLBACK = (12, 0)

# (시간대, 양력 날짜, 시각 또는 None(모름), 무엇을 보는지)
CASES: list[tuple[str, str, str | None, str]] = [
    # 서울: 표준 오프셋 +8:30·+9 구간과 서머타임
    ("Asia/Seoul", "1910-06-01", "12:00", "1908~1911 +8:30"),
    ("Asia/Seoul", "1930-01-01", None, "1912~1954 +9"),
    ("Asia/Seoul", "1948-07-01", "08:00", "1948 서머타임(+9 표준)"),
    ("Asia/Seoul", "1950-07-01", "08:00", "1950 서머타임"),
    ("Asia/Seoul", "1951-07-01", None, "1951 서머타임, 시각 모름"),
    ("Asia/Seoul", "1954-03-20", "23:45", "+9 → +8:30 겹친 시각(앞)"),
    ("Asia/Seoul", "1954-03-20", None, "전환 전날 시각 모름"),
    ("Asia/Seoul", "1954-03-21", None, "전환 당일 시각 모름"),
    ("Asia/Seoul", "1955-06-15", "08:00", "1955 서머타임(+8:30 표준)"),
    ("Asia/Seoul", "1956-07-01", "12:00", "1956 서머타임"),
    ("Asia/Seoul", "1957-08-01", "06:30", "1957 서머타임"),
    ("Asia/Seoul", "1959-12-01", None, "+8:30 겨울"),
    ("Asia/Seoul", "1960-07-01", "08:00", "1960 서머타임"),
    ("Asia/Seoul", "1961-08-09", "23:45", "+8:30 마지막 시각"),
    ("Asia/Seoul", "1961-08-10", "00:15", "+8:30 → +9 없는 시각(뒤로)"),
    ("Asia/Seoul", "1961-08-10", None, "+9 복귀 당일 시각 모름"),
    ("Asia/Seoul", "1987-05-10", "02:30", "1987 서머타임 시작 없는 시각"),
    ("Asia/Seoul", "1987-07-15", "08:00", "1987 서머타임"),
    ("Asia/Seoul", "1987-10-11", "02:30", "1987 서머타임 끝 겹친 시각(앞)"),
    ("Asia/Seoul", "1988-07-01", None, "1988 서머타임, 시각 모름"),
    ("Asia/Seoul", "1990-05-05", "08:00", "서머타임 없는 현재 규칙"),
    ("Asia/Seoul", "2024-12-31", "23:59", "최근"),
    # 도쿄
    ("Asia/Tokyo", "1949-07-01", "08:00", "도쿄 1949 서머타임"),
    ("Asia/Tokyo", "1990-05-05", "08:00", "도쿄 표준"),
    ("Asia/Tokyo", "2020-02-29", None, "도쿄 시각 모름"),
    # 뉴욕
    ("America/New_York", "1943-06-01", "12:00", "뉴욕 전시 시간(War Time)"),
    ("America/New_York", "1990-01-01", "08:00", "뉴욕 겨울"),
    ("America/New_York", "1990-07-01", "08:00", "뉴욕 서머타임"),
    ("America/New_York", "2007-03-11", "02:30", "뉴욕 없는 시각"),
    ("America/New_York", "2007-11-04", "01:30", "뉴욕 겹친 시각(앞)"),
    ("America/Los_Angeles", "1990-07-01", None, "LA 서머타임, 시각 모름"),
    # 런던·베를린: 이중 서머타임과 연중 BST
    ("Europe/London", "1941-01-15", "12:00", "런던 전시 연중 BST"),
    ("Europe/London", "1941-07-01", "12:00", "런던 이중 서머타임(BDST)"),
    ("Europe/London", "1947-06-01", "12:00", "런던 1947 BDST"),
    ("Europe/London", "1969-01-15", "12:00", "런던 British Standard Time"),
    ("Europe/London", "1990-07-01", "08:00", "런던 서머타임"),
    ("Europe/London", "2020-03-29", "01:30", "런던 없는 시각"),
    ("Europe/Berlin", "1945-06-01", "12:00", "베를린 이중 서머타임"),
    ("Europe/Berlin", "1990-01-01", "08:00", "베를린 겨울"),
    # 남반구·30분 단위
    ("Australia/Sydney", "1990-01-01", "12:00", "시드니 서머타임"),
    ("Australia/Lord_Howe", "1990-01-01", "12:00", "로드하우 30분 서머타임"),
    ("Pacific/Auckland", "1990-01-01", None, "오클랜드 서머타임, 시각 모름"),
    ("America/St_Johns", "1990-07-01", "08:00", "세인트존스 −3:30 서머타임"),
    ("Asia/Kolkata", "1990-05-05", "08:00", "인도 +5:30"),
    ("Asia/Kathmandu", "1985-05-05", "08:00", "카트만두 +5:30(1986 전)"),
    ("Asia/Kathmandu", "2000-05-05", "08:00", "카트만두 +5:45"),
]


def build_case(timezone: str, date: str, time: str | None, note: str) -> dict[str, object]:
    zone = load_zone(timezone)
    year, month, day = (int(part) for part in date.split("-"))
    if time is None:
        hour, minute = UNKNOWN_TIME_FALLBACK
    else:
        hour, minute = (int(part) for part in time.split(":"))
    utc, _notices = _local_to_utc(datetime(year, month, day, hour, minute), zone)
    standard_offset = standard_offset_hours(utc, zone)
    longitude = representative_longitude(timezone, standard_offset)
    dst = utc.astimezone(zone).dst()
    dst_minutes = 0 if dst is None else int(dst.total_seconds() // 60)
    return {
        "note": note,
        "timezone": timezone,
        "date": date,
        "time": time,
        "longitude": longitude,
        "correctionMinutes": round((longitude - standard_offset * 15) * 4),
        "daylightSavingMinutes": dst_minutes,
    }


def main() -> None:
    output = sys.argv[1]
    cases = [build_case(*case) for case in CASES]
    with open(output, "w", encoding="utf-8") as file:
        json.dump(cases, file, ensure_ascii=False, indent=2)
        file.write("\n")
    print(f"{len(cases)}건을 {output}에 썼습니다.")


if __name__ == "__main__":
    main()
