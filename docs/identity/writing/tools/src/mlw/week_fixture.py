"""엔진 gRPC를 호출해 한 주 검사용 고정 자료를 만듭니다.

실행: python -m mlw.week_fixture --engine localhost:50051 > fixtures/week_samples.json
"""

import argparse
import json
import sys
from collections.abc import Sequence
from dataclasses import asdict, dataclass
from datetime import date, timedelta
from typing import Literal

import grpc

from mlw._gen.myungli.engine.v1 import engine_pb2, engine_pb2_grpc
from mlw.bundles import DayKeys

START_DATE = date(2026, 11, 2)
DAYS = 28
CURRENT_TIMEZONE = "Asia/Seoul"
BIRTH_TIMEZONE = "Asia/Seoul"


@dataclass(frozen=True)
class BirthSample:
    """고정 표본 한 명의 양력 출생 정보입니다. hour가 None이면 시간 모름입니다."""

    birth_id: str
    year: int
    month: int
    day: int
    hour: int | None
    minute: int
    gender: Literal["male", "female"]


SAMPLE_BIRTHS: tuple[BirthSample, ...] = (
    BirthSample("b01", 1970, 3, 14, 7, 30, "male"),
    BirthSample("b02", 1974, 11, 2, 22, 10, "female"),
    BirthSample("b03", 1978, 6, 21, 12, 0, "male"),
    BirthSample("b04", 1982, 1, 9, 3, 45, "female"),
    BirthSample("b05", 1986, 9, 30, 18, 20, "male"),
    BirthSample("b06", 1990, 4, 5, None, 0, "female"),
    BirthSample("b07", 1994, 12, 25, 9, 15, "male"),
    BirthSample("b08", 1997, 8, 17, 15, 50, "female"),
    BirthSample("b09", 2001, 2, 28, 0, 5, "male"),
    BirthSample("b10", 2005, 7, 7, 20, 35, "female"),
)


def day_keys_from_response(resp: engine_pb2.DailyResponse) -> DayKeys:
    """DailyResponse에서 화면에 나오는 메시지 키만 뽑습니다."""
    fortune = resp.fortune
    return DayKeys(
        head=fortune[0].message_key,
        tag_sentence=fortune[1].message_key if len(fortune) > 1 else None,
        guide=resp.guide.message_key,
        color=resp.color.judgment.message_key,
        direction=resp.direction.judgment.message_key,
        number=resp.number.judgment.message_key,
        focus=resp.focus_time.judgment.message_key,
        tag_label=resp.featured_tags[0] if resp.featured_tags else None,
    )


def _birth_info(sample: BirthSample) -> engine_pb2.BirthInfo:
    birth = engine_pb2.BirthInfo(
        calendar=engine_pb2.CALENDAR_TYPE_SOLAR,
        date=engine_pb2.LocalDate(year=sample.year, month=sample.month, day=sample.day),
        gender=engine_pb2.GENDER_MALE if sample.gender == "male" else engine_pb2.GENDER_FEMALE,
        timezone=BIRTH_TIMEZONE,
    )
    if sample.hour is not None:
        birth.time.CopyFrom(engine_pb2.LocalTime(hour=sample.hour, minute=sample.minute))
    return birth


def _request(sample: BirthSample, day: date) -> engine_pb2.DailyRequest:
    return engine_pb2.DailyRequest(
        birth=_birth_info(sample),
        date=engine_pb2.LocalDate(year=day.year, month=day.month, day=day.day),
        current_timezone=CURRENT_TIMEZONE,
    )


def _single_version(versions: Sequence[str], name: str) -> str:
    distinct = set(versions)
    if len(distinct) != 1:
        raise RuntimeError(f"{name}이 하나로 정해지지 않습니다: {sorted(distinct)}")
    return distinct.pop()


def generate(address: str) -> dict[str, object]:
    """표본 전원의 28일치 하루 결과를 엔진에서 받아 고정 자료 형태로 만듭니다."""
    engine_versions: list[str] = []
    ruleset_versions: list[str] = []
    samples: list[dict[str, object]] = []
    with grpc.insecure_channel(address) as channel:
        stub = engine_pb2_grpc.MyungliEngineStub(channel)
        for sample in SAMPLE_BIRTHS:
            days: list[dict[str, str | None]] = []
            for offset in range(DAYS):
                resp = stub.GetDaily(_request(sample, START_DATE + timedelta(days=offset)))
                engine_versions.append(resp.meta.engine_version)
                ruleset_versions.append(resp.meta.ruleset_version)
                days.append(asdict(day_keys_from_response(resp)))
            samples.append({"birth_id": sample.birth_id, "days": days})
    return {
        "engine_version": _single_version(engine_versions, "engine_version"),
        "ruleset_version": _single_version(ruleset_versions, "ruleset_version"),
        "start": START_DATE.isoformat(),
        "samples": samples,
    }


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="엔진 gRPC로 한 주 표본 고정 자료를 만듭니다.")
    parser.add_argument("--engine", required=True, help="엔진 주소, 예: localhost:50051")
    args = parser.parse_args(argv)
    fixture = generate(args.engine)
    json.dump(fixture, sys.stdout, indent=2, ensure_ascii=False, sort_keys=False)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
