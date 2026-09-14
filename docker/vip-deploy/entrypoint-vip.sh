#!/bin/sh
# VIP 版镜像 entrypoint
# 1. 启动 certd (默认 CMD 逻辑)
# 2. 后台启动一个 内置 fake-plus-server (本容器内, 监听 11007)
# 3. certd 则通过 env PLUS_SERVER_BASE_URL=http://127.0.0.1:11007 指向本地

set -e

# 环境变量默认值
export CERTD_FAKE_SERVER_PORT="${CERTD_FAKE_SERVER_PORT:-11007}"
export CERTD_SELF_KEY="${CERTD_SELF_KEY:-/app/tools/selfsign_key.pem}"
export CERTD_VIP_TYPE="${CERTD_VIP_TYPE:-plus}"
export PLUS_SERVER_BASE_URL="${PLUS_SERVER_BASE_URL:-http://127.0.0.1:${CERTD_FAKE_SERVER_PORT}}"

echo "[entrypoint-vip] starting fake-plus-server on :${CERTD_FAKE_SERVER_PORT}"
# 安装 cryptography (alpine 用 --break-system-packages / slim 用正常 pip)
(pip install --quiet --no-cache-dir --break-system-packages cryptography 2>/dev/null \
  || pip install --quiet cryptography 2>/dev/null \
  || pip3 install --quiet --break-system-packages cryptography 2>/dev/null \
  || pip3 install --quiet cryptography 2>/dev/null) \
  && python3 /app/tools/fake_plus_server.py > /var/log/fake-plus.log 2>&1 &
FAKE_PID=$!

echo "[entrypoint-vip] fake-plus-server pid: ${FAKE_PID}"
echo "[entrypoint-vip] PLUS_SERVER_BASE_URL=$PLUS_SERVER_BASE_URL"

# 等 fake server 探活 (最多30s)
for i in $(seq 1 15); do
  if wget -q -O- --post-data='{}' "http://127.0.0.1:${CERTD_FAKE_SERVER_PORT}/api/activation/app/get" 2>/dev/null | grep -q '"ok":true' 2>/dev/null; then
    echo "[entrypoint-vip] fake-plus-server ready"
    break
  fi
  sleep 2
done

# 启动 certd (原 CMD)
echo "[entrypoint-vip] starting certd ..."
exec "$@"
