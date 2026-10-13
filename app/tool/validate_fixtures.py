"""대역 서버 fixture를 계약(openapi.yaml) 스키마로 검증합니다.

app/에서 실행합니다.
    uv run --with jsonschema --with pyyaml --with referencing python -I tool/validate_fixtures.py

각 `fixtures/<시나리오>/<operationId>[__<매개변수>].json`의 `body`를 그 operation의
`status`(없으면 `default`) 응답 스키마로 검증합니다. 실패하면 파일과 JSON Pointer를
출력하고 종료 코드 1입니다.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any

import yaml
from jsonschema import Draft202012Validator
from referencing import Registry, Resource
from referencing.jsonschema import DRAFT202012

APP_DIR = Path(__file__).resolve().parent.parent
FIXTURES_DIR = APP_DIR / "fixtures"
OPENAPI_PATH = APP_DIR.parent / "server" / "api" / "openapi.yaml"

# openapi.yaml 전체를 이 URI의 리소스로 등록해 `#/components/...` $ref를 풉니다.
SPEC_URI = "urn:myungli:openapi"
HTTP_METHODS = ("get", "put", "post", "delete", "options", "head", "patch", "trace")


class Contract:
    """openapi.yaml과 $ref 해석기를 묶은 검증 문맥."""

    def __init__(self, spec: dict[str, Any]) -> None:
        self.spec = spec
        resource = Resource.from_contents(spec, default_specification=DRAFT202012)
        self.registry = Registry().with_resource(SPEC_URI, resource)
        self.operations: dict[str, dict[str, Any]] = {}
        for item in spec["paths"].values():
            for method in HTTP_METHODS:
                operation = item.get(method)
                if operation:
                    self.operations[operation["operationId"]] = operation

    @classmethod
    def load(cls, path: Path = OPENAPI_PATH) -> "Contract":
        return cls(yaml.safe_load(path.read_text(encoding="utf-8")))

    def resolve_ref(self, node: dict[str, Any]) -> dict[str, Any]:
        """`{"$ref": "#/components/responses/X"}`처럼 객체 하나를 가리키는 참조를 풉니다."""
        while "$ref" in node:
            resolver = self.registry.resolver(SPEC_URI)
            node = resolver.lookup(node["$ref"]).contents
        return node


def default_content_type(status: int) -> str:
    return "application/problem+json" if status >= 400 else "application/json"


def _pointer(path: list[Any]) -> str:
    return "".join(
        "/" + str(part).replace("~", "~0").replace("/", "~1") for part in path
    )


def validate_fixture(
    contract: Contract, operation_id: str, fixture: Any
) -> list[str]:
    """fixture 하나를 검증하고 오류 문구 목록을 돌려줍니다(없으면 빈 목록)."""
    operation = contract.operations.get(operation_id)
    if operation is None:
        return [f"계약에 없는 operationId: {operation_id}"]
    if not isinstance(fixture, dict) or not isinstance(fixture.get("status"), int):
        return ["fixture는 정수 status가 있는 객체여야 합니다"]

    status = fixture["status"]
    responses = operation["responses"]
    key = str(status) if str(status) in responses else "default"
    if key not in responses:
        return [f"{operation_id}에 status {status}도 default도 없습니다"]
    response = contract.resolve_ref(responses[key])

    headers = {k.lower(): v for k, v in (fixture.get("headers") or {}).items()}
    media_type = (
        headers.get("content-type", default_content_type(status))
        .split(";")[0]
        .strip()
        .lower()
    )
    content = response.get("content") or {}
    if "body" not in fixture or fixture["body"] is None:
        if content:
            return [f"/body: 본문이 필요합니다 ({media_type})"]
        return []
    if media_type not in content:
        return [
            f"/headers/content-type: {operation_id} {key} 응답에 "
            f"{media_type} 본문이 없습니다 (있는 것: {', '.join(content) or '없음'})"
        ]

    schema = content[media_type].get("schema", {})
    validator = Draft202012Validator(
        _absolute_refs(schema),
        registry=contract.registry,
        format_checker=Draft202012Validator.FORMAT_CHECKER,
    )
    errors = sorted(
        validator.iter_errors(fixture["body"]), key=lambda e: list(e.absolute_path)
    )
    return [
        f"{_pointer(['body', *error.absolute_path])}: {error.message}"
        for error in errors
    ]


def _absolute_refs(node: Any) -> Any:
    """응답 안에 직접 적힌 스키마의 `#/...` $ref를 openapi 리소스 기준으로 바꿉니다."""
    if isinstance(node, dict):
        return {
            key: (
                SPEC_URI + value
                if key == "$ref" and isinstance(value, str) and value.startswith("#")
                else _absolute_refs(value)
            )
            for key, value in node.items()
        }
    if isinstance(node, list):
        return [_absolute_refs(item) for item in node]
    return node


def operation_id_of(file: Path) -> str:
    """`getDaily__2026-10-13.json` → `getDaily`."""
    return file.stem.split("__", 1)[0]


def validate_all(contract: Contract, fixtures_dir: Path = FIXTURES_DIR) -> tuple[int, list[str]]:
    """`<시나리오>/*.json`을 모두 검증합니다. (파일 수, 오류 목록)을 돌려줍니다."""
    count = 0
    failures: list[str] = []
    for file in sorted(fixtures_dir.glob("*/*.json")):
        count += 1
        relative = file.relative_to(fixtures_dir.parent)
        try:
            fixture = json.loads(file.read_text(encoding="utf-8"))
        except json.JSONDecodeError as error:
            failures.append(f"{relative}: JSON 문법 오류: {error}")
            continue
        for message in validate_fixture(contract, operation_id_of(file), fixture):
            failures.append(f"{relative}: {message}")
    return count, failures


def main() -> int:
    contract = Contract.load()
    count, failures = validate_all(contract)
    if failures:
        print("\n".join(failures), file=sys.stderr)
        print(f"fixtures 오류 {len(failures)}건", file=sys.stderr)
        return 1
    print(f"fixtures OK ({count}개)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
