#!/usr/bin/env bash
# proto/myungri/engine/v1/engine.proto 에서 검사기용 Python 코드를 생성한다.
#
# 사용: bash gen_proto.sh [출력 디렉터리]   (기본 src/mlw/_gen)
# 환경 변수 PYTHON: grpc_tools가 설치된 Python 실행 명령 (기본 "uv run python")
#
# 방식은 core/tools/gen_proto.sh 와 같다. 생성 코드는 mlw._gen.myungri.engine.v1 패키지로 import한다.
# protoc의 grpc 플러그인은 "from myungri.engine.v1 import engine_pb2" 처럼 proto 경로 기준 절대 import를 쓰므로,
# 이를 패키지 경로로 고치는 후처리를 한다.
set -euo pipefail

TOOLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROTO_ROOT="$(cd "${TOOLS_DIR}/../../../../proto" && pwd)"
OUT_DIR="${1:-${TOOLS_DIR}/src/mlw/_gen}"
PROTO_FILE="myungri/engine/v1/engine.proto"
PACKAGE_DIR="myungri/engine/v1"
GEN_PACKAGE="mlw._gen.myungri.engine.v1"
read -r -a PYTHON_CMD <<< "${PYTHON:-uv run python}"

# 이전 생성물만 지운다(출력 디렉터리 자체는 지우지 않음).
rm -rf "${OUT_DIR}/myungri"
mkdir -p "${OUT_DIR}"

cd "${TOOLS_DIR}"
"${PYTHON_CMD[@]}" -m grpc_tools.protoc \
  -I "${PROTO_ROOT}" \
  --python_out="${OUT_DIR}" \
  --pyi_out="${OUT_DIR}" \
  --grpc_python_out="${OUT_DIR}" \
  "${PROTO_FILE}"

# grpc 생성 코드의 proto 경로 기준 import를 패키지 경로로 고친다.
GRPC_FILE="${OUT_DIR}/${PACKAGE_DIR}/engine_pb2_grpc.py"
sed "s/^from myungri\.engine\.v1 import engine_pb2 as /from ${GEN_PACKAGE} import engine_pb2 as /" \
  "${GRPC_FILE}" > "${GRPC_FILE}.tmp"
mv "${GRPC_FILE}.tmp" "${GRPC_FILE}"
if grep -q "^from myungri\.engine" "${GRPC_FILE}"; then
  echo "gen_proto.sh: engine_pb2_grpc.py 의 import 후처리에 실패했습니다" >&2
  exit 1
fi

# 패키지로 import되도록 각 단계에 빈 __init__.py를 둔다.
for package in "" "myungri" "myungri/engine" "${PACKAGE_DIR}"; do
  : > "${OUT_DIR}/${package:+${package}/}__init__.py"
done
