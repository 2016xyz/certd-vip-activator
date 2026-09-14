#!/bin/bash
# ============================================================
# Certd VIP 版 一键安装 / 一键重装 (全新机器适用)
# 用法: bash install-certd-vip.sh
# 功能:
#   1. 检查/安装 Docker
#   2. 清理旧 certd 容器 (保留数据)
#   3. 拉取最新 VIP 镜像
#   4. 启动 + 自动激活 (plus / 永久)
#   5. 输出 访问地址 / 默认账号 / 验证命令
# 镜像: ghcr.io/2016xyz/certd-vip:latest  (GitHub Actions 自动跟上游 stable 构建)
# ============================================================
set -e

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; NC='\033[0m'
log() { echo -e "${GREEN}[certd-vip]${NC} $1"; }
err() { echo -e "${RED}[certd-vip]${NC} $1"; }

DATA_DIR="/opt/certd-vip/data"
IMAGE="ghcr.io/2016xyz/certd-vip:latest"
VIP_TYPE="${CERTD_VIP_TYPE:-plus}"

# ── 1. Docker 检查 ──
if ! command -v docker &>/dev/null; then
  log "未检测到 Docker, 自动安装..."
  curl -fsSL https://get.docker.com | bash
  systemctl enable --now docker
fi
log "Docker: $(docker --version)"

# ── 2. 清理旧容器 (数据保留) ──
if docker ps -a --format '{{.Names}}' | grep -qE '^certd$'; then
  log "发现旧 certd 容器, 停止并删除 (数据在 $DATA_DIR 保留)"
  docker rm -f certd >/dev/null 2>&1 || true
fi
mkdir -p "$DATA_DIR"

# ── 3. 拉取最新 VIP 镜像 ──
log "拉取镜像 $IMAGE ..."
for i in 1 2 3; do
  docker pull $IMAGE >/dev/null 2>&1 && break
  err "拉取失败, 重试 ($i/3)..."
  sleep 5
  [ "$i" = "3" ] && { err "镜像拉取失败, 请检查网络或 manually: docker pull $IMAGE"; exit 1; }
done

# ── 4. 启动 ──
log "启动 certd (VIP=$VIP_TYPE)..."
docker run -d --name certd --restart unless-stopped \
  -p 7001:7001 -p 7002:7002 \
  -v "$DATA_DIR:/app/data" \
  -e TZ=Asia/Shanghai \
  -e CERTD_VIP_TYPE=$VIP_TYPE \
  $IMAGE >/dev/null

log "等待启动 + 自动激活 (首次约 3 分钟)..."
sleep 45

# ── 5. 自动激活兜底 (首启 fake server pip 慢时) ──
HAS_LIC=$(docker exec certd sh -c 'node -e "
const Database=require(\"/app/node_modules/better-sqlite3\");
try{
  const db=new Database(\"/app/data/db.sqlite\",{timeout:5000});
  const lic=db.prepare(\"SELECT setting FROM sys_settings WHERE key='\\''sys.license'\\''\").get();
  const j=lic?JSON.parse(lic.setting||\"{}\"):{};
  process.stdout.write(j.license?\"1\":\"0\");
}catch(e){process.stdout.write(\"0\")}
"' 2>/dev/null || echo "0")
if [ "$HAS_LIC" != "1" ]; then
  log "license 未自动写入, 跑兜底 activate ..."
  docker exec certd node /app/tools/auto-activate.cjs 2>&1 | tail -1
  docker restart certd >/dev/null
fi

# ── 6. 等待生效 + 验证 ──
log "再等 60 秒验证..."
sleep 60
if docker logs certd 2>&1 | grep -q "授权校验成功"; then
  log "✅ VIP 激活成功: $(docker logs certd 2>&1 | grep '授权校验成功' | tail -1 | sed 's/.*- //')"
else
  err "日志未见授权成功, 最后日志:"
  docker logs certd --tail 8 2>&1 | sed 's/^/    /'
  err "可手动重试: docker exec -it certd node /app/tools/auto-activate.cjs && docker restart certd"
fi

# ── 7. 输出信息 ──
IP=$(ip route get 1.1.1.1 2>/dev/null | grep -oP 'src \K[^ ]+' | head -1 || hostname -I | awk '{print $1}')
echo ""
echo "=========================================="
log "Certd VIP 版安装完成!"
echo "=========================================="
echo ""
echo "访问地址:  http://$IP:7001  (HTTPS: https://$IP:7002)"
echo "默认账号:  admin / 123456   (首次登录强制改密)"
echo "授权状态:  后台 → 系统设置 → 授权信息 → $VIP_TYPE / 永久"
echo "数据目录:  $DATA_DIR (备份此目录即可容灾)"
echo ""
echo "常用命令:"
echo "  docker logs certd | grep 授权校验       # 验证激活"
echo "  docker restart certd                    # 重启"
echo "  docker rm -f certd && docker run ...    # 升级 (换IMAGE TAG)"
echo "  切商业版: docker rm -f certd && CLEANUP 同上 -e CERTD_VIP_TYPE=comm 重新 run"
echo ""
