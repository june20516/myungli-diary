# myungli-engine

명리 엔진(Python). 출생 정보로 원국을 세우고 일진 × 원국 판정을 계산해 gRPC로 반환하는 상태 없는 엔진입니다.
문장은 만들지 않고 메시지 키, 매개변수, 근거만 반환합니다.

* 설계: [`docs/specs/2026-10-10-myungli-engine-design.md`](docs/specs/2026-10-10-myungli-engine-design.md)
* 연산 로직 위키(v1.7): [`docs/engine-logic-wiki.md`](docs/engine-logic-wiki.md)
* core 결정 로그(C1~C5): [`docs/decisions.md`](docs/decisions.md)
* 필요한 도구: [uv](https://docs.astral.sh/uv/)(Python 3.13), proto 검사에 [buf](https://buf.build/)

## 설치와 실행

```bash
cd core
uv sync
uv run python -m myungli_engine --port 50051   # gRPC 서버
```

포트는 `--port` 인자 → `PORT` 환경 변수 → 50051 순으로 정합니다. 서버는 엔진 서비스와 함께 gRPC health checking(`grpc.health.v1.Health`)을 제공합니다. 준비(근거 데이터 검증, 캐시 예열)가 끝나면 전체(`""`)와 `myungli.engine.v1.MyungliEngine`이 `SERVING`이 됩니다. SIGTERM을 받으면 `NOT_SERVING`으로 바꾸고 8초 안에 종료합니다.

## 컨테이너 (Cloud Run, D56)

```bash
docker build -t myungli-engine core                          # 저장소 루트에서. 빌드 맥락은 core/만(D33)
docker run --rm -e PORT=8080 -p 8080:8080 myungli-engine
uv run python tools/check_container.py localhost:8080         # core/에서. health와 GetInfo 확인
```

* 실행에 비밀값이 필요 없습니다. `KASI_SERVICE_KEY`는 자료 수집 도구(`tools/fetch_kasi.py`)에서만 씁니다. `.dockerignore`가 허용 목록이라 `.env`는 이미지에 들어가지 않습니다.
* Cloud Run 설정: HTTP/2 end-to-end(h2c)를 켜야 gRPC가 통합니다. startup probe는 gRPC 방식으로 서비스 이름 `myungli.engine.v1.MyungliEngine`을 씁니다.

## 테스트와 검사

```bash
uv run pytest -q -m "not slow"   # 기본: 단위·통합·불변 조건·회귀 스냅샷·골든(기준 앱)
uv run pytest -q -m slow         # 느린 테스트: 분포 보정 상수 확인(약 80초), KASI 골든(약 30초)
uv run pytest -q tests/golden    # 골든 테스트만 (KASI 골든은 slow 마커)
uv run ruff check .
uv run mypy src tools
```

KASI 골든은 저장된 fixture(`tests/golden/fixtures/`)만 읽고 네트워크를 쓰지 않습니다.
CI(`.github/workflows/core.yml`)는 PR과 main push에서 ci-gate가 불러 기본 검사와 이미지 검사를 돌립니다. slow 테스트는 계산·규칙·근거 데이터를 바꾸는 변경, 수동 실행, 매주 한 번 돌립니다.

## proto 코드 생성

`proto/myungli/engine/v1/engine.proto`에서 Python 코드를 만들어 `src/myungli_engine/_gen/`에 commit합니다(D33).
proto를 고치면 다시 생성하고, CI가 생성물과 proto의 일치를 검사합니다.

```bash
bash tools/gen_proto.sh
git diff --exit-code src/myungli_engine/_gen   # 변경이 없어야 합니다
(cd ../proto && buf lint)
```

## 메시지 키와 매개변수 목록

키와 키별 매개변수 이름은 `src/myungli_engine/constants/message_keys.py`의 `KEY_PARAMS` 한 곳에서 선언합니다.
엔진이 판정을 만들 때 `require(key, params)`가 실제 매개변수 이름이 선언과 같은지 확인합니다.
선언을 바꾸면 계약 파일 두 개를 다시 만들어 commit합니다. 테스트가 코드와 파일의 일치를 검사합니다.

```bash
uv run python -m myungli_engine.constants.message_keys > message_keys.json
uv run python -m myungli_engine.constants.message_keys params > message_params.json
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

출처: 한국천문연구원, 공공데이터포털(음양력 정보 15012679, 특일 정보 15012690). 두 데이터셋 모두 이용허락범위 제한이 없습니다.

```bash
export KASI_SERVICE_KEY="<발급받은 키>"
uv run python tools/fetch_kasi.py --years 2000-2028
# 절기와 음력 범위를 따로: --terms-years, --lunar-years
```

## ruleset 버전과 스냅샷 갱신

규칙·상수·근거 데이터가 바뀌어 출력이 달라지면 `ruleset_version`을 올립니다(spec §12). 순서는 다음과 같습니다.

1. `src/myungli_engine/version.py`의 `RULESET_VERSION`을 올립니다.
2. 회귀 스냅샷을 갱신하고 diff가 의도한 변화인지 확인합니다.
   ```bash
   uv run pytest tests/snapshots --snapshot-update
   ```
3. ruleset 해시 기록을 갱신합니다. 스냅샷이 바뀌었는데 버전이 그대로면 갱신이 거부됩니다.
   ```bash
   UPDATE_RULESET_HASH=1 uv run pytest tests/unit/test_ruleset_version.py
   ```
4. 서버가 일기 태그와 캐시에 `ruleset_version`을 쓰므로(D31), 값이 바뀌었음을 `from:core` GitHub Issue로 알립니다.
