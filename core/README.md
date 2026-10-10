# myungri-engine

명리 엔진(Python). 출생 정보로 원국을 세우고 일진 × 원국 판정을 계산해 gRPC로 반환하는 상태 없는 엔진입니다.
문장은 만들지 않고 메시지 키, 매개변수, 근거만 반환합니다.

* 설계: [`docs/specs/2026-10-10-myungri-engine-design.md`](docs/specs/2026-10-10-myungri-engine-design.md)
* 연산 로직 위키(v1.5): [`docs/engine-logic-wiki.md`](docs/engine-logic-wiki.md)
* core 결정 로그(C1~C5): [`docs/decisions.md`](docs/decisions.md)
* 필요한 도구: [uv](https://docs.astral.sh/uv/)(Python 3.13), proto 검사에 [buf](https://buf.build/)

## 설치와 실행

```bash
cd core
uv sync
uv run python -m myungri_engine --port 50051   # gRPC 서버
```

## 테스트와 검사

```bash
uv run pytest -q -m "not slow"   # 기본: 단위·통합·불변 조건·회귀 스냅샷·골든(기준 앱)
uv run pytest -q -m slow         # 느린 테스트: 분포 보정 상수 확인(약 80초), KASI 골든(약 30초)
uv run pytest -q tests/golden    # 골든 테스트만 (KASI 골든은 slow 마커)
uv run ruff check .
uv run mypy src tools
```

KASI 골든은 저장된 fixture(`tests/golden/fixtures/`)만 읽고 네트워크를 쓰지 않습니다.
CI는 기본 검사를 push·PR마다, slow 테스트를 수동 실행과 매주 한 번 돌립니다(`.github/workflows/core.yml`).

## proto 코드 생성

`proto/myungri/engine/v1/engine.proto`에서 Python 코드를 만들어 `src/myungri_engine/_gen/`에 commit합니다(D33).
proto를 고치면 다시 생성하고, CI가 생성물과 proto의 일치를 검사합니다.

```bash
bash tools/gen_proto.sh
git diff --exit-code src/myungri_engine/_gen   # 변경이 없어야 합니다
(cd ../proto && buf lint)
```

## 강약 보정 상수

`constants/calibration.py`의 신강·신약 경계값과 조후 기준값은 무작위 출생 분포(난수 시드 고정)에서 산출합니다.

```bash
uv run python tools/calibrate_strength.py --check   # 상수가 산출값과 같은지 확인
uv run python tools/calibrate_strength.py --write   # 산출값으로 상수 파일 갱신
```

상수가 바뀌면 출력이 달라지므로 아래 ruleset 갱신 절차를 함께 진행합니다.

## KASI 자료 수집

절기·음양력 골든 fixture는 공공데이터포털의 한국천문연구원 API로 받습니다. 키는 **환경 변수 `KASI_SERVICE_KEY`로만** 넘기고 저장소에 넣지 않습니다(`core/.env`는 git이 무시합니다).

```bash
export KASI_SERVICE_KEY="<발급받은 키>"
uv run python tools/fetch_kasi.py --years 2000-2028
# 절기와 음력 범위를 따로: --terms-years, --lunar-years
```

## ruleset 버전과 스냅샷 갱신

규칙·상수·근거 데이터가 바뀌어 출력이 달라지면 `ruleset_version`을 올립니다(spec §12). 순서는 다음과 같습니다.

1. `src/myungri_engine/version.py`의 `RULESET_VERSION`을 올립니다.
2. 회귀 스냅샷을 갱신하고 diff가 의도한 변화인지 확인합니다.
   ```bash
   uv run pytest tests/snapshots --snapshot-update
   ```
3. ruleset 해시 기록을 갱신합니다. 스냅샷이 바뀌었는데 버전이 그대로면 갱신이 거부됩니다.
   ```bash
   UPDATE_RULESET_HASH=1 uv run pytest tests/unit/test_ruleset_version.py
   ```
4. 서버가 일기 태그와 캐시에 `ruleset_version`을 쓰므로(D31), 값이 바뀌었음을 `docs/coordination/`으로 알립니다.
