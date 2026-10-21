"""테스트 실행 안에서만 쓰는 결과 캐시(`tests/session_cache.py`, D81 ⑥)를 검사합니다."""

from pathlib import Path

import pytest
from session_cache import SessionCache


def counting_reader(calls: list[Path]):
    def read(path: Path) -> list[str]:
        calls.append(path)
        return path.read_text(encoding="utf-8").split()

    return read


def test_same_file_content_reuses_result(tmp_path: Path) -> None:
    path = tmp_path / "a.txt"
    path.write_text("가 나", encoding="utf-8")
    calls: list[Path] = []
    read = SessionCache().wrap(counting_reader(calls))
    assert read(path) == ["가", "나"]
    assert read(path) == ["가", "나"]
    assert len(calls) == 1


def test_changed_file_content_reads_again(tmp_path: Path) -> None:
    path = tmp_path / "a.txt"
    path.write_text("가", encoding="utf-8")
    calls: list[Path] = []
    read = SessionCache().wrap(counting_reader(calls))
    read(path)
    path.write_text("나", encoding="utf-8")
    assert read(path) == ["나"]
    assert len(calls) == 2


def test_directory_key_covers_every_file(tmp_path: Path) -> None:
    (tmp_path / "sub").mkdir()
    (tmp_path / "sub" / "b.txt").write_text("1", encoding="utf-8")
    calls: list[Path] = []
    cached = SessionCache().wrap(lambda path: calls.append(path) or sorted(p.name for p in path.rglob("*")))
    cached(tmp_path)
    (tmp_path / "sub" / "b.txt").write_text("2", encoding="utf-8")
    cached(tmp_path)
    assert len(calls) == 2


def test_value_arguments_are_part_of_key() -> None:
    calls: list[int] = []
    double = SessionCache().wrap(lambda value: calls.append(value) or [value * 2])
    assert double(1) == [2]
    assert double(2) == [4]
    assert double(1) == [2]
    assert calls == [1, 2]


def test_returned_container_is_a_copy(tmp_path: Path) -> None:
    path = tmp_path / "a.txt"
    path.write_text("가", encoding="utf-8")
    read = SessionCache().wrap(counting_reader([]))
    first = read(path)
    first.append("바꿈")
    assert read(path) == ["가"]


def test_errors_are_not_cached(tmp_path: Path) -> None:
    calls: list[Path] = []
    read = SessionCache().wrap(counting_reader(calls))
    missing = tmp_path / "없음.txt"
    for _ in range(2):
        with pytest.raises(FileNotFoundError):
            read(missing)
    assert len(calls) == 2


def test_verify_catches_mutated_shared_value() -> None:
    cache = SessionCache()
    shared = {"key": ["원래"]}
    cached = cache.wrap(lambda: shared)
    cached()["key"].append("바뀜")
    with pytest.raises(AssertionError, match="공유 결과가 바뀌었습니다"):
        cache.verify()


def test_verify_passes_when_untouched() -> None:
    cache = SessionCache()
    cache.wrap(lambda: {"key": ("그대로",)})()
    cache.verify()
