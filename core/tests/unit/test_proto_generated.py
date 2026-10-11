# proto 생성 코드가 최신이고, 패키지 경로로 import되며, 도메인 enum을 빠짐없이 담는지 검사
import filecmp
import importlib
import os
import subprocess
import sys
from enum import Enum
from pathlib import Path

import pytest

from myungri_engine.chart.positions import Position
from myungri_engine.domain import enums
from myungri_engine.rules.color import ElementRole
from myungri_engine.rules.relations import RelationKind

CORE_DIR = Path(__file__).resolve().parents[2]
GEN_DIR = CORE_DIR / "src" / "myungri_engine" / "_gen"
GEN_SCRIPT = CORE_DIR / "tools" / "gen_proto.sh"
GEN_PACKAGE = "myungri_engine._gen.myungri.engine.v1"

# (도메인 enum, proto enum 이름). proto 값 이름은 <PROTO_ENUM_UPPER_SNAKE>_<도메인 멤버 이름>이다.
DOMAIN_TO_PROTO_ENUMS: tuple[tuple[type[Enum], str, str], ...] = (
    (enums.Element, "Element", "ELEMENT"),
    (enums.Stem, "Stem", "STEM"),
    (enums.Branch, "Branch", "BRANCH"),
    (enums.TenGod, "TenGod", "TEN_GOD"),
    (enums.Gender, "Gender", "GENDER"),
    (enums.CalendarType, "CalendarType", "CALENDAR_TYPE"),
    (enums.Direction8, "Direction8", "DIRECTION8"),
    (enums.DayKind, "DayKind", "DAY_KIND"),
    (enums.StrengthLevel, "StrengthLevel", "STRENGTH_LEVEL"),
    (enums.YongsinMethod, "YongsinMethod", "YONGSIN_METHOD"),
    (enums.LuckLevel, "LuckLevel", "LUCK_LEVEL"),
    (enums.NoticeCode, "NoticeCode", "NOTICE_CODE"),
    (enums.Shinsal, "Shinsal", "SHINSAL"),
    (enums.TwelveStage, "TwelveStage", "TWELVE_STAGE"),
    (Position, "Position", "POSITION"),
    (RelationKind, "RelationKind", "RELATION_KIND"),
    (ElementRole, "ElementRole", "ELEMENT_ROLE"),
    (enums.SolarTermKind, "SolarTermKind", "SOLAR_TERM_KIND"),
    (enums.PersonalTermKind, "PersonalTermKind", "PERSONAL_TERM_KIND"),
)


def _relative_files(root: Path) -> list[Path]:
    return sorted(
        path.relative_to(root)
        for path in root.rglob("*")
        if path.is_file() and "__pycache__" not in path.parts
    )


def test_generated_code_up_to_date(tmp_path: Path) -> None:
    out_dir = tmp_path / "_gen"
    # 테스트 중 uv run을 다시 부르지 않도록 지금 Python을 넘긴다
    env = {**os.environ, "PYTHON": sys.executable}
    subprocess.run(["bash", str(GEN_SCRIPT), str(out_dir)], cwd=CORE_DIR, env=env, check=True)

    expected_files = _relative_files(out_dir)
    assert expected_files, "생성 스크립트가 아무 파일도 만들지 않았습니다"
    assert _relative_files(GEN_DIR) == expected_files
    _, mismatched, errors = filecmp.cmpfiles(
        out_dir, GEN_DIR, [str(p) for p in expected_files], shallow=False
    )
    assert mismatched == [], "커밋된 _gen이 proto와 다릅니다. bash tools/gen_proto.sh 를 실행하세요"
    assert errors == []


def test_generated_modules_import_by_package_path() -> None:
    pb2 = importlib.import_module(f"{GEN_PACKAGE}.engine_pb2")
    pb2_grpc = importlib.import_module(f"{GEN_PACKAGE}.engine_pb2_grpc")

    service = pb2.DESCRIPTOR.services_by_name["MyungriEngine"]
    assert [method.name for method in service.methods] == ["GetChart", "GetDaily", "GetMonthCalendar", "GetBirthHour"]
    assert hasattr(pb2_grpc, "MyungriEngineServicer")
    assert hasattr(pb2_grpc, "add_MyungriEngineServicer_to_server")


@pytest.mark.parametrize(("domain_enum", "proto_name", "prefix"), DOMAIN_TO_PROTO_ENUMS)
def test_proto_enums_cover_domain_enums(domain_enum: type[Enum], proto_name: str, prefix: str) -> None:
    pb2 = importlib.import_module(f"{GEN_PACKAGE}.engine_pb2")
    proto_values = [value.name for value in pb2.DESCRIPTOR.enum_types_by_name[proto_name].values]

    expected = [f"{prefix}_UNSPECIFIED"] + [f"{prefix}_{member.name}" for member in domain_enum]
    assert proto_values == expected


def test_month_day_carries_luck_judgment() -> None:
    pb2 = importlib.import_module(f"{GEN_PACKAGE}.engine_pb2")
    judgment_field = pb2.MonthDay.DESCRIPTOR.fields_by_name["judgment"]

    assert judgment_field.number == 12
    assert judgment_field.message_type.full_name == "myungri.engine.v1.Judgment"


def test_solar_term_carries_kind_with_new_field_number() -> None:
    pb2 = importlib.import_module(f"{GEN_PACKAGE}.engine_pb2")
    fields = pb2.SolarTerm.DESCRIPTOR.fields_by_name

    assert (fields["name"].number, fields["at"].number) == (1, 2)
    assert fields["kind"].number == 3
    assert fields["kind"].enum_type.full_name == "myungri.engine.v1.SolarTermKind"


def test_enum_fields_use_unspecified_instead_of_optional() -> None:
    pb2 = importlib.import_module(f"{GEN_PACKAGE}.engine_pb2")
    enum_fields_with_presence = [
        f"{message.name}.{field.name}"
        for message in pb2.DESCRIPTOR.message_types_by_name.values()
        for field in message.fields
        if field.enum_type is not None and field.has_presence
    ]

    assert enum_fields_with_presence == []
