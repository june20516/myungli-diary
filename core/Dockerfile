# 명리 엔진 컨테이너 이미지 (#34, D56). core/만 빌드 맥락으로 쓴다(D33).
#   docker build -t myungli-engine core
#   docker run --rm -e PORT=8080 -p 8080:8080 myungli-engine
# 포트는 PORT 환경 변수(Cloud Run이 넣어 준다), 없으면 50051이다. 실행에 비밀값은 필요 없다.

FROM python:3.13-slim-bookworm AS builder
COPY --from=ghcr.io/astral-sh/uv:0.11.3 /uv /bin/uv
ENV UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    UV_PYTHON_DOWNLOADS=0
WORKDIR /app
# 의존성 층을 먼저 만들어 소스만 바뀐 빌드에서 다시 쓴다.
COPY pyproject.toml uv.lock README.md ./
RUN uv sync --frozen --no-dev --no-install-project
COPY src ./src
RUN uv sync --frozen --no-dev --no-editable

FROM python:3.13-slim-bookworm
RUN useradd --system --uid 10001 --no-create-home engine
COPY --from=builder /app/.venv /app/.venv
ENV PATH="/app/.venv/bin:${PATH}" \
    PYTHONUNBUFFERED=1
USER engine
EXPOSE 50051
CMD ["python", "-m", "myungli_engine"]
