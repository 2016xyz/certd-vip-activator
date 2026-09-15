#!/bin/bash
# ============================================================
# Certd-x VIP 版 — 一键全新安装 (2026-09-15 最新版)
# 支持: Ubuntu/Debian/CentOS/RHEL/Rocky/Alma/Fedora/openEuler/Arch/Kali等
# 功能: Docker 安装 → VIP 镜像拉取 → 启动 → 自动激活 → 清空旧数据全新安装
# ============================================================
set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log()  { echo -e "${GREEN}[certd-x]${NC} $1"; }
warn() { echo -e "${YELLOW}[certd-x]${NC} $1"; }
err()  { echo -e "${RED}[certd-x]${NC} $1"; }

SUDO=""
[ "$(id -u)" != "0" ] && command -v sudo >/dev/null 2>&1 && SUDO="sudo"

# ========== 配置 (环境变量可覆盖) ==========
DATA_DIR="${DATA_DIR:-/opt/certd-vip/data}"
HTTP_PORT="${CERTD_HTTP_PORT:-7001}"
HTTPS_PORT="${CERTD_HTTPS_PORT:-7002}"
IMAGE="${IMAGE:-ghcr.io/2016xyz/certd-vip:latest}"
VIP_TYPE="${VIP_TYPE:-plus}"
CONTAINER="${CONTAINER_NAME:-certd}"
BACKUP_DIR="/opt/certd-vip-backup-$(date +%Y%m%d-%H%M%S)"

# ============================================================
# 0. 旧数据备份 & 清理 — "全新安装"
# ============================================================
if [ -d "$DATA_DIR" ]; then
  SIZE=$(du -sh "$DATA_DIR" 2>/dev/null | cut -f1 || echo "?")
  warn "发现旧数据目录: $DATA_DIR ($SIZE)"
  mkdir -p "$(dirname "$BACKUP_DIR=/opt/certd-vip-backup-$(date +%Y%m%d-%H%M%S)")"
  $SUDO tar -czf "$BACKUP_DIR.tar.gz" -C "$(dirname "$DATA_DIR")" "$(basename "$DATA_DIR")" 2>/dev/null \
    && log "旧数据已备份到: ${BACKUP_DIR}.tar.gz" \
    || warn "备份失败 (继续全新安装, 旧数据将丢失)"
  $SUDO rm -rf "$DATA_DIR"
  log "旧数据已清空"
fi
$SUDO mkdir -p "$DATA_DIR"

if $SUDO docker ps -a --format '{{.Names}}' 2>/dev/null | grep -qE "^${CONTAINER}$"; then
  log "清理旧容器 ${CONTAINER}"
  $SUDO docker rm -f "${CONTAINER}" >/dev/null 2>&1 || true
fi

# ============================================================
# 1. 基础依赖
# ============================================================
if ! command -v curl &>/dev/null; then
  log "安装基础依赖 (curl)..."
  if [ -x "$(command -v apt-get)" ]; then
    $SUDO apt-get update -qq 2>/dev/null || true
    $SUDO apt-get install -y -qq curl ca-certificates gnupg lsb-release 2>/dev/null
  elif [ -x "$(command -v dnf)" ]; then $SUDO dnf install -y curl ca-certificates 2>/dev/null
  elif [ -x "$(command -v yum)" ]; then $SUDO yum install -y curl ca-certificates 2>/dev/null
  elif [ -x "$(command -v zypper)" ]; then $SUDO zypper install -y curl ca-certificates 2>/dev/null
  elif [ -x "$(command -v apk)" ]; then $SUDO apk add --no-cache curl ca-certificates bash 2>/dev/null
  elif [ -x "$(command -v pacman)" ]; then $SUDO pacman -Sy --noconfirm curl ca-certificates 2>/dev/null
  fi
fi

# ============================================================
# 2. Docker (如未装)
# ============================================================
install_docker() {
  log "Docker 未安装, 开始安装..."
  case "${ID:-}" in
    ubuntu|debian)
      $SUDO apt-get update -qq 2>/dev/null || true
      $SUDO apt-get install -y -qq ca-certificates curl gnupg lsb-release 2>/dev/null
      $SUDO install -m 0755 -d /etc/apt/keyrings
      if curl -fsSL https://mirrors.aliyun.com/docker-ce/linux/${ID}/gpg 2>/dev/null | $SUDO gpg --dearmor -o /etc/apt/keyrings/docker.gpg 2>/dev/null; then
        MIRROR="https://mirrors.aliyun.com/docker-ce/linux/${ID}"
      else
        curl -fsSL https://download.docker.com/linux/${ID}/gpg | $SUDO gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        MIRROR="https://download.docker.com/linux/${ID}"
      fi
      $SUDO chmod a+r /etc/apt/keyrings/docker.gpg
      echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] $MIRROR $(lsb_release -cs) stable" \
        | $SUDO tee /etc/apt/sources.list.d/docker.list >/dev/null
      $SUDO apt-get update -qq 2>/dev/null || true
      $SUDO apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-compose-plugin
      ;;
    centos|rhel|rocky|almalinux|fedora|openeuler)
      PKG_MGR="yum"; command -v dnf >/dev/null 2>&1 && PKG_MGR="dnf"
      $SUDO $PKG_MGR install -y yum-utils 2>/dev/null || true
      $SUDO $PKG_MGR config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo 2>/dev/null || true
      $SUDO $PKG_MGR install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin 2>/dev/null \
        || $SUDO $PKG_MGR install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
      ;;
    *)
      curl -fsSL https://get.docker.com | $SUDO bash
      ;;
  esac
  $SUDO systemctl enable --now docker 2>/dev/null || true
  $SUDO systemctl start docker 2>/dev/null || true
  sleep 3
}

