"""시간대 로딩의 입력 검사 (Q1 core-Q1-1, 2)."""

import pytest

from myungli_engine.calendar_core.time_basis import MAX_ECHOED_NAME_LENGTH, load_zone
from myungli_engine.domain.errors import InvalidInputError


def test_known_zone_loads() -> None:
    assert load_zone("Asia/Seoul").key == "Asia/Seoul"


def test_name_longer_than_file_name_limit_is_invalid_input() -> None:
    # 파일 이름 한도(약 255바이트)를 넘으면 ZoneInfo가 OSError를 낸다.
    with pytest.raises(InvalidInputError):
        load_zone("A" * 300)


def test_error_message_does_not_echo_long_name_in_full() -> None:
    name = "Asia/" + "x" * 1000
    with pytest.raises(InvalidInputError) as caught:
        load_zone(name)
    message = str(caught.value)
    assert name not in message
    assert len(message) < MAX_ECHOED_NAME_LENGTH + 50
