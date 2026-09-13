#!/bin/bash
# certd VIP 版 一键部署激活脚本
# ============================================================
# 用法: bash deploy.sh [安装目录, 默认 /opt/certd-vip]
# 流程:
#   1. 检查 Docker + Docker Compose
#   2. 复制本仓库 patched + PoC + compose 到安装目录
#   3. docker compose up -d (certd + fake-plus-server)
#   4. 等待 certd 就绪, 自动从 fake-plus-server 拉永久 license 写入 sqlite
#   5. 重启 certd 完成激活
# 结果: 打开 http://IP:7001 → 授权信息显示 "plus, 永久"
set -e

INSTALL_DIR="${1:-/opt/certd-vip}"
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE="${CERTD_IMAGE:-certd/certd:latest}"
VIP_TYPE="${CERTD_VIP_TYPE:-plus}"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error(){ echo -e "${RED}[ERROR]${NC} $1"; }

# ── 1. 基础环境 ──────────────────────────────
check_docker() {
  if ! command -v docker &>/dev/null; then
    log_error "请先安装 Docker: curl -fsSL https://get.docker.com | bash"
    exit 1
  fi
  if docker compose version &>/dev/null; then
    COMPOSE_CMD="docker compose"
  elif docker-compose version &>/dev/null; then
    COMPOSE_CMD="docker-compose"
  else
    log_error "请先安装 Docker Compose"
    exit 1
  fi
}
check_docker

# ── 2. 复制安装目录 ─────────────────────────────
log_info "准备安装目录 $INSTALL_DIR"
mkdir -p "$INSTALL_DIR/patched" "$INSTALL_DIR/PoC" "$INSTALL_DIR/data"
cp "$SRC/patched/plus-core-patched.js"     "$INSTALL_DIR/patched/"
cp "$SRC/patched/selfsign_key.pem"         "$INSTALL_DIR/patched/"
cp "$SRC/PoC/fake_plus_server.py"          "$INSTALL_DIR/PoC/"
cp "$SRC/docker/vip-deploy/docker-compose.yaml" "$INSTALL_DIR/docker-compose.yaml"
# 占位 data 目录避免 docker 作为 root 建文件后 volume 生命周期不可控
chmod -R 755 "$INSTALL_DIR"

# ── 3. 启动 certd + fake server ──────────────────
log_info "启动 certd + fake-plus-server"
cd "$INSTALL_DIR"
$COMPOSE_CMD down 2>/dev/null || true
# restore: 若已有旧数据, 尽力保留
$COMPOSE_CMD up -d

# ── 4. 等 certd 就绪 → 动态拉 license 写库 ─────────
log_info "等待 certd 启动 (最多 120s)..."
for i in $(seq 1 24); do
  if docker exec certd sh -c 'test -f /app/data/db.sqlite' 2>/dev/null; then break; fi
  sleep 5
done

log_info "向 fake-plus-server 请求本站 license 并写库"
docker exec certd node -e "
(async()=>{
  const Database=require('better-sqlite3');
  const db=new Database('/app/data/db.sqlite');
  let siteId;
  for(let i=0;i<10;i++){
    const row=db.prepare(\"SELECT setting FROM sys_settings WHERE key='sys.install'\").get();
    if(row&&JSON.parse(row.setting).siteId){siteId=JSON.parse(row.setting).siteId;break;}
    await new Promise(r=>setTimeout(r,2000));
  }
  if(!siteId){console.error('未等到 siteId');process.exit(1);}
  console.log('siteId:', siteId);
  const r=await fetch('http://certd-fake-plus-server:11007/api/activation/subject/register',{
    method:'POST',headers:{'Content-Type':'application/json'},
    body:JSON.stringify({appKey:'kQth6FHM71IPV3qdWc',subjectId:siteId,installTime:Date.now()})});
  const j=await r.json();
  if(j.code!==0)throw new Error('fake server 返回异常:'+JSON.stringify(j));
  db.prepare(\"INSERT INTO sys_settings (key,title,setting,access) VALUES ('sys.license','授权许可信息',?, 'private') \"
    + \"ON CONFLICT(key) DO UPDATE SET setting=excluded.setting\")
    .run(JSON.stringify({license:j.data.license}));
  console.log('✓ license 已写库 (vipType: plus, 永久)');
})().catch(e=>{console.error('ERR',e.message);process.exit(1)});
" || { log_error "license 写库失败"; exit 1; }

# ── 5. 重启 certd 完成激活 ────────────────────────
log_info "重启 certd 完成激活"
docker restart certd > /dev/null
sleep 30

# ── 6. 验证 ────────────────────────────────
log_info "激活状态校验"
docker logs certd --since 1m 2>&1 | grep -E "授权校验成功" && \
  log_info "✓ VIP 激活成功" || log_warn "未见授权成功日志, 请检查 fake-plus-server 日志: docker logs certd-fake-plus-server"

echo ""
echo "=========================================="
log_info "部署完成!"
echo "=========================================="
echo "访问地址: http://$(hostname -I | awk '{print $1}'):7001"
echo "默认账号: admin / 123456 (首次登录请改密)"
echo ""
echo "授权面板路径: 系统设置 → 授权信息 → 应显示 plus / 永久"
echo ""
echo "常用命令:"
echo "  cd $INSTALL_DIR"
echo "  $COMPOSE_CMD logs -f                          # 查看日志"
echo "  $COMPOSE_CMD restart                          # 重启"
echo "  docker restart certd-fake-plus-server         # 重启激活服务器"
echo ""
