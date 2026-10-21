"""pytest 한 번의 실행 안에서만 쓰는 결과 캐시입니다(테스트 유틸리티, D81 ⑥).

`test_cli`처럼 `mlw check`를 여러 번 부르는 테스트가 같은 원고를 매번 다시 읽고 같은 묶음 검사를 다시 돌리지 않게 합니다.

* 키: 함수와 모든 인자입니다. 경로 인자는 그 파일(디렉터리면 아래 모든 파일)의 이름과 내용 해시로, 그 밖의 인자는 값의 해시로 넣습니다.
  그래서 원고를 고치는 테스트(`tmp_path` 사본)나 내용이 바뀐 파일은 새로 계산합니다.
* 쓰지 않는 때: 결과는 파일에 저장하지 않습니다. 예외가 난 호출은 캐시하지 않습니다.
* 공유 값 보호: 돌려줄 때 바깥 그릇(dict·list)은 사본으로 줍니다. 그 안의 값까지 바꾸면 `verify()`가 세션 끝에 잡습니다.
"""

import functools
import hashlib
import pickle
from collections.abc import Callable, ItemsView, KeysView, ValuesView
from pathlib import Path
from typing import Any


def _path_digest(path: Path) -> str:
    digest = hashlib.sha256(str(path.resolve()).encode())
    if path.is_dir():
        for child in sorted(p for p in path.rglob("*") if p.is_file()):
            digest.update(str(child.relative_to(path)).encode())
            digest.update(child.read_bytes())
    elif path.is_file():
        digest.update(path.read_bytes())
    else:
        digest.update(b"<missing>")
    return digest.hexdigest()


def _value_digest(value: Any) -> str:
    if isinstance(value, Path):
        return "path:" + _path_digest(value)
    if isinstance(value, (KeysView, ValuesView, ItemsView)):
        value = list(value)
    return "value:" + hashlib.sha256(pickle.dumps(value)).hexdigest()


def _copy(value: Any) -> Any:
    if isinstance(value, dict):
        return dict(value)
    if isinstance(value, list):
        return list(value)
    return value


class SessionCache:
    def __init__(self) -> None:
        self._results: dict[tuple[str, ...], Any] = {}
        self._stored: dict[tuple[str, ...], str] = {}

    def wrap[**P, R](self, function: Callable[P, R]) -> Callable[P, R]:
        name = f"{function.__module__}.{function.__qualname__}"

        @functools.wraps(function)
        def cached(*args: P.args, **kwargs: P.kwargs) -> R:
            key = (
                name,
                *(_value_digest(arg) for arg in args),
                *(f"{k}={_value_digest(v)}" for k, v in sorted(kwargs.items())),
            )
            if key not in self._results:
                result = function(*args, **kwargs)
                self._results[key] = result
                self._stored[key] = _value_digest(result)
            return _copy(self._results[key])  # type: ignore[no-any-return]

        return cached

    def verify(self) -> None:
        """캐시한 값이 저장할 때와 같은지 봅니다. 어떤 테스트가 공유 값을 바꿨으면 실패합니다."""
        changed = [key[0] for key, result in self._results.items() if _value_digest(result) != self._stored[key]]
        assert not changed, f"공유 결과가 바뀌었습니다(테스트가 캐시된 값을 고침): {changed}"
