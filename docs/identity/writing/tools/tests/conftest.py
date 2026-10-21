"""테스트 전체가 함께 쓰는 fixture입니다."""

from collections.abc import Iterator

import pytest
from session_cache import SessionCache

import mlw.cli

# `mlw check`·`gen-docs`가 부르는 함수 중, 같은 입력이면 결과가 같고 시간이 많이 드는 것입니다(#361).
CACHED_CLI_FUNCTIONS = ("load_rules", "load_slots", "load_content", "load_ia", "check_days", "check_weeks")


@pytest.fixture(scope="session", autouse=True)
def cached_cli() -> Iterator[None]:
    """한 실행 안에서 같은 원고를 다시 읽거나 같은 묶음 검사를 다시 돌리지 않게 합니다. 끝에 공유 값이 바뀌지 않았는지 봅니다."""
    cache = SessionCache()
    with pytest.MonkeyPatch.context() as patch:
        for name in CACHED_CLI_FUNCTIONS:
            patch.setattr(mlw.cli, name, cache.wrap(getattr(mlw.cli, name)))
        yield
    cache.verify()
