import unicodedata

import pytest

from mlw.josa import Batchim, NameResult, default_josa_data, final_batchim, normalize_name, render_josa
from mlw.model import JosaData

EXPLICIT_CASES = [
    ("남색(이)가", "남색이"),
    ("파랑(이)가", "파랑이"),
    ("하늘(으)로", "하늘로"),
    ("동쪽(으)로", "동쪽으로"),
    ("서(으)로", "서로"),
    ("1(이)에요", "1이에요"),
    ("2(이)에요", "2예요"),
    ("10(은)는", "10은"),
    ("L(으)로", "L로"),
    ("A(과)와", "A와"),
    ("甲(을)를", "甲을"),
    ("丑(이)가", "丑이"),
    ("★(이)가", "★이(가)"),
    ("보라(이)가", "보라가"),
    ("★(으)로", "★(으)로"),
    ("★(이)에요", "★(이)에요"),
]


def _data() -> JosaData:
    return default_josa_data()


@pytest.mark.parametrize(("text", "expected"), EXPLICIT_CASES)
def test_render_explicit(text: str, expected: str) -> None:
    assert render_josa(text) == expected


def test_render_examples_from_yaml() -> None:
    examples = _data().examples
    assert len(examples) >= len(EXPLICIT_CASES)
    for example in examples:
        assert render_josa(example.text) == example.expected, example.text


def test_yaml_examples_cover_explicit_cases() -> None:
    pairs = {(example.text, example.expected) for example in _data().examples}
    assert set(EXPLICIT_CASES) <= pairs


def test_render_inside_sentence_and_multiple_markers() -> None:
    assert render_josa("오늘은 {x}가 아니라 물(이)가 필요해요") == "오늘은 {x}가 아니라 물이 필요해요"
    assert render_josa("봄(은)는 나무(을)를 키워요") == "봄은 나무를 키워요"


def test_render_without_marker_is_unchanged() -> None:
    assert render_josa("그대로 둡니다") == "그대로 둡니다"


def test_render_fallback_when_nothing_precedes() -> None:
    assert render_josa("(이)가") == "이(가)"


@pytest.mark.parametrize(
    ("text", "expected"),
    [
        ("서", Batchim.NONE),
        ("물", Batchim.RIEUL),
        ("파랑", Batchim.OTHER),
        ("1", Batchim.RIEUL),
        ("3", Batchim.OTHER),
        ("100", Batchim.OTHER),
        ("0", Batchim.OTHER),
        ("R", Batchim.RIEUL),
        ("N", Batchim.OTHER),
        ("Z", Batchim.NONE),
        ("甲", Batchim.OTHER),
        ("子", Batchim.NONE),
        ("★", None),
        ("", None),
    ],
)
def test_final_batchim(text: str, expected: Batchim | None) -> None:
    assert final_batchim(text) is expected


def test_normalize_name_strips_suffix() -> None:
    assert normalize_name("ko", " 민지님 ") == NameResult("민지", ("name.suffix_stripped",))


def test_normalize_name_strips_repeated_suffix() -> None:
    assert normalize_name("ko", "민지님님") == NameResult("민지", ("name.suffix_stripped",))


@pytest.mark.parametrize("raw", ["님", "님님", "", "   "])
def test_normalize_name_empty(raw: str) -> None:
    assert normalize_name("ko", raw) == NameResult(None, ("name.empty",))


def test_normalize_name_too_long() -> None:
    assert normalize_name("ko", "가" * 11) == NameResult(None, ("name.too_long",))
    assert normalize_name("ko", "가" * 10).value == "가" * 10
    assert normalize_name("en", "a" * 20).value == "a" * 20
    assert normalize_name("en", "a" * 21) == NameResult(None, ("name.too_long",))


def test_normalize_name_japanese_suffix_warns_but_stays() -> None:
    assert normalize_name("ja", "ゆきさん") == NameResult("ゆきさん", ("name.suffix_warning",))


def test_normalize_name_emoji() -> None:
    assert normalize_name("en", "Sam🙂") == NameResult(None, ("name.emoji",))


def test_normalize_name_control_character() -> None:
    assert normalize_name("en", "Sam\u0007") == NameResult(None, ("name.control",))


def test_normalize_name_plain() -> None:
    assert normalize_name("en", "Sam") == NameResult("Sam", ())


def test_normalize_name_applies_nfc_before_checks() -> None:
    nfd = unicodedata.normalize("NFD", "민지님")
    assert nfd != "민지님"
    assert normalize_name("ko", nfd) == NameResult("민지", ("name.suffix_stripped",))


def test_normalize_name_nfd_ten_syllables_is_not_too_long() -> None:
    nfd = unicodedata.normalize("NFD", "가" * 10)
    assert normalize_name("ko", nfd) == NameResult("가" * 10, ())


def test_render_josa_applies_nfc() -> None:
    assert render_josa(unicodedata.normalize("NFD", "남색(이)가")) == "남색이"


def test_final_batchim_applies_nfc() -> None:
    assert final_batchim(unicodedata.normalize("NFD", "남색")) is Batchim.OTHER
    assert final_batchim(unicodedata.normalize("NFD", "보라")) is Batchim.NONE
