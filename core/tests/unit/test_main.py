# 실행 포트 결정: --port 인자 → PORT 환경 변수(Cloud Run) → 기본값 (#34)
import pytest

from myungli_engine.__main__ import resolve_port
from myungli_engine.grpc_api.server import DEFAULT_PORT


def test_cli_port_wins_over_env() -> None:
    assert resolve_port(cli_port=7000, env={"PORT": "8080"}) == 7000


def test_env_port_used_without_cli_port() -> None:
    assert resolve_port(cli_port=None, env={"PORT": "8080"}) == 8080


def test_default_port_without_cli_or_env() -> None:
    assert resolve_port(cli_port=None, env={}) == DEFAULT_PORT


def test_non_numeric_env_port_is_rejected() -> None:
    with pytest.raises(ValueError, match="PORT"):
        resolve_port(cli_port=None, env={"PORT": "http"})
