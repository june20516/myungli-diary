"""ui 원고의 조사 표기를 ICU select로 펼칩니다(spec 2026-10-22-ui-josa §4).

app ARB는 조사를 렌더하지 않으므로, ko ARB를 만들 때 `{p}(이)가`를
`{p}{pJosa, select, final{이} rieul{이} none{가} other{이(가)}}`로 바꿉니다.
app은 값의 받침 종류를 `pJosa`로 넘깁니다. 가지 값은 `rules/josa.yaml`의 `pairs`에서 옵니다.
"""

import regex

from mlw.josa import default_josa_data
from mlw.model import JosaData, JosaPair

JOSA_SUFFIX = "Josa"
# 받침 있음(ㄹ 아님), ㄹ 받침, 받침 없음, 판정할 수 없음(ICU 필수 기본 가지) 순서입니다.
JOSA_BRANCHES: tuple[str, ...] = ("final", "rieul", "none", "other")
_SELECT = regex.compile(
    r"\{(?P<var>\w+" + JOSA_SUFFIX + r"), select, "
    + " ".join(rf"{branch}\{{(?P<{branch}>[^{{}}]*)\}}" for branch in JOSA_BRANCHES)
    + r"\}"
)


def josa_param(name: str) -> str:
    """조사 가지를 고르는 매개변수 이름입니다(`title` → `titleJosa`)."""
    return name + JOSA_SUFFIX


def _branch_values(pair: JosaPair) -> dict[str, str]:
    rieul = pair.rieul if pair.rieul is not None else pair.with_batchim
    return {"final": pair.with_batchim, "rieul": rieul, "none": pair.without_batchim, "other": pair.fallback}


def _select(name: str, pair: JosaPair) -> str:
    values = _branch_values(pair)
    branches = " ".join(f"{branch}{{{values[branch]}}}" for branch in JOSA_BRANCHES)
    return f"{{{josa_param(name)}, select, {branches}}}"


def expand_josa(text: str, data: JosaData | None = None) -> tuple[str, list[str]]:
    """매개변수 바로 뒤 조사 표기를 select로 펼친 문장과, 조사가 붙은 매개변수 이름(처음 나온 순서)입니다."""
    rules = data if data is not None else default_josa_data()
    if not rules.pairs:
        return text, []
    by_marker = {pair.marker: pair for pair in rules.pairs}
    markers = sorted(by_marker, key=len, reverse=True)
    pattern = regex.compile(r"\{(?P<name>[^{}:\s,]+)\}(?P<marker>" + "|".join(regex.escape(m) for m in markers) + ")")
    names: list[str] = []

    def replace(match: regex.Match[str]) -> str:
        name = match.group("name")
        if name not in names:
            names.append(name)
        return "{" + name + "}" + _select(name, by_marker[match.group("marker")])

    return pattern.sub(replace, text), names


def select_forms(text: str) -> list[str]:
    """펼친 조사 select를 가지마다 하나씩 고른 문장입니다. 한 문장의 모든 select가 같은 가지를 고릅니다."""
    if _SELECT.search(text) is None:
        return [text]
    return [_SELECT.sub(lambda match, branch=branch: match.group(branch), text) for branch in JOSA_BRANCHES]
