"""fixture 도구가 함께 쓰는 writing 원고 읽기와 렌더(server `content` 규칙을 따름).

`gen_daily_fixtures.py`, `gen_chart_fixtures.py`, `gen_glossary_fixtures.py`가 씁니다. 원고는
`docs/identity/writing/content/ko/`(문장), `slots/content/`(매개변수 값 종류), `content/hanja.yaml`(한자 표기)입니다.
원고 파일은 한 줄 한 항목(`- {slot: …, key: …, text: "…"}`) 형식을 정규식으로 읽고, 읽은 것이 없으면 실패합니다
(형식이 바뀌어 조용히 빈 결과가 나오지 않게).

같은 디렉터리의 도구가 `import fixture_content`로 씁니다(스크립트 디렉터리가 import 경로에 듭니다).
"""

from __future__ import annotations

import json
import re
from pathlib import Path

# 이 도구 기준 저장소 경로(app/tool/ → 저장소 뿌리).
REPO = Path(__file__).resolve().parents[2]
CONTENT = REPO / "docs/identity/writing/content/ko"

SLOTS = REPO / "docs/identity/writing/slots/content"
HANJA = REPO / "docs/identity/writing/content/hanja.yaml"

# 조사 표지 → (받침 있을 때, 받침 없을 때). `(으)로`는 ㄹ 받침도 받침 없음과 같습니다.
JOSA = {
    "(이)에요": ("이에요", "예요"),
    "(이)가": ("이", "가"),
    "(을)를": ("을", "를"),
    "(은)는": ("은", "는"),
    "(와)과": ("과", "와"),
    "(으)로": ("으로", "로"),
}
# 숫자를 한국어로 읽었을 때의 받침(0 영, 1 일, 3 삼, 6 육, 7 칠, 8 팔).
DIGIT_FINAL = {"0": "ㅇ", "1": "ㄹ", "3": "ㅁ", "6": "ㄱ", "7": "ㄹ", "8": "ㄹ"}

PREVIEW_WORDS = 3

# 십성 → 묶음(`{ten_god:ten_god_group}` 렌더용). 엔진 `TenGod.group`과 같은 표입니다.
TEN_GOD_GROUP = {
    "BIGYEON": "bigyeop",
    "GEOPJAE": "bigyeop",
    "SIKSIN": "siksang",
    "SANGGWAN": "siksang",
    "PYEONJAE": "jaeseong",
    "JEONGJAE": "jaeseong",
    "PYEONGWAN": "gwanseong",
    "JEONGGWAN": "gwanseong",
    "PYEONIN": "inseong",
    "JEONGIN": "inseong",
}

# ---------- writing 원고 ----------

_FIELD = re.compile(r'(\w+): ("(?:[^"\\]|\\.)*"|[^,}]+)')


def _load_lines() -> dict[tuple[str, str, str], str]:
    """원고 줄 `{slot, key, (type|variant), text}` → (slot, key, 변주) → 문장. 변주가 없으면 single입니다."""
    out: dict[tuple[str, str, str], str] = {}
    for path in sorted(CONTENT.glob("*.yaml")):
        for line in path.read_text(encoding="utf-8").splitlines():
            if not line.startswith("- {"):
                continue
            fields = {name: value.strip() for name, value in _FIELD.findall(line)}
            if "slot" not in fields or "text" not in fields:
                continue
            unquote = lambda v: json.loads(v) if v.startswith('"') else v  # noqa: E731
            variant = unquote(fields.get("type") or fields.get("variant") or "single")
            out[(unquote(fields["slot"]), unquote(fields["key"]), str(variant))] = unquote(fields["text"])
    if not out:
        raise RuntimeError(f"원고를 읽지 못했습니다(형식이 바뀌었는지 확인): {CONTENT}")
    return out


LINES = _load_lines()

_PARAMS_LINE = re.compile(r"^\s*- params: \{(?P<body>.*)\}\s*$")
_PARAM_ENTRY = re.compile(r"(\w+): (\[[^\]]*\]|\w+)")


