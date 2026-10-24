"""대역 서버 fixture를 계약(openapi.yaml) 스키마로 검증합니다.

app/에서 실행합니다(rfc3339-validator는 `date-time` format 검사에 필요합니다).
    uv run --with jsonschema --with pyyaml --with referencing --with rfc3339-validator python -I tool/validate_fixtures.py

각 `fixtures/<시나리오>/<operationId>[__<매개변수>].json`의 `body`를 그 operation의
`status`(없으면 `default`) 응답 스키마로 검증합니다. `{ "sequence": [응답, ...] }`
형식이면 각 응답을 같은 규칙으로 검증합니다. 실패하면 파일과 JSON Pointer를
출력하고 종료 코드 1입니다.

스키마에 없는 속성은 오류입니다. `properties`가 있고 `additionalProperties`를 적지 않은
객체 스키마는 `additionalProperties: false`로 보고 검증합니다(없어진 필드가 fixture에 남지
않게). 계약이 `additionalProperties`를 적은 스키마는 그 값을 그대로 따릅니다.
"""

from __future__ import annotations

import json
import re
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
        resource = Resource.from_contents(
            _close_objects(spec), default_specification=DRAFT202012
        )
        self.registry = Registry().with_resource(SPEC_URI, resource)
        self.operations: dict[str, dict[str, Any]] = {}
        # operationId -> 경로 템플릿 순서의 path 매개변수 스키마 목록
        self.path_parameters: dict[str, list[dict[str, Any]]] = {}
        for template, item in spec["paths"].items():
            declared = {}
            for parameter in item.get("parameters", []):
                parameter = self.resolve_ref(parameter)
                if parameter.get("in") == "path":
                    declared[parameter["name"]] = parameter.get("schema", {})
            names = re.findall(r"\{([^}]+)\}", template)
            for method in HTTP_METHODS:
                operation = item.get(method)
                if operation:
                    operation_id = operation["operationId"]
                    self.operations[operation_id] = operation
                    self.path_parameters[operation_id] = [
                        declared.get(name, {}) for name in names
                    ]

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
    if operation_id not in contract.operations:
        return [f"계약에 없는 operationId: {operation_id}"]
    if isinstance(fixture, dict) and "sequence" in fixture:
        sequence = fixture["sequence"]
        if set(fixture) != {"sequence"} or not isinstance(sequence, list) or not sequence:
            return ["/sequence: sequence는 비어 있지 않은 배열이어야 하고 다른 키와 함께 쓸 수 없습니다"]
        errors: list[str] = []
        for index, response in enumerate(sequence):
            errors += validate_response(
                contract, operation_id, response, f"/sequence/{index}"
            )
        return errors
    return validate_response(contract, operation_id, fixture, "")


def validate_response(
    contract: Contract, operation_id: str, fixture: Any, prefix: str
) -> list[str]:
    """`{status, headers?, body?}` 응답 하나를 검증합니다. [prefix]는 오류 위치 접두어입니다."""
    operation = contract.operations[operation_id]
    if not isinstance(fixture, dict) or not isinstance(fixture.get("status"), int):
        return [f"{prefix}: 응답은 정수 status가 있는 객체여야 합니다"]

    status = fixture["status"]
    responses = operation["responses"]
    key = str(status) if str(status) in responses else "default"
    if key not in responses:
        return [f"{prefix}: {operation_id}에 status {status}도 default도 없습니다"]
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
            return [f"{prefix}/body: 본문이 필요합니다 ({media_type})"]
        return []
    if media_type not in content:
        return [
            f"{prefix}/headers/content-type: {operation_id} {key} 응답에 "
            f"{media_type} 본문이 없습니다 (있는 것: {', '.join(content) or '없음'})"
        ]

    schema = content[media_type].get("schema", {})
    validator = Draft202012Validator(
        _absolute_refs(_close_objects(schema)),
        registry=contract.registry,
        format_checker=Draft202012Validator.FORMAT_CHECKER,
    )
    errors_sorted = sorted(
        validator.iter_errors(fixture["body"]), key=lambda e: list(e.absolute_path)
    )
    return [
        f"{_pointer([*prefix.split('/')[1:], 'body', *error.absolute_path])}: {error.message}"
        for error in errors_sorted
    ]


def check_file_name(contract: Contract, file: Path) -> list[str]:
    """`<operationId>__<값>-<값>.json`의 값이 path 매개변수 스키마와 맞는지 검사합니다.

    값 자체에 `-`가 있을 수 있어(예 날짜) `-` 조각을 매개변수 수만큼 이어 붙이는
    모든 방법 중 스키마를 모두 만족하는 것이 하나라도 있으면 통과합니다.
    """
    operation_id, separator, suffix = file.stem.partition("__")
    schemas = contract.path_parameters.get(operation_id)
    if schemas is None:
        return []  # 계약에 없는 operationId는 validate_fixture가 알립니다.
    if not separator:
        return []
    if not schemas:
        return [f"path 매개변수가 없는 {operation_id}에 `__{suffix}`가 붙었습니다"]
    pieces = suffix.split("-")

    def fits(schema: dict[str, Any], value: str) -> bool:
        instance: Any = value
        if schema.get("type") == "integer":
            if not re.fullmatch(r"-?\d+", value):
                return False
            instance = int(value)
        validator = Draft202012Validator(
            _absolute_refs(schema),
            registry=contract.registry,
            format_checker=Draft202012Validator.FORMAT_CHECKER,
        )
        return validator.is_valid(instance)

    def split(start: int, index: int) -> bool:
        if index == len(schemas):
            return start == len(pieces)
        for end in range(start + 1, len(pieces) + 1):
            if fits(schemas[index], "-".join(pieces[start:end])) and split(end, index + 1):
                return True
        return False

    if split(0, 0):
        return []
    return [
        f"파일 이름의 값 `{suffix}`이 {operation_id}의 path 매개변수 "
        f"{len(schemas)}개와 맞지 않습니다"
    ]


def _close_objects(node: Any) -> Any:
    """`additionalProperties`를 적지 않은 객체 스키마에 `false`를 더한 사본을 돌려줍니다.

    `properties`가 스키마 이름 → 스키마 사전인 노드만 객체 스키마로 봅니다.
    """
    if isinstance(node, list):
        return [_close_objects(item) for item in node]
    if not isinstance(node, dict):
        return node
    closed = {key: _close_objects(value) for key, value in node.items()}
    properties = node.get("properties")
    if (
        isinstance(properties, dict)
        and all(isinstance(value, dict) for value in properties.values())
        and "additionalProperties" not in node
        and "patternProperties" not in node
    ):
        closed["additionalProperties"] = False
    return closed


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
        for message in check_file_name(contract, file):
            failures.append(f"{relative}: {message}")
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
