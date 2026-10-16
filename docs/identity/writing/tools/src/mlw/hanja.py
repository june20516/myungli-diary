"""용어 한자 표기 원고(#226): 용어 id → 한자. 언어와 상관없이 한 벌이라 `content/<lang>/` 밖 `content/hanja.yaml`에 둡니다.

server가 시드 변환으로 읽어 `Glossary.hanja`(용어 id → 한자)를 채웁니다. 한자가 없는 용어(날의 성격 등)는 적지 않습니다.
"""

from collections.abc import Sequence
from dataclasses import dataclass
from pathlib import Path

import regex
import yaml

from mlw.model import Finding, LoadError
from mlw.yamlio import load_with_lines

# 원고 디렉터리(`content/`) 바로 아래 파일 이름입니다.
HANJA_FILE_NAME = "hanja.yaml"
RULE_HANJA_LOAD = "load.hanja"
RULE_HANJA_UNKNOWN = "hanja.unknown_term"
RULE_HANJA_DUPLICATE = "hanja.duplicate"
RULE_HANJA_NOT_HAN = "hanja.not_han"

HAN_ONLY = regex.compile(r"\p{Han}+")


@dataclass(frozen=True)
class HanjaEntry:
    term: str
    hanja: str
    file: Path
    line: int


def load_hanja(path: Path) -> list[HanjaEntry]:
    """`{term, hanja}` 목록을 읽습니다. 파일이 없으면 빈 목록이고, 형식이 틀리면 모아서 `LoadError`를 던집니다."""
    if not path.is_file():
        return []
    try:
        items = load_with_lines(path)
    except (yaml.YAMLError, OSError) as error:
        raise LoadError(
            [Finding(path, 1, RULE_HANJA_LOAD, "error", f"YAML을 읽을 수 없습니다: {error}")]
        ) from error
    entries: list[HanjaEntry] = []
    findings: list[Finding] = []
    for data, line in items:
        term, hanja = data.get("term"), data.get("hanja")
        if not isinstance(term, str) or not isinstance(hanja, str) or set(data) != {"term", "hanja"}:
            message = "항목은 문자열 필드 term·hanja만 가진 매핑이어야 합니다"
            findings.append(Finding(path, line, RULE_HANJA_LOAD, "error", message))
            continue
        entries.append(HanjaEntry(term, hanja, path, line))
    if findings:
        raise LoadError(findings)
    return entries


def check_hanja(entries: Sequence[HanjaEntry], term_ids: Sequence[str]) -> list[Finding]:
    """용어 id가 있는지, 한 번만 나오는지, 값이 한자로만 되어 있는지 봅니다."""
    known = set(term_ids)
    seen: set[str] = set()
    findings: list[Finding] = []
    for entry in entries:
        if entry.term not in known:
            message = f"용어 id '{entry.term}'이(가) 없습니다"
            findings.append(Finding(entry.file, entry.line, RULE_HANJA_UNKNOWN, "error", message))
        elif entry.term in seen:
            message = f"용어 id '{entry.term}'의 한자가 두 번 나옵니다"
            findings.append(Finding(entry.file, entry.line, RULE_HANJA_DUPLICATE, "error", message))
        elif HAN_ONLY.fullmatch(entry.hanja) is None:
            message = f"용어 id '{entry.term}'의 한자 '{entry.hanja}'에 한자가 아닌 글자가 있습니다"
            findings.append(Finding(entry.file, entry.line, RULE_HANJA_NOT_HAN, "error", message))
        seen.add(entry.term)
    return findings
