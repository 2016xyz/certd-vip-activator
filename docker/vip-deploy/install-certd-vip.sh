#!/bin/bash
# ============================================================
# Certd VIP 版 — 全平台一键安装 (CentOS/RHEL/Rocky/AlmaLinux/Ubuntu/Debian/等等)
# ============================================================
# 用法
#   bash install-certd-vip.sh                      安装/重装 (保留数据)
#   curl -fsSL <raw-url>/install-certd-vip.sh | bash   远程一键 (推荐)
#   VIP_TYPE=comm bash install-certd-vip.sh             安装商业版
#   CERTD_HTTP_PORT=7001  bash install-certd-vip.sh                自定义端口
#   DATA_DIR=/data/certd bash install-certd-vip.sh      自定义数据目录
# 功能:
#   - 自动识别 OS (Ubuntu/Debian/CentOS/RHEL/Rocky/Alma/Fedora/openEuler等)
#   - 自动安装 Docker + Docker Compose (源适配国内网络)
#   - 清理旧 certd 容器 (数据保留)
#   - 拉取 VIP 镜像 → 启动 → 自动激活 → 输出访问信息
# ============================================================
set -e

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; NC='\033[0m'
log()  { echo -e "${GREEN}[certd-vip]${NC} $1"; }
warn() { echo -e "${YELLOW}[certd-vip]${NC} $1"; }
err()  { echo -e "${RED}[certd-vip]${NC} $1"; }

DATA_DIR="${DATA_DIR:-/opt/certd-vip/data}"
HTTP_PORT="${CERTD_HTTP_PORT:-7001}"
# 兼容: 如果环境变量 PORT 显式存在(如 heroku 等场景), 且 CERTD_HTTP_PORT 未设, 用 PORT
if [ -n "$CERTD_HTTP_PORT" ]; then HTTP_PORT="$CERTD_HTTP_PORT"; fi
HTTPS_PORT="${CERTD_HTTPS_PORT:-7002}"
IMAGE="${IMAGE:-ghcr.io/2016xyz/certd-vip:latest}"
VIP_TYPE="${VIP_TYPE:-plus}"
CONTAINER_NAME="${CONTAINER_NAME:-certd}"
SUDO=""
[ "$(id -u)" != "0" ] && command -v sudo >/dev/null 2>&1 && SUDO="sudo"

# ============================================================
# 1. 系统检测
# ============================================================
detect_os() {
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS="$ID"; OS_VER="${VERSION_ID:-}"
    if [ "${VERSION% (*}" = "" ]; then :; fi
  elif [ -f /etc/redhat-release ]; then
    OS="rhel"
  elif [ -f /etc/debian_version ]; then
    OS="debian"
  elif [ -f /etc/centos-release ]; then
    OS="centos"
  else
    OS="unknown"
  fi
  log "检测到系统: ${PRETTY_NAME:-$OS}"
}
detect_os

# ============================================================
# 2. 安装依赖 (curl + wget, 有些 minimal 系统没有)
# ============================================================
install_pkgs() {
  local manager pkgs="curl ca-certificates"
  if [ -x "$(command -v apt-get)" ]; then
    $SUDO apt-get update -qq 2>/dev/null || true
    $SUDO apt-get install -y -qq curl ca-certificates gnupg lsb-release 2>/dev/null
  elif [ -x "$(command -v dnf)" ]; then
    $SUDO dnf install -y curl ca-certificates 2>/dev/null
  elif [ -x "$(command -v yum)" ]; then
    $SUDO yum install -y curl ca-certificates 2>/dev/null
  elif [ -x "$(command -v zypper)" ]; then
    $SUDO zypper install -y curl ca-certificates 2>/dev/null
  elif [ -x "$(command -v apk)" ]; then
    $SUDO apk add --no-cache curl ca-certificates bash 2>/dev/null
  elif [ -x "$(command -v pacman)" ]; then
    $SUDO pacman -Sy --noconfirm curl ca-certificates 2>/dev/null
  fi
  log "基础依赖安装完成"
}

install_pkgs

