"""규칙·슬롯 YAML에서 사람이 읽는 Markdown을 만듭니다. YAML이 원본이고 문서는 생성물입니다."""

from collections.abc import Callable, Mapping
from pathlib import Path

from mlw.model import LANGS, PARAM_KIND_LIST_PREFIX, Detect, JosaPair, ParamKind, RuleSet, Slot

HEADER = "<!-- mlw gen-docs로 생성. 직접 고치지 않습니다 -->"
RULE_STALE = "docs.stale"
NONE_TEXT = "-"


def _cell(text: str) -> str:
    """표 칸에 넣을 수 있게 줄바꿈과 세로선을 처리합니다."""
    return " ".join(text.split()).replace("|", "\\|")


def _code(text: str) -> str:
    return f"`{_cell(text)}`"


def _detect_text(detect: Detect) -> str:
    if detect.kind == "lexicon":
        body = ", ".join(detect.words)
    else:
        body = detect.pattern or ""
    langs = f" ({', '.join(sorted(detect.langs))})" if detect.langs else ""
    return f"{detect.kind}: {_code(body)}{langs}"


def _table(header: tuple[str, ...], rows: list[tuple[str, ...]]) -> list[str]:
    lines = [f"| {' | '.join(header)} |", f"| {' | '.join('---' for _ in header)} |"]
    lines.extend(f"| {' | '.join(row)} |" for row in rows)
    return lines


def _document(title: str, intro: str, table: list[str]) -> str:
    return "\n".join([HEADER, "", f"# {title}", "", intro, "", *table, ""])


def _render_slop(rules: RuleSet) -> str:
    rows: list[tuple[str, ...]] = []
    for rule_id in sorted(rules.slop):
        rule = rules.slop[rule_id]
        if rule.detect is not None:
            detection = _detect_text(rule.detect)
        else:
            detection = _cell(rule.rubric or NONE_TEXT)
        exempt = ", ".join(sorted(rule.exempt_purposes)) or NONE_TEXT
        rows.append((rule.id, _cell(rule.name), rule.judge, rule.severity, exempt, detection))
    table = _table(("ID", "이름", "판정", "심각도", "예외 목적", "탐지식 또는 루브릭"), rows)
    return _document("slop 패턴", "원본은 `rules/slop.yaml`입니다. 판정이 `llm`인 규칙은 루브릭으로 사람이 봅니다.", table)


def _param_kind_text(kind: ParamKind) -> str:
    if kind.kind == "glossary":
        return ", ".join(kind.categories)
    if kind.kind == "list":
        return f"{PARAM_KIND_LIST_PREFIX}{kind.categories[0]}"
    return kind.kind


def _params_text(slot: Slot) -> str:
    """슬롯의 키들이 쓰는 매개변수와 값 종류를 처음 나온 순서로 모읍니다."""
    params: dict[str, ParamKind] = {}
    for key_params in slot.keys.values():
        for name, kind in key_params.items():
            params.setdefault(name, kind)
    return "<br>".join(f"`{name}`: {_param_kind_text(kind)}" for name, kind in params.items()) or NONE_TEXT


def _render_slots(slots: Mapping[str, Slot]) -> str:
    rows: list[tuple[str, ...]] = []
    for slot_id in sorted(slots):
        slot = slots[slot_id]
        limits = ", ".join(
            f"{lang} {slot.max_length[lang] if slot.max_length.get(lang) is not None else NONE_TEXT}"
            for lang in LANGS
        )
        rows.append(
            (
                slot.id,
                slot.purpose,
                ", ".join(slot.types) or NONE_TEXT,
                str(slot.variants),
                str(len(slot.keys)),
                _params_text(slot),
                limits,
            )
        )
    table = _table(("ID", "목적", "유형", "변주", "키 수", "매개변수: 값 종류", "글자 수 상한"), rows)
    description = (
        "원본은 `slots/`의 YAML입니다. 글자 수 상한의 `-`는 아직 정하지 않음입니다. "
        "값 종류는 범주 목록(첫째가 기본), `list:<범주>`, `number`, `none`이고 `name`은 어느 슬롯에서나 씁니다."
    )
    return _document("슬롯 목록", description, table)


def _pair_examples(pair: JosaPair, rules: RuleSet) -> str:
    shown = [f"{_cell(example.text)} → {_cell(example.expected)}" for example in rules.josa.examples]
    matching = [text for text, example in zip(shown, rules.josa.examples, strict=True) if pair.marker in example.text]
    return "<br>".join(matching) or NONE_TEXT


def _render_josa(rules: RuleSet) -> str:
    rows: list[tuple[str, ...]] = [
        (
            _code(pair.marker),
            pair.with_batchim,
            pair.without_batchim,
            pair.rieul if pair.rieul is not None else pair.with_batchim,
            _pair_examples(pair, rules),
        )
        for pair in rules.josa.pairs
    ]
    table = _table(("표기", "받침 있음", "받침 없음", "ㄹ 받침", "예시"), rows)
    return _document("조사 표", "원본은 `rules/josa.yaml`입니다. 예시는 `표기된 원고 → 렌더 결과`입니다.", table)


def render_docs(rules: RuleSet, slots: Mapping[str, Slot]) -> dict[str, str]:
    """파일 이름 -> 내용. 같은 입력이면 항상 같은 결과입니다."""
    renderers: dict[str, Callable[[], str]] = {
        "slop-patterns.md": lambda: _render_slop(rules),
        "slot-catalog.md": lambda: _render_slots(slots),
        "josa-table.md": lambda: _render_josa(rules),
    }
    return {name: render() for name, render in renderers.items()}


def write_docs(out_dir: Path, docs: Mapping[str, str]) -> None:
    out_dir.mkdir(parents=True, exist_ok=True)
    for name, content in docs.items():
        (out_dir / name).write_text(content, encoding="utf-8")


def stale_docs(out_dir: Path, docs: Mapping[str, str]) -> list[str]:
    """없거나 내용이 다른 파일 이름입니다."""
    stale: list[str] = []
    for name in sorted(docs):
        path = out_dir / name
        try:
            current = path.read_text(encoding="utf-8")
        except (OSError, UnicodeDecodeError):
            stale.append(name)
            continue
        if current != docs[name]:
            stale.append(name)
    return stale
