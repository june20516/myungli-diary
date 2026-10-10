import pytest

from myungri_engine.constants.calibration import STRENGTH_THRESHOLDS
from myungri_engine.domain.enums import Branch as B
from myungri_engine.domain.enums import Element, StrengthLevel
from myungri_engine.domain.enums import Stem as S
from myungri_engine.domain.models import FourPillars, Pillar
from myungri_engine.rules.strength import compute_strength, element_weights, level_for_score

# 庚午년 辛巳월 庚辰일 辛巳시. 일간 庚(금)은 제외.
CHART = FourPillars(
    year=Pillar(S.GYEONG, B.O),
    month=Pillar(S.SIN, B.SA),
    day=Pillar(S.GYEONG, B.JIN),
    hour=Pillar(S.SIN, B.SA),
)


def test_position_weights() -> None:
    # 천간: 庚 1 + 辛 1 + 辛 1 -> 금 3
    # 午(1.5; 丁 0.7, 己 0.3): 화 1.05, 토 0.45
    # 巳(3; 丙 0.6, 庚 0.3, 戊 0.1): 화 1.8, 금 0.9, 토 0.3
    # 辰(1.5; 戊 0.6, 乙 0.3, 癸 0.1): 토 0.9, 목 0.45, 수 0.15
    # 巳(1.5): 화 0.9, 금 0.45, 토 0.15
    weights = element_weights(CHART)
    assert weights[Element.METAL] == pytest.approx(4.35)
    assert weights[Element.FIRE] == pytest.approx(3.75)
    assert weights[Element.EARTH] == pytest.approx(1.8)
    assert weights[Element.WOOD] == pytest.approx(0.45)
    assert weights[Element.WATER] == pytest.approx(0.15)
    assert sum(weights.values()) == pytest.approx(10.5)


def test_time_unknown_drops_hour() -> None:
    no_hour = FourPillars(CHART.year, CHART.month, CHART.day, None)
    assert sum(element_weights(no_hour).values()) == pytest.approx(8.0)


def test_score_is_support_share() -> None:
    weights = element_weights(CHART)
    expected = 100 * (weights[Element.METAL] + weights[Element.EARTH]) / sum(weights.values())
    result = compute_strength(CHART)
    assert result.score == pytest.approx(expected)
    assert result.score == pytest.approx(100 * 6.15 / 10.5)
    assert result.element_weights == weights


def test_level_boundaries() -> None:
    t1, t2, t3, t4 = STRENGTH_THRESHOLDS
    eps = 1e-6
    # 경계값 자체는 더 높은 등급에 속한다 (score < T 이면 낮은 등급).
    assert level_for_score(t1 - eps) is StrengthLevel.VERY_WEAK
    assert level_for_score(t1) is StrengthLevel.WEAK
    assert level_for_score(t2 - eps) is StrengthLevel.WEAK
    assert level_for_score(t2) is StrengthLevel.NEUTRAL
    assert level_for_score(t3 - eps) is StrengthLevel.NEUTRAL
    assert level_for_score(t3) is StrengthLevel.STRONG
    assert level_for_score(t4 - eps) is StrengthLevel.STRONG
    assert level_for_score(t4) is StrengthLevel.VERY_STRONG
