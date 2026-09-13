#!/bin/bash
# certd VIP 激活一键部署（Linux shell 版）
# 用法: ./deploy.sh [certd根目录]
set -e
CERTD_DIR="${1:-.}"
PLUS_CORE="$CERTD_DIR/node_modules/@certd/plus-core/dist/index.js"

if [ ! -f "$PLUS_CORE" ]; then
  echo "[!] $PLUS_CORE 不存在，先进入 certd 目录 pnpm install"
  exit 1
fi

echo "[1/3] 备份原版 plus-core"
[ -f "$PLUS_CORE.orig" ] || cp "$PLUS_CORE" "$PLUS_CORE.orig"

echo "[2/3] 替换为 patched 版"
cp "$(dirname "$0")/../patched/plus-core-patched.js" "$PLUS_CORE"

echo "[3/3] license 写库提示"
echo "  patched 版配套公钥已内置，需配套 license:"
echo "  sqlite: UPDATE 表名 SET setting='{\"license\":\"<license_permanent.b64内容>\"}' WHERE setting_key='sys.license';"
echo "  或 docker: docker cp patched/plus-core-patched.js container:/app/node_modules/@certd/plus-core/dist/index.js"
echo "[✓] 完成，重启 certd 生效"
