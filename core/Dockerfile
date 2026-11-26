# 명리 엔진 컨테이너 이미지 (#34, D56). core/만 빌드 맥락으로 쓴다(D33).
#   docker build -t myungli-engine core
#   docker run --rm -e PORT=8080 -p 8080:8080 myungli-engine
# 포트는 PORT 환경 변수(Cloud Run이 넣어 준다), 없으면 50051이다. 실행에 비밀값은 필요 없다.
# 기반 이미지는 태그와 digest를 함께 적어 태그가 다른 내용으로 바뀌어도 빌드가 따라가지 않게 한다(Q1 core-Q1-3).
# digest를 올릴 때는 두 python 줄을 같은 값으로 맞춘다. uv 판은 core.yml의 setup-uv version과 같게 둔다.

FROM python:3.13-slim-trixie@sha256:7249d5587b78209a006dc4a3b5340678f84ea729239193aa559962cd8c1fce50 AS builder
COPY --from=ghcr.io/astral-sh/uv:0.11.3@sha256:90bbb3c16635e9627f49eec6539f956d70746c409209041800a0280b93152823 /uv /bin/uv
ENV UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    UV_PYTHON_DOWNLOADS=0
WORKDIR /app
# 의존성 층을 먼저 만들어 소스만 바뀐 빌드에서 다시 쓴다.
COPY pyproject.toml uv.lock README.md ./
RUN uv sync --frozen --no-dev --no-install-project
COPY src ./src
RUN uv sync --frozen --no-dev --no-editable

FROM python:3.13-slim-trixie@sha256:7249d5587b78209a006dc4a3b5340678f84ea729239193aa559962cd8c1fce50
RUN useradd --system --uid 10001 --no-create-home engine
COPY --from=builder /app/.venv /app/.venv
ENV PATH="/app/.venv/bin:${PATH}" \
    PYTHONUNBUFFERED=1
USER engine
EXPOSE 50051
CMD ["python", "-m", "myungli_engine"]