# ============================================================
# 3. 安装 Docker (如果未装)
# ============================================================
install_docker() {
  log "Docker 未安装, 开始安装..."
  case "$OS" in
    ubuntu|debian)
      $SUDO apt-get update -qq 2>/dev/null || true
      $SUDO apt-get install -y -qq ca-certificates curl gnupg lsb-release 2>/dev/null
      $SUDO install -m 0755 -d /etc/apt/keyrings
      # 优先国内镜像源 (阿里云), 失败回退官方
      if curl -fsSL https://mirrors.aliyun.com/docker-ce/linux/${OS}/gpg | $SUDO gpg --dearmor -o /etc/apt/keyrings/docker.gpg 2>/dev/null; then
        DOCKER_APT_MIRROR="https://mirrors.aliyun.com/docker-ce/linux/${OS}"
      else
        curl -fsSL https://download.docker.com/linux/${OS}/gpg | $SUDO gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        DOCKER_APT_MIRROR="https://download.docker.com/linux/${OS}"
      fi
      $SUDO chmod a+r /etc/apt/keyrings/docker.gpg
      echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] $DOCKER_APT_MIRROR $(lsb_release -cs) stable" \
        | $SUDO tee /etc/apt/sources.list.d/docker.list >/dev/null
      $SUDO apt-get update -qq 2>/dev/null || true
      $SUDO apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-compose-plugin
      ;;
    centos|rhel|rocky|almalinux|fedora)
      DOCKER_YUM_MIRROR="https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo"
      [ -x "$(command -v dnf)" ] && PKG_MGR="dnf" || PKG_MGR="yum"
      $SUDO $PKG_MGR install -y yum-utils 2>/dev/null || true
      $SUDO $PKG_MGR config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo 2>/dev/null || true
      $SUDO $PKG_MGR install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin 2>/dev/null \
        || { curl -fsSL $DOCKER_YUM_MIRROR -o /etc/yum.repos.d/docker-ce.repo; $SUDO $PKG_MGR install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin; }
      ;;
    *)
      # 其他系统用官方一键脚本 (支持绝大多数发行版)
      curl -fsSL https://get.docker.com | $SUDO bash
      ;;
  esac
  $SUDO systemctl enable --now docker 2>/dev/null || true
  $SUDO systemctl start docker 2>/dev/null || true
  sleep 2
  [ "$(docker info >/dev/null 2>&1; echo $?)" = "0" ] \
    && log "Docker 安装成功: $(docker --version 2>/dev/null)" \
    || { err "Docker 启动失败, 请手动检查: systemctl status docker"; exit 1; }
}

if ! command -v docker &>/dev/null; then
  install_docker
else
  log "Docker 已安装: $(docker --version 2>/dev/null | awk '{print $3}' | tr -d ',')"
fi

# ============================================================
# 4. 清理旧容器 (数据保留)
# ============================================================
if $SUDO docker ps -a --format '{{.Names}}' 2>/dev/null | grep -qE "^${CONTAINER_NAME}$"; then
  log "发现旧 ${CONTAINER_NAME} 容器, 停止并删除 (数据在 $DATA_DIR 保留)"
  $SUDO docker rm -f ${CONTAINER_NAME} >/dev/null 2>&1 || true
fi
$SUDO mkdir -p "$DATA_DIR"

# ============================================================
# 5. 拉取 VIP 镜像
# ============================================================
log "拉取镜像 $IMAGE ..."
PULL_OK=false
for MIRROR in "ghcr.io/2016xyz/certd-vip:latest" "ghcr.dockerproxy.com/2016xyz/certd-vip:latest"; do
  if $SUDO docker pull "$MIRROR" >/dev/null 2>&1; then
    # 统一 tag
    $SUDO docker tag "$MIRROR" "$IMAGE" >/dev/null 2>&1 || true
    PULL_OK=true
    break
  fi
done
if [ "$PULL_OK" != "true" ]; then
  err "镜像拉取失败, 请检查网络或手动: docker pull $IMAGE"
  exit 1
fi
log "镜像拉取完成"

# ============================================================
# 5. 启动 (含端口占用检测)
# ============================================================
check_port() {
  local port="$1"
  if command -v ss >/dev/null 2>&1; then
    if $SUDO ss -tlnp 2>/dev/null | grep -q ":${port} "; then
      return 1
    fi
  elif command -v netstat >/dev/null 2>&1; then
    if $SUDO netstat -tln 2>/dev/null | grep -q ":${port} "; then return 1; fi
  fi
  return 0
}

if ! check_port "$HTTP_PORT"; then
  err "端口 $HTTP_PORT 已被占用"
  read -p "输入其他端口 (回车采用默认 ${HTTP_PORT}): " NEWPORT
  [ -n "$NEWPORT" ] && HTTP_PORT=$NEWPORT 2>/dev/null || true
  [ -n "$NEWPORT" ] || { err "端口冲突, 放弃"; exit 1; }
