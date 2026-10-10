# myungri-engine

명리 엔진(Python). 출생 정보로 원국을 세우고 일진 × 원국 판정을 계산해 gRPC로 반환하는 상태 없는 엔진입니다.
문장은 만들지 않고 메시지 키, 매개변수, 근거만 반환합니다.

## 개발

```bash
uv sync
uv run pytest -q
uv run ruff check .
uv run mypy src
```

설계는 `docs/specs/2026-10-10-myungri-engine-design.md`를 따릅니다.
