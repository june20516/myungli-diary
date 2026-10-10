"""분포 보정 상수. tools/calibrate_strength.py --write 가 생성한다. 직접 고치지 않는다."""

SAMPLE_SEED = 20261010
SAMPLE_SIZE = 20000
STRENGTH_THRESHOLDS: tuple[float, float, float, float] = (22.381, 35.2381, 43.8095, 57.619)
JOHU_SUMMER_FIRE_SHARE = 0.3
JOHU_WINTER_WATER_SHARE = 0.3571
