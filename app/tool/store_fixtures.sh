#!/usr/bin/env bash
# 스토어 스크린샷용 대역 fixture(fixtures/store-<언어>, store-<언어>-unlocked)를 로컬 server 응답으로 다시 만듭니다
# (#1203, D133). server 문장이나 엔진 규칙이 바뀌어 스크린샷 글을 새로 맞출 때 돌립니다.
#
#   app/tool/store_fixtures.sh
#
# 하는 일:
# 1. 로컬 DB와 엔진(server/compose.yaml)을 따로 이름 붙인 compose 프로젝트로 띄웁니다(다른 세션의 로컬 DB와 섞이지 않게).
# 2. server를 staging 빌드 태그로 만들어(테스트 로그인, 테스트 광고 제거 기간) APP_ENV=local로 띄웁니다.
#    인증 값은 로컬 값 파일(D98 K6, `${MYUNGLI_LOCAL_DIR:-$HOME/.config/myungli}/app/local/env.sh`)을 읽고,
#    테스트 로그인 비밀은 실행마다 새로 만듭니다. 비밀은 출력하지 않습니다.
# 3. tool/store_fixtures.py가 데모 프로필로 세 언어 응답을 받아 fixture로 씁니다.
# 4. 끝나면(실패해도) server를 멈추고 compose 프로젝트를 볼륨째 지웁니다.
#
# 필요: Docker, Go, python3, openssl, curl.
set -euo pipefail

app_dir="$(cd "$(dirname "$0")/.." && pwd)"
server_dir="$(cd "$app_dir/../server" && pwd)"
local_env="${MYUNGLI_LOCAL_DIR:-$HOME/.config/myungli}/app/local/env.sh"
project="myungli-store-fixtures"
port=47290
work="$app_dir/.local/store-fixtures"

if [ ! -f "$local_env" ]; then
  echo "로컬 server 값 파일이 없습니다: $local_env (docs/local-values.md K6)" >&2
  exit 3
fi
mkdir -p "$work"

server_pid=""
cleanup() {
  if [ -n "$server_pid" ]; then
    kill "$server_pid" 2>/dev/null || true
    wait "$server_pid" 2>/dev/null || true
  fi
  docker compose -p "$project" -f "$server_dir/compose.yaml" down -v >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "로컬 DB와 엔진을 띄웁니다(compose 프로젝트 $project)."
docker compose -p "$project" -f "$server_dir/compose.yaml" up -d --wait >/dev/null

echo "server를 staging 빌드 태그로 만듭니다."
(cd "$server_dir" && go build -tags staging -o "$work/server" ./cmd/server)

# 로컬 값(인증 키 등)을 이 셸에만 읽습니다. 포트와 환경은 이 도구가 정합니다.
# shellcheck disable=SC1090
source "$local_env"
export APP_ENV=local
export PORT="$port"
TEST_LOGIN_SECRET="$(openssl rand -hex 32)"
export TEST_LOGIN_SECRET

echo "마이그레이션과 시드를 넣습니다."
(cd "$server_dir" && "$work/server" migrate up >"$work/migrate.log" 2>&1)
(cd "$server_dir" && "$work/server" seed >"$work/seed.log" 2>&1)

echo "server를 띄웁니다(포트 $port, 로그 $work/serve.log)."
(cd "$server_dir" && exec "$work/server" serve >"$work/serve.log" 2>&1) &
server_pid=$!
for _ in $(seq 1 60); do
  if curl -fsS "http://127.0.0.1:$port/health" >/dev/null 2>&1; then
    break
  fi
  if ! kill -0 "$server_pid" 2>/dev/null; then
    echo "server가 시작하지 못했습니다. $work/serve.log를 보세요." >&2
    exit 1
  fi
  sleep 1
done

STORE_API="http://127.0.0.1:$port" python3 -I "$app_dir/tool/store_fixtures.py"