fi

log "启动 ${CONTAINER_NAME} (VIP=$VIP_TYPE, http=$HTTP_PORT, https=$HTTPS_PORT)..."
$SUDO docker run -d \
  --name ${CONTAINER_NAME} \
  --restart unless-stopped \
  -p ${HTTP_PORT}:7001 \
  -p ${HTTPS_PORT}:7002 \
  -v "${DATA_DIR}:/app/data" \
  -e TZ=Asia/Shanghai \
  -e CERTD_VIP_TYPE=$VIP_TYPE \
  $IMAGE >/dev/null

log "容器已启动, 等待首次启动激活 (约 2-3 分钟)..."

# ============================================================
# 6. 激活兜底: 等 license 写入, 未写入则手动触发
# ============================================================
check_license() {
  $SUDO docker exec ${CONTAINER_NAME} node -e "
    const Database=require('/app/node_modules/better-sqlite3');
    function check(){
      try{
        const db=new Database('/app/data/db.sqlite',{timeout:5000});
        const lic=db.prepare(\"SELECT setting FROM sys_settings WHERE key='sys.license'\").get();
        const j=lic?JSON.parse(lic.setting||'{}'):{};
        process.stdout.write(j.license?'1':'0');
      }catch(e){process.stdout.write('0')}
    }
    check();" 2>/dev/null || echo "0"
}

for i in $(seq 1 30); do
  sleep 10
  LIC=$(check_license)
  if [ "$LIC" = "1" ]; then
    log " license 已自动写入 ✓"
    break
  fi
  if [ "$i" = "30" ]; then
    warn "未自动写入 license, 执行兜底激活..."
    $SUDO docker exec ${CONTAINER_NAME} node /app/tools/auto-activate.cjs 2>&1 | tail -1 || true
    $SUDO docker restart ${CONTAINER_NAME} >/dev/null
    sleep 45
    break
  fi
done

# ============================================================
# 6. 验证
# ============================================================
sleep 30
if $SUDO docker logs ${CONTAINER_NAME} 2>&1 | grep -q "授权校验成功"; then
  log "✅ VIP 激活: $($SUDO docker logs ${CONTAINER_NAME} 2>&1 | grep '授权校验成功' | tail -1 | sed 's/.*- //')"
else
  err "日志未见授权成功, 日志尾部:"
  $SUDO docker logs ${CONTAINER_NAME} --tail 6 2>&1 | sed 's/^/    /'
  err "手动重试: docker exec -it ${CONTAINER_NAME} node /app/tools/auto-activate.cjs && docker restart ${CONTAINER_NAME}"
fi

# ============================================================
# 7. 输出信息
# ============================================================
LOCAL_IP=$(ip route get 1.1.1.1 2>/dev/null | grep -oP 'src \K[^ ]+' | head -1) \
  || LOCAL_IP=$(hostname -I 2>/dev/null | awk '{print $1}') \
  || LOCAL_IP="127.0.0.1"
PUBLIC_IP=$(curl -s --max-time 5 https://api.ipify.org 2>/dev/null || curl -s --max-time 5 checkip.amazonaws.com 2>/dev/null || true)

echo ""
echo "=========================================="
log "Certd VIP 版安装完成!"
echo "=========================================="
echo ""
echo "访问地址:"
[ -n "$PUBLIC_IP" ] && echo -e "  ${GREEN}外网:${NC}  http://$PUBLIC_IP:$HTTP_PORT"
echo -e "  ${GREEN}本地:${NC}  http://$LOCAL_IP:$HTTP_PORT"
echo ""
echo "默认账号:  admin / 123456   (首次登录强制改密)"
echo "授权状态:  后台 → 系统设置 → 授权信息 → $VIP_TYPE / 永久"
echo "数据目录:  $DATA_DIR (备份此目录即可容灾)"
echo ""
echo "常用命令:"
echo "  docker logs ${CONTAINER_NAME} | grep 授权校验     # 验证 VIP"
echo "  docker restart ${CONTAINER_NAME}                 # 重启"
echo "  docker pull $IMAGE && docker rm -f certd && 重新运行本脚本     # 升级"
echo "  docker rm -f certd && 重跑: docker run -d --name certd --restart unless-stopped -p 7001:7001 -p 7002:7002 -v $DATA_DIR:/app/data -e CERTD_VIP_TYPE=comm $IMAGE  # 切商业版"
echo ""
