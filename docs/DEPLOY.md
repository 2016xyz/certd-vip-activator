# Certd VIP 版部署文档

> 完整复现 **Certd 专业版（VIP）** 部署流程，部署完成即是 VIP 版。
> 结构与官方 certd 部署文档保持一致。
>
> **仅供安全研究与学习用途** —— 请勿用于商业生产，请支持正版 [certd](https://github.com/certd/certd)。

---

## 目录

1. [简介](#一简介)
2. [环境要求](#二环境要求)
3. [Docker 方式部署（推荐）](#三docker-方式部署推荐)
4. [宝塔 / 1Panel 方式部署](#四宝塔--1panel-方式部署)
5. [非 Docker 方式部署](#五非-docker-方式部署)
6. [开机自启与升级](#六开机自启与升级)
7. [常见问题 FAQ](#七常见问题-faq)
8. [安全与合规](#八安全与合规)

---

## 一、简介

Certd 是开源证书自动化申请+部署平台。官方镜像 `certd/certd:<tag>` 中已内置专业版（plus）框架，但功能解锁依赖远程激活服务器 `api.handfree.work` 发放的 license，未购买授权前仅提供 `free` 权限。

本仓库对 certd 授权机制（`@certd/plus-core@1.44.x`）做了完整逆向，提供**三层递进方案**：

- **方案 A（预构建镜像）**：`ghcr.io/2016xyz/certd-vip:latest` —— patched plus-core + 内置假激活服务器 + 自动激活脚本**全部烧进镜像**，`docker run` 即 VIP。
- **方案 B（自建双容器）**：官方 certd 镜像 + 独立 fake-plus-server，patched 文件以 volume 挂载。
- **方案 C（静态离线）**：`PoC/poc_selfsign*` 本地自签 key + license，完全离线。

所有方案共同点：

- ✅ 专业版（plus）全功能解锁，`isPlus()===true`，授权显示 `plus / 永久`
- ✅ 无需连接官方激活服务器，**完全离线/内网运行**
- ✅ 110+ 专业版部署插件全部可用（Baidu/CDN/多云/宝塔/1Panel/群晖等）
- ✅ license 按 **siteId 动态签发**，换机器/new install 不需手工干预

### 组件速览

| 组件 | 文件 | 作用 |
|---|---|---|
| patched plus-core | `patched/plus-core-patched.js` | 替换内置 RSA 公钥为自持公钥；禁远程打回、禁自杀定时器、禁远程覆盖 |
| fake-plus-server | `PoC/fake_plus_server.py` | 本地"激活服务器"，按 certd 实际上报的 siteId 实时签发永久 license |
| auto-activate | `docker/vip-deploy/auto-activate.cjs` | certd data 落库后自动向 fake server 申请并写 `sys.license` |
| entrypoint | `docker/vip-deploy/entrypoint-vip.sh` | 先起 fake server sidecar → auto-activate 后台 → exec certd |
| GH Actions | `.github/workflows/build-vip-image.yml` | 每天跟随上游 certd:stable 自动构建 + 推镜像 |

---

## 二、环境要求

| 项 | 要求 |
|---|---|
| 系统 | Linux x86_64 / arm64（其他需改 compose 平台即可） |
| Docker | ≥ 20.10 |
| Docker Compose | v2 插件版 或 standalone |
| 内存 | ≥ 512MB，推荐 1GB |
| 磁盘 | ≥ 2GB |
| 网络 | 仅启动时拉镜像需要外网；**运行时完全离线可用** |

支持 certd 版本：`1.40.x ~ 1.44.x`（镜像构建自动跟随，无需手动 patch）
旧版本请用 `PoC/poc_selfsign.js` 重新 patch。

---

## 三、Docker 方式部署（推荐）

### 方式 ⓪ 全自动一键安装（最推荐 · 全发行版）★NEW

**在全新 Linux 机器上一行命令搞定【Docker 安装 + 镜像拉取 + 启动 + VIP 激活 + 终态验证】：**

```bash
curl -fsSL https://raw.githubusercontent.com/2016xyz/certd-vip-activator/main/docker/vip-deploy/install-certd-vip.sh -o install.sh && sudo bash install.sh
```

国内服务器（GitHub raw 访问慢）：

```bash
git clone https://github.com/2016xyz/certd-vip-activator.git && sudo bash certd-vip-activator/docker/vip-deploy/install-certd-vip.sh
```

**脚本能力一览：**

| 步骤 | 动作 |
|---|---|
| 系统识别 | Ubuntu / Debian / CentOS / RHEL / Rocky / AlmaLinux / Fedora / openEuler / Arch 自动判定 |
| Docker 安装 | 未装自动装（优先 aliyun 镜像源加速，失败回退官方），已装跳过 |
| 基础依赖 | 自动补 curl / ca-certificates 等最小依赖 |
| 镜像双源拉取 | `ghcr.io/2016xyz/certd-vip:latest` 失败自动试 `ghcr.dockerproxy.com` |
| 容器启动 | 7001(http) / 7002(https)，`./data` 宿主化持久化 |
| 端口冲突检测 | 若被占用提示输入新端口 |
| 自动激活 | 内置 auto-activate watch → 检查 license → 兜底 → grep「授权校验成功」终态 |
| 输出访问信息 | 外网IP / 本地IP / 默认账号 / 常用命令 / 升级 / 切 comm 全集 |

**环境变量定制**：

```bash
VIP_TYPE=comm bash install-certd-vip.sh            # 默认签发 comm（商业版）
CERTD_HTTP_PORT=8001 bash install-certd-vip.sh     # 自定义 http 端口
DATA_DIR=/data/certd bash install-certd-vip.sh     # 自定义数据目录
CONTAINER_NAME=certd2 bash install-certd-vip.sh    # 多实例并存
```

**实测终端输出**（已在 Kali/Debian 环境跑通 + 服务器复现）：

```
[certd-vip] 检测到系统: Kali GNU/Linux Rolling
[certd-vip] Docker 已安装: 28.5.2+dfsg4
[certd-vip] 镜像拉取完成
[certd-vip] 启动 certd (VIP=plus, http=7001, https=7002)...
[certd-vip] ✅ VIP 激活: 授权校验成功：plus，到期时间：永久
访问地址:
  外网:  http://43.133.237.180:7001
  本地:  http://192.168.12.231:7001
默认账号:  admin / 123456   (首次登录强制改密)
授权状态:  后台 → 系统设置 → 授权信息 → plus / 永久
数据目录:  /opt/certd-vip/data (备份此目录即可容灾)
```

### 方式 A：预构建 VIP 镜像一键部署（最少配置，手动版）

```bash
mkdir -p /opt/certd-vip/data && docker run -d \
  --name certd --restart unless-stopped \
  -p 7001:7001 -p 7002:7002 \
  -v /opt/certd-vip/data:/app/data \
  -e TZ=Asia/Shanghai \
  -e CERTD_VIP_TYPE=plus \
  ghcr.io/2016xyz/certd-vip:latest

# 等待 ~100 秒后验证：
docker logs certd | grep 授权校验
# → 授权校验成功：plus，到期时间：永久
```

打开 `http://<服务器IP>:7001`（HTTP）或 `https://...:7002`（HTTPS）。默认 `admin / 123456`，首次登录强制改密。
后台「系统设置 → 授权信息」即显示 **plus / 永久**。

**遇到首启 race（未出现上述日志）？** 跑一行兜底：
```bash
docker exec -it certd node /app/tools/auto-activate.cjs && docker restart certd
```

### 方式 B：docker compose（推荐持久化）

```bash
mkdir -p /opt/certd-vip/data && cd /opt/certd-vip && cat > docker-compose.yaml <<'EOF'
version: '3.3'
services:
  certd:
    image: ghcr.io/2016xyz/certd-vip:latest     # 或 :stable / :1.44.4
    container_name: certd
    restart: unless-stopped
    ports:
      - "7001:7001"
      - "7002:7002"
    volumes:
      - ./data:/app/data
    environment:
      - TZ=Asia/Shanghai
      - CERTD_VIP_TYPE=plus      # plus / comm
EOF
docker compose up -d
```

### 方式 C：本仓库自建双容器（key 在你手上，自持最安全）

```bash
git clone https://github.com/2016xyz/certd-vip-activator.git /tmp/act
bash /tmp/act/PoC/deploy.sh /opt/certd-vip
```

部署 = `certd`（官方镜像）+ `certd-fake-plus-server`（Python 动态签发），
patched 文件以 volume 形式挂进 certd 容器。编排见
[docker/vip-deploy/docker-compose.yaml](docker/vip-deploy/docker-compose.yaml)。

### 验证激活

```bash
# ① 启动日志
docker logs certd | grep 授权校验     # → 授权校验成功：plus，到期时间：永久

# ② 容器内检查 plus-core
docker exec certd node -e "
import('/app/node_modules/@certd/plus-core/dist/index.js').then(m=>{
  console.log('isPlus:', m.isPlus());       // true
  console.log('vipType:', m.getVipType());  // plus
  console.log('expireTime:', m.getExpiresTime()); // -1
});"

# ③ 接口验证
TOKEN=$(curl -s -X POST http://127.0.0.1:7001/api/login \
  -H 'Content-Type:application/json' \
  -d '{"username":"admin","password":"123456"}' | python3 -c "import sys,json;print(json.load(sys.stdin)['data']['token'])")
curl -s -X POST http://127.0.0.1:7001/api/sys/plus/getVipTrial \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d '{"vipType":"plus"}'      # → {"code":0,"data":{"duration":-1}}
```

### 添加第一个流水线

进入「流水线」→ 新建 → 选 ACME 账号、DnsProvider、部署插件（110+ 种，全解锁）。VIP 卡片标记可以正常编辑保存即生效。

---

## 四、宝塔 / 1Panel 方式部署

### 宝塔面板

1. 宝塔 → Docker → 编排 → 添加编排，名 `certd-vip`
2. 粘贴 **方式 B** yaml，部署
3. 按 **验证激活** 验证

### 1Panel

1. 1Panel → 容器 → 编排 → 创建编排，粘贴 yaml 部署
2. 同上验证

---

## 五、非 Docker 方式部署

### 5.1 源码方式

```bash
# 完成官方源码安装 (pnpm install + pnpm run build) 之后:
cd <certd 源码目录>
# patch plus-core (备份原版)
cp -b /path/to/patched/plus-core-patched.js node_modules/@certd/plus-core/dist/index.js
# 指向本地假激活服务器
echo "PLUS_SERVER_BASE_URL=http://127.0.0.1:11007" >> .env
# 启动 fake-plus-server (独立进程)
nohup python3 /path/to/PoC/fake_plus_server.py &
# 启动 certd
pnpm run dev
```

### 5.2 已购买官方授权但连服务器困难

直接使用本仓库 fake_plus_server 本地化即可（与真激活完全等价，key 自持更安全）。

### 5.3 完全离线静态签发（无 fake server）

```bash
node PoC/poc_selfsign.js              # 生成 selfsign_key.pem + patch
node PoC/poc_selfsign_v2.js           # PKCS#1 格式校正
node PoC/poc_selfsign_comm.js         # （可选）商业版
node PoC/verify_permanent.mjs         # 验证: verified:true / expire:-1
# license 写库 (subjectId 必须与你 certd 实例 siteId 一致)
sqlite3 data/db.sqlite "UPDATE sys_settings SET setting='{\"license\":\"<b64>\"}' WHERE key='sys.license';"
```

---

## 六、开机自启与升级

### 开机自启

compose 已设 `restart: unless-stopped`，宿主机 `systemctl enable docker` 即自动拉起。

### 手动升级

```bash
cd /opt/certd-vip
docker pull ghcr.io/2016xyz/certd-vip:latest
docker rm -f certd
docker run -d --name certd --restart unless-stopped \
  -p 7001:7001 -p 7002:7002 -v ./data:/app/data \
  -e CERTD_VIP_TYPE=plus \
  ghcr.io/2016xyz/certd-vip:latest
# 验证
docker logs certd | grep 授权校验
```

### 数据持久化

`./data:/app/data` 里是 sqlite DB + SSL 证书 + tmp 文件，备份该目录即可容灾。
**务必确认数据卷已挂宿主**，否则容器删除时 siteId 重建，fake server 会自动重签（无数据丢失，但建议还是挂宿主目录）。

### Watchtower 自动升级（不推荐开）

官方 compose 末尾的 watchtower 配置对 VIP 版**不建议开启**——
certd 版本升级可能更新 plus-core 结构，导致 patched 失效。本仓库 Actions 会自动重新构建镜像，手动升级即可。

---

## 七、常见问题 FAQ

<details>
<summary>❓ 首次启动一定秒激活？</summary>
不是。fake-plus-server 首次启动会 `pip install cryptography`（约 20 秒），比 certd 生产启动还慢。若看过日志只有 free：

```bash
docker exec -it certd node /app/tools/auto-activate.cjs && docker restart certd
```
新版本镜像在 entrypoint 里内置了 auto-activate 后台 watch 后台线程，通常 2-3 分钟自动好。
</details>

<details>
<summary>❓ 启动报 <code>Cannot find module '@certd/plus-core'</code></summary>
用 `docker exec certd find / -name plus-core -type d | head -3` 查实际位置，调整 volume 挂载路径。
</details>

<details>
<summary>❓ 授权面板仍显示「free」？</summary>
1. `docker exec certd grep -c 'license ok' /app/node_modules/@certd/plus-core/dist/index.js` → `1`；(not found = patch 未绑)
2. `docker exec certd wget -qO- --post-data='{}' http://127.0.0.1:11007/api/activation/app/get` → `{"ok":true}`；
3. 手动激活: `docker exec -it certd node /app/tools/auto-activate.cjs && docker restart certd`
</details>

<details>
<summary>❓ 启动时日志显示 <code>验证配置失败</code>？</summary>
first-boot 时 fake server 未就绪, 是正常现象，下一周期校验（或手动激活）会转 OK。
</details>

<details>
<summary>❓ 如果想切商业版 (comm)</summary>
`docker rm -f certd && docker run ... -e CERTD_VIP_TYPE=comm ...` 重启；license 按 env 即时签发。
</details>

<details>
<summary>❓ 已有官方授权但 unable to reach server？</summary>
直接用本仓库 fake_plus_server 完全本地化（见 5.2），效果与真激活完全等价，无外网依赖。
</details>

---

## 八、安全与合规

1. 本仓库内容基于 **npm 公开包** `@certd/plus-core@1.44.4` 的逆向分析，未使用任何零日漏洞。
2. 仅供**自部署实例**与自己拥有完整管理权的环境使用。
3. 生产环境请购买官方授权（[certd 官网](https://certd.docmirror.cn/)），支持高质量开源项目。
4. 若 certd 官方认为本仓库存在侵权，请通过 GitHub Issue 联系，我们会及时停止分发相关 patch 文件。
5. `PoC/poc_selfsign.js` 生成的 `selfsign_key.pem` 属于你个人 key，**仅本地保存，切勿上传公开仓库**。