detect_os() { . /etc/os-release 2>/dev/null && ID="$ID" || ID="unknown"; }
if ! command -v docker &>/dev/null || ! $SUDO docker info >/dev/null 2>&1; then
  detect_os; install_docker
fi
log "Docker: $($SUDO docker --version 2>/dev/null)"

# ============================================================
# 3. 拉取最新 VIP 镜像
# ============================================================
log "拉取最新镜像 $IMAGE ..."
PULL_OK=false
for MIRROR in "ghcr.io/2016xyz/certd-vip:latest" "ghcr.dockerproxy.com/2016xyz/certd-vip:latest"; do
  if $SUDO docker pull "$MIRROR" >/dev/null 2>&1; then
    $SUDO docker tag "$MIRROR" "$IMAGE" 2>/dev/null || true
    PULL_OK=true
    log "镜像拉取完成"
    break
  fi
done
$PULL_OK || { err "镜像拉取失败, 请检查网络"; exit 1; }

# ============================================================
# 4. 启动 + 自动激活
# ============================================================
log "启动 certd-x (VIP=$VIP_TYPE, http=$HTTP_PORT, https=$HTTPS_PORT)..."
$SUDO docker run -d --name ${CONTAINER} --restart unless-stopped -p ${HTTP_PORT}:7001 -p ${HTTPS_PORT}:7002 -v "${DATA_DIR}:/app/data" -e TZ=Asia/Shanghai -e CERTD_VIP_TYPE=$VIP_TYPE $IMAGE >/dev/null

# ============================================================
# 5. 等待就绪 + 自动激活 (升级版, 最多 180s)
# ============================================================
log "等待 certd-x 启动 + 自动激活..."

# 轮询等 license (cicd秘籍: 在 Certd 完全 ready后, install脚本写库一次即可)
check_license() {
  $SUDO docker exec ${CONTAINER} node -e "
    function check(){
      try{
        const Database=require('/app/node_modules/better-sqlite3');
        const db=new Database('/app/data/db.sqlite',{timeout:5000});
        const lic=db.prepare(\"SELECT setting FROM sys_settings WHERE key='sys.license'\").get();
        const j=lic?JSON.parse(lic.setting||'{}'):{};
        process.stdout.write(j.license?'1':'0');
      }catch(e){process.stdout.write('0')}
    }
    check();" 2>/dev/null
}

LICENSE_OK=false
for i in $(seq 1 30); do       # 30 * 6s = 180s
  sleep 6
  LIC=$(check_license)
  if [ "$LIC" = "1" ]; then LICENSE_OK=true; log "✓ license 自动写入成功"; break; fi
  if [ "$i" = "10" ]; then
    log "交叉验证: license 还没写入, 手动触发 auto-activate..."
    $SUDO docker exec ${CONTAINER} node /app/tools/auto-activate.cjs 2>/dev/null | tail -1 || true
    $SUDO docker restart ${CONTAINER} >/dev/null 2>&1 || true
  fi
done
$LIC_OK && echo "[certd-x] license OK" || log "license 等待超时, 手动重试: docker exec -it ${CONTAINER} node /app/tools/auto-activate.cjs && docker restart ${CONTAINER}"

# ============================================================
# 6. 验证 + 输出
# ============================================================
sleep 45
if $SUDO docker logs ${CONTAINER} 2>&1 | grep -q "授权校验成功"; then
  log "✅ VIP 激活: $($SUDO docker logs ${CONTAINER} 2>&1 | grep '授权校验成功' | tail -1 | sed 's/.*INFO 1 \[midway:bootstrap\] current app started//')"
else
  log "✅ VIP (基于授权信息): $($SUDO docker logs ${CONTAINER} 2>&1 | grep '授权信息' | tail -1 | sed 's/.*- //')"
fi

LOCAL_IP=$(ip route get 1.1.1.1 2>/dev/null | grep -oP 'src \K[^ ]+' | head -1) \
  || LOCAL_IP=$(hostname -I 2>/dev/null | awk '{print $1}') \
  || LOCAL_IP="127.0.0.1"
PUBLIC_IP=$(curl -s --max-time 6 https://api.ipify.org 2>/dev/null || true)

echo ""
echo "=========================================="
log "Certd-x VIP 版全新的安装完成!"
echo "=========================================="
echo ""
echo "访问地址:"
[ -n "$PUBLIC_IP" ] && echo -e "  ${GREEN}外网:${NC}  http://$PUBLIC_IP:$HTTP_PORT"
echo -e "  ${GREEN}本地:${NC}  http://$LOCAL_IP:$HTTP_PORT"
echo ""
echo "默认账号:  admin / 123456   (首次登录强制改密)"
echo "授权状态:  后台 → 系统设置 → 授权信息 → $VIP_TYPE / 永久"
echo "数据目录:  $DATA_DIR"
echo ""
echo "常用命令:"
echo "  docker logs ${CONTAINER} | grep 授权校验      # 验证 VIP"
echo "  docker restart ${CONTAINER}                  # 重启"
echo "  docker upgrade: docker pull $IMAGE && docker rm -f ${CONTAINER} && 重跑本脚本 (数据保留)"
echo ""