def _load_param_kinds() -> dict[str, dict[str, str | None]]:
    """슬롯 명세의 키 → 매개변수 → 기본 glossary 범주(값 종류 `text`, `number`, `none`이면 None)."""
    out: dict[str, dict[str, str | None]] = {}
    for path in sorted(SLOTS.glob("*.yaml")):
        lines = path.read_text(encoding="utf-8").splitlines()
        for index, text in enumerate(lines):
            match = _PARAMS_LINE.match(text)
            if match is None:
                continue
            kinds = {
                name: (kind.strip("[]").split(",")[0].strip() if kind.startswith("[") else None)
                for name, kind in _PARAM_ENTRY.findall(match["body"])
            }
            keys: list[str] = []
            following = lines[index + 1].strip()
            if following.startswith("keys: ["):
                keys = [k.strip().strip('"') for k in following[len("keys: [") : -1].split(",")]
            elif following == "keys:":
                for item in lines[index + 2 :]:
                    item = item.strip()
                    if not item.startswith("- ") or item.startswith("- params:"):
                        break
                    keys.append(item[2:].strip().strip('"'))
            for key in keys:
                out[key] = kinds
    if not out:
        raise RuntimeError(f"슬롯 명세의 params를 읽지 못했습니다(형식이 바뀌었는지 확인): {SLOTS}")
    return out


PARAM_KINDS = _load_param_kinds()


def line(slot: str, key: str, variant: str = "single") -> str | None:
    return LINES.get((slot, key, variant))


def value_name(category: str, key: str) -> str:
    name = line("glossary.value_name", f"{category}.{key}")
    if name is None:
        raise KeyError(f"glossary 값 이름이 없습니다: {category}.{key}")
    return name


# ---------- 렌더 ----------


def _has_final(word: str, *, rieul_as_open: bool = False) -> bool:
    last = word[-1]
    if last in DIGIT_FINAL or last.isdigit():
        final = DIGIT_FINAL.get(last)
        return final is not None and not (rieul_as_open and final == "ㄹ")
    code = ord(last) - 0xAC00
    if not 0 <= code <= 11171:
        return False
    jong = code % 28
    return jong != 0 and not (rieul_as_open and jong == 8)


def _apply_josa(text: str) -> str:
    for marker, (closed, opened) in JOSA.items():
        while marker in text:
            index = text.index(marker)
            before = text[:index]
            closed_word = _has_final(before, rieul_as_open=marker == "(으)로")
            text = before + (closed if closed_word else opened) + text[index + len(marker) :]
    return text


def _param(name: str, category: str | None, params: dict[str, str], kinds: dict[str, str | None]) -> tuple[str, str | None]:
    """(표시 글자, 용어 id). 범주가 없으면(값 종류 `text`, `number`) 값을 그대로 씁니다."""
    raw = str(params[name])
    if kinds.get(name) is None and category is None:
        return raw, None
    category = category or kinds[name]
    if category is None:
        return raw, None
    key = raw.lower()
    if category == "ten_god_group" and raw in TEN_GOD_GROUP:
        # 십성 값을 묶음 범주로 고르면 그 십성의 묶음 이름입니다(`{ten_god:ten_god_group}`).
        key = TEN_GOD_GROUP[raw]
    return value_name(category, key), f"{category}.{key}"


_TOKEN = re.compile(r"\[\[(?P<term_text>[^\]|]+)\|(?P<term>[^\]]+)\]\]|\[\[\{(?P<term_param>\w+)(?::(?P<term_cat>\w+))?\}\]\]|\{(?P<param>\w+)(?::(?P<cat>\w+))?\}")


def render(template: str, params: dict[str, str], key: str = "") -> list[dict]:
    """원고 틀을 조각 배열로 렌더합니다. `[[글자|용어]]`, `[[{p}]]`는 용어 조각, `{p}`, `{p:범주}`는 글자입니다."""
    kinds = PARAM_KINDS.get(key, {})
    segments: list[dict] = []
    buffer = ""
    position = 0
    for match in _TOKEN.finditer(template):
        buffer += template[position : match.start()]
        position = match.end()
        if match["term"]:
            text, term = match["term_text"], match["term"]
        elif match["term_param"]:
            text, term = _param(match["term_param"], match["term_cat"], params, kinds)
        else:
            text, _ = _param(match["param"], match["cat"], params, kinds)
            buffer += text
            continue
        if buffer:
            segments.append({"text": buffer})
            buffer = ""
        segments.append({"text": text, "term": term})
    buffer += template[position:]
    if buffer:
        segments.append({"text": buffer})
    # 조사는 앞 조각의 끝 글자로 고르므로 조각을 이어 고른 뒤 다시 나눕니다.
    return _josa_segments(segments)


