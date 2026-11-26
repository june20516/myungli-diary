"""엔진 응답 표면 변경과 ENGINE_VERSION 연동 (spec 12, D147 ③).

응답 표면은 server와 writing이 읽는 모양이다: gRPC 메시지 정의, 메시지 키 목록, 메시지 키별 매개변수,
근거 규칙별 detail 키. 이것이 바뀌면 배포된 엔진끼리 버전 표기로 구별되도록 ENGINE_VERSION을 올린다.
기록 파일 tests/ENGINE_SURFACE_HASH는 `UPDATE_ENGINE_SURFACE_HASH=1 uv run pytest tests/unit/test_engine_version.py`로 갱신한다.
"""

import hashlib
import json
import os
from pathlib import Path

import pytest
from version_record import RecordRule, VersionRecord, verify_record

from myungli_engine._gen.myungli.engine.v1 import engine_pb2
from myungli_engine.version import ENGINE_VERSION

CORE_DIR = Path(__file__).parent.parent.parent
SURFACE_JSON_FILES = ("message_keys.json", "message_params.json", "evidence_rules.json")
RECORD_FILE = Path(__file__).parent.parent / "ENGINE_SURFACE_HASH"
UPDATE_ENV = "UPDATE_ENGINE_SURFACE_HASH"
RULE = RecordRule(
    file_name=RECORD_FILE.name,
    bump_message=(
        "엔진 응답 표면(proto, 메시지 키, 매개변수, 근거 detail 키)이 바뀌었으면 "
        "pyproject.toml의 version(ENGINE_VERSION)을 올리고 `uv lock`을 돌리세요."
    ),
    update_hint=f"기록 갱신: `{UPDATE_ENV}=1 uv run pytest tests/unit/test_engine_version.py`",
)


def surface_hash(descriptor: bytes, json_texts: dict[str, str]) -> str:
    """메시지 정의와 JSON 계약을 SHA-256에 먹인다.

    descriptor는 주석이 빠진 직렬화 정의라 proto 주석만 고친 변경은 해시를 바꾸지 않는다.
    JSON은 키 정렬과 공백을 맞춘 뒤 먹여 서식만 바뀐 변경도 해시를 바꾸지 않는다.
    """
    digest = hashlib.sha256()
    digest.update(descriptor)
    for name in sorted(json_texts):
        canonical = json.dumps(json.loads(json_texts[name]), ensure_ascii=False, sort_keys=True)
        digest.update(b"\0")
        digest.update(name.encode())
        digest.update(b"\0")
        digest.update(canonical.encode())
    return digest.hexdigest()


def current_surface_hash() -> str:
    texts = {name: (CORE_DIR / name).read_text() for name in SURFACE_JSON_FILES}
    return surface_hash(engine_pb2.DESCRIPTOR.serialized_pb, texts)


@pytest.mark.contract
def test_engine_surface_matches_recorded_engine_version() -> None:
    current = VersionRecord(version=ENGINE_VERSION, sha256=current_surface_hash())
    problem = verify_record(RECORD_FILE, current, RULE, update=os.environ.get(UPDATE_ENV) == "1")
    assert problem is None, problem


def test_hash_ignores_json_formatting() -> None:
    assert surface_hash(b"d", {"a.json": '{"x": 1, "y": [2]}'}) == surface_hash(
        b"d", {"a.json": '{\n  "y": [2],\n  "x": 1\n}\n'}
    )


@pytest.mark.parametrize(
    ("descriptor", "texts"),
    [
        (b"d2", {"a.json": '{"x": 1}'}),
        (b"d", {"a.json": '{"x": 2}'}),
        (b"d", {"b.json": '{"x": 1}'}),
        (b"d", {"a.json": '{"x": 1}', "b.json": "{}"}),
    ],
)
def test_hash_changes_with_surface(descriptor: bytes, texts: dict[str, str]) -> None:
    assert surface_hash(descriptor, texts) != surface_hash(b"d", {"a.json": '{"x": 1}'})