def _josa_segments(segments: list[dict]) -> list[dict]:
    out: list[dict] = []
    for segment in segments:
        text = segment["text"]
        if "term" not in segment and out and any(text.startswith(m) for m in JOSA):
            marker = next(m for m in JOSA if text.startswith(m))
            prev = out[-1]["text"]
            closed, opened = JOSA[marker]
            word = closed if _has_final(prev, rieul_as_open=marker == "(으)로") else opened
            text = word + text[len(marker) :]
        if "term" not in segment:
            text = _apply_josa(text)
        out.append({**segment, "text": text})
    return out


def preview(segments: list[dict] | None) -> list[dict] | None:
    """잠긴 문장의 앞부분(server `render.Preview` ko 규칙, D106). 자를 수 없으면 None입니다."""
    if not segments:
        return None
    text = "".join(s["text"] for s in segments)
    ends = [m.end() for m in re.finditer(r"\S+", text)]
    count = min(PREVIEW_WORDS, len(ends) - 1)
    if count < 1:
        return None
    cut = ends[count - 1]
    out: list[dict] = []
    offset = 0
    for segment in segments:
        if offset >= cut:
            break
        end = offset + len(segment["text"])
        out.append(segment if end <= cut else {"text": segment["text"][: cut - offset]})
        offset = end
    return out


def rendered(segments: list[dict]) -> dict:
    return {"segments": segments}


def evidence_items(judgment) -> list[dict]:
    """근거마다 판정 근거(`basis.<ruleId>`)와 원전(`source.<sourceRef>`) 문장(server `Renderer.evidence`)."""
    items = []
    for evidence in judgment.evidence:
        detail = {k: str(v) for k, v in evidence.detail.items()}
        item: dict = {"ruleId": evidence.rule_id, "sourceRef": evidence.source_ref, "detail": detail}
        basis = line("evidence.basis", f"basis.{evidence.rule_id}")
        if basis is not None:
            item["basis"] = rendered(render(basis, detail, f"basis.{evidence.rule_id}"))
        source = line("evidence.source", f"source.{evidence.source_ref}")
        if source is not None:
            item["source"] = rendered(render(source, {}))
        items.append(item)
    return items


def slot_text(slot: str, judgment, *, unlocked: bool, variant: str = "single", name: str = "") -> dict:
    template = line(slot, judgment.message_key, variant)
    if template is None:
        raise KeyError(f"원고가 없습니다: {slot} {judgment.message_key} {variant}")
    params = {k: str(v) for k, v in judgment.params.items()}
    if name:
        params["name"] = name
    out: dict = {
        "slot": slot,
        "messageKey": judgment.message_key,
        "variant": variant,
        # server `content.Reactable`: 총운 두 슬롯만 true입니다.
        "reactable": slot in ("daily.fortune.head", "daily.fortune.tag"),
        "text": rendered(render(template, params, judgment.message_key)),
    }
    for evidence in judgment.evidence:
        reason = line("explain.today_reason", f"reason.{evidence.rule_id}")
        if reason is not None:
            out["todayReason"] = rendered(render(reason, {}))
            break
    items = evidence_items(judgment)
    if unlocked and items:
        out["evidence"] = items
    if not unlocked:
        previews = []
        for item in items:
            head = {
                key: rendered(cut)
                for key in ("basis", "source")
                if key in item and (cut := preview(item[key]["segments"])) is not None
            }
            if head:
                previews.append(head)
        if previews:
            out["evidencePreview"] = previews
    return out




def lines_of(slot: str) -> list[tuple[str, str, str]]:
    """[slot]의 (키, 변주, 문장)을 원고 순서대로."""
    return [(key, variant, text) for (s, key, variant), text in LINES.items() if s == slot]


def load_hanja() -> dict[str, str]:
    """용어 id → 한자 표기(`content/hanja.yaml`, server 시드 변환과 같은 원본)."""
    out = {
        term: hanja
        for term, hanja in re.findall(r'term: ([\w.]+), hanja: "([^"]*)"', HANJA.read_text(encoding="utf-8"))
    }
    if not out:
        raise RuntimeError(f"한자 표기를 읽지 못했습니다(형식이 바뀌었는지 확인): {HANJA}")
    return out
