# Certd VIP 终身激活工具

> 完整利用 certd（开源证书自动化平台）授权体系漏洞的激活工具链 + **自动构建 VIP 镜像流水线**。
> 支持 4 种模式：**① 预构建镜像一键部署（推荐）** ② 既有实例打补丁 ③ 静态签发 ④ 白嫖官方试用。
>
> **仅供安全研究与学习用途** —— 请勿用于商业生产，请支持正版 [certd](https://github.com/certd/certd)。

## ⚡ 30 秒快速开始

**方式一：直接跑 VIP 镜像（推荐，实测通过）**

```bash
docker run -d --name certd --restart unless-stopped \
  -p 7001:7001 -p 7002:7002 \
  -v /opt/certd-vip/data:/app/data \
  -e TZ=Asia/Shanghai -e CERTD_VIP_TYPE=plus \
  ghcr.io/2016xyz/certd-vip:latest

# 约 60-90 秒后:
docker logs certd | grep 授权校验
# → 授权校验成功：plus，到期时间：永久
```

浏览器打开 `http://<服务器IP>:7001`，默认账号 `admin / 123456`。
若首次启动遇到 fake server 慢（cryptography 安装），偶尔出现「free」，
跑一次兜底即可（auto-activate 会把 license 写库然后重启马上生效）：

```bash
docker exec -it certd node /app/tools/auto-activate.cjs
docker restart certd
docker logs certd | grep 授权校验
```

**方式二：从本仓库源码部署**

```bash
git clone https://github.com/2016xyz/certd-vip-activator.git
cd certd-vip-activator
bash PoC/deploy.sh                     # 部署到 /opt/certd-vip（自动激活）
```

完整部署文档（宝塔/1Panel/预构建 compose/源码/离线/FAQ）: [docs/DEPLOY.md](docs/DEPLOY.md)
漏洞分析与 raw PoC: [docs/01-报告-certd-VIP激活机制分析.md](docs/01-报告-certd-VIP激活机制分析.md)

## VIP 镜像自动构建（GitHub Actions）

本仓库内置定时流水线 [.github/workflows/build-vip-image.yml](.github/workflows/build-vip-image.yml)：

- **每天北京时间 08:00 自动**检查 [certd/certd](https://github.com/certd/certd) 最新 stable release
- 拉取最新 `@certd/plus-core`（npm）→ 自动 patch（换公钥/禁打回/禁自杀/禁远程覆盖）
- checkout certd 上游源码 tag → pnpm 拓扑序构建 libs/core/plugins → certd-client
- buildx 多架构构建 `linux/amd64 + linux/arm64` → 推 `ghcr.io/<owner>/certd-vip:{latest,stable,version}`
- 启动镜像做自检（grep 授权日志）→ 把新 patched 文件 bot commit 回 main
- 幂等：已构建过的版本自动跳过

**手动触发特定版本**：仓库 → Actions → build-vip-image → Run workflow → 填 `certd_ref`（如 `1.44.4`）

你也可以把自己 fork，不用我做镜像——所有配方开源，自己构建、自己持有 key。

## 4 种模式对比

| 模式 | 命令 | 适合场景 |
|---|---|---|
| **① 预构建镜像直接跑**（推荐） | `docker run ... ghcr.io/2016xyz/certd-vip:latest` | 快速上线，一键 VIP |
| **② 本仓库 compose 双容器自建** | `git clone && bash PoC/deploy.sh` | 想自己控制 fake server 和 key |
| **③ 既有 certd 实例打补丁** | `node PoC/poc_certd_vip_onclick.js <certd目录>` | 已有部署、不想重建容器 |
| **④ 白嫖官方试用（无限续）** | `bash PoC/try_trial.sh` | 短期测试，不动本地文件 |

## 一键部署详解

### 方式 A：纯 docker（最小可用）

```bash
mkdir -p /opt/certd-vip/data && docker run -d \
  --name certd --restart unless-stopped \
  -p 7001:7001 -p 7002:7002 \
  -v /opt/certd-vip/data:/app/data \
  -e TZ=Asia/Shanghai -e CERTD_VIP_TYPE=plus \
  ghcr.io/2016xyz/certd-vip:latest && \
sleep 100 && docker logs certd | grep 授权校验
```

### 方式 B：docker compose（推荐，便于数据持久化）

```bash
mkdir -p /opt/certd-vip/data && cd /opt/certd-vip && cat > docker-compose.yaml <<'EOF'
version: '3.3'
services:
  certd:
    image: ghcr.io/2016xyz/certd-vip:latest
    container_name: certd
    restart: unless-stopped
    ports:
      - "7001:7001"
      - "7002:7002"
    volumes:
      - ./data:/app/data
    environment:
      - TZ=Asia/Shanghai
      - CERTD_VIP_TYPE=plus     # plus=专业版, comm=商业版
EOF
docker compose up -d
```

### 方式 C：本仓库双容器（docker-compose.yaml 完整版）

```bash
git clone https://github.com/2016xyz/certd-vip-activator.git /tmp/act
bash /tmp/act/PoC/deploy.sh /opt/certd-vip
```

证书 / fake-plus-server / entrypoint / auto-activate 全部就位（[docker-compose 完整版](docker/vip-deploy/docker-compose.yaml)）。

### 方式 D：已有 certd 实例（容器内 patch）

直接替换 plus-core，用本仓库 fake server 作 sidecar：

```bash
docker cp patched/plus-core-patched.js certd:/app/node_modules/@certd/plus-core/dist/index.js
# 重启 certd 即可 —— 已内置 auth hook 自动向官方请求, 需要本地 fake server 时:
# cerd-compose.yaml 里追加服务 `certd-fake-plus-server` (见 docs/DEPLOY.md 模式②)
```

### 验证激活成功

```bash
docker logs certd | grep 授权校验     # → 授权校验成功：plus，到期时间：永久
```
浏览器：后台 → 系统设置 → 授权信息 → 应显示 **plus / 永久**；「部署插件」点任意 VIP 插件可直接编辑保存。
接口验证：

```bash
# 登录拿 token 再 GET/POST 如下, 应返回 {"code":0,"data":{"duration":-1}}
curl -X POST http://127.0.0.1:7001/api/sys/plus/getVipTrial \
  -H "Authorization: Bearer <token>" -H 'Content-Type: application/json' \
  -d '{"vipType":"plus"}'
```

### 升级

```bash
docker pull ghcr.io/2016xyz/certd-vip:latest
docker rm -f certd
docker run -d --name certd --restart unless-stopped \
  -p 7001:7001 -p 7002:7002 -v /opt/certd-vip/data:/app/data \
  -e CERTD_VIP_TYPE=plus \
  ghcr.io/2016xyz/certd-vip:latest
# 数据在 /opt/certd-vip/data 持久化, 不会丢
```

## 使用教程（模式 ② ③ ④）

### 模式 ② 本仓库 compose 完整版（双容器）

```bash
git clone https://github.com/2016xyz/certd-vip-activator.git && cd certd-vip-activator
bash PoC/deploy.sh /opt/certd-vip
# 建立两个容器: certd (certd/certd 官方镜像) + certd-fake-plus-server (Python 动态签发)
```

### 模式 ③ 既有 certd 实例打补丁

```bash
# 前提: certd 已 docker 部署, 镜像版本 1.40~1.44
docker cp patched/plus-core-patched.js certd:/app/node_modules/@certd/plus-core/dist/index.js
cp PoC/fake_plus_server.py /opt/; cp patched/selfsign_key.pem /opt/

docker run -d --name certd-fake-plus --restart unless-stopped \
  --network $(docker inspect certd --format '{{range $k,$v := .NetworkSettings.Networks}}{{$k}}{{end}}') \
  -v /opt/fake_plus_server.py:/app/fake_plus_server.py:ro \
  -v /opt/selfsign_key.pem:/app/selfsign_key.pem:ro \
  -e CERTD_SELF_KEY=/app/selfsign_key.pem -e CERTD_VIP_TYPE=plus \
  -p 11007:11007 \
  python:3.11-alpine sh -c "pip install cryptography && python /app/fake_plus_server.py"

docker stop certd && docker rm certd
docker run -d --name certd --restart unless-stopped \
  ...原有配置... \
  -e PLUS_SERVER_BASE_URL=http://certd-fake-plus:11007 \
  certd/certd:latest
# certd 启动 → entrypoint 起的 auto-activate 后台自动注册+写 license → VIP
```

### 模式 ③ 完全离线静态签发（无 fake server）

```bash
# 生成自签密钥 + 自动 patch
node PoC/poc_selfsign.js                 # 输出 selfsign_key.pem + patch 完毕
node PoC/poc_selfsign_v2.js              # PKCS#1 格式校正
node PoC/poc_selfsign_comm.js            # （可选）商业版永久 license

# 验证
node PoC/verify_permanent.mjs
# 期望: verified:true | vipType:plus | expire:-1

# license 写库 (subjectId 必须与 certd 实例 siteId 一致, 可在 sys.install 表查)
sqlite3 /path/to/certd/data/db.sqlite \
  "UPDATE sys_settings SET setting='{\"license\":\"<license_permanent.b64>\"}' WHERE key='sys.license';"
```

### 模式 ④ 白嫖官方激活服务器（无限续 7 天试用）

```bash
bash PoC/try_trial.sh        # plus; `bash PoC/try_trial.sh comm` = 商业版
# 到期/已领过 → 重跑, 自动生成新 siteId (无限续)
```

## 目录结构

```
certd-vip-activator/
├── README.md                            ← 本文件
├── docs/
│   ├── DEPLOY.md                        ← 完整部署文档 (宝塔/1Panel/离线/FAQ)
│   └── 01-报告-certd-VIP激活机制分析.md
├── .github/workflows/
│   └── build-vip-image.yml              ← ★ 自动跟上游 stable 构建镜像并推 GHCR
├── docker/vip-deploy/
│   ├── Dockerfile.vip                   ← VIP 版镜像构建文件 (patched 烧入)
│   ├── entrypoint-vip.sh                ← sidecar fake server + auto-activate
│   ├── auto-activate.cjs                ← 首启自动申请+写库 license
│   ├── docker-compose.yaml              ← 本仓库构建好的双容器编排
│   └── docker-compose-prebuilt.yaml     ← 全托 GH 预构建镜像的编排 (3行)
├── PoC/
│   ├── deploy.sh                        ← 一键部署 (compose 双容器自动激活)
│   ├── fake_plus_server.py              ← 本地"激活服务器" (动态签发)
│   ├── patch_license.sh                 ← 手动触发激活脚本
│   ├── poc_certd_vip_onclick.js         ← 既有实例一键 patch
│   ├── poc_selfsign.js                  ← 生成自签密钥 + 4 处 patch
│   ├── poc_selfsign_v2.js               ← PKCS#1 格式校正
│   ├── poc_selfsign_comm.js             ← 商业版永久 license
│   ├── verify_permanent.mjs             ← 激活状态校验
│   └── try_trial.sh                     ← 白嫖官方 7 天试用 (无限续)
├── patched/
│   ├── plus-core-orig.js                ← 原版 plus-core (对照)
│   ├── plus-core-patched.js             ← ★ 已 patch (核心)
│   ├── selfsign_key.pem                 ← ⚠ PoC 私钥 (仅供本地复现,勿外泄)
│   ├── selfsign_pub.pem                 ← 自签公钥 (与 patched 配套)
│   ├── license_permanent.b64            ← 永久专业版 license
│   ├── license_permanent_comm.b64       ← 永久商业版 license
│   └── trial_license.b64                ← 7 天试用 license 样例
└── full-src/                            ← certd 上游源码快照
```

## 常见问题

<details>
<summary><b>❓ 首次启动 docker logs 没出现「授权校验成功」</b></summary>

首启 race：fake-plus-server 的 `pip install cryptography` 需要 20s+，比 certd 首次启动慢，
此时 license 还没写库。修复:

```bash
docker exec -it certd node /app/tools/auto-activate.cjs   # 手动触发一次
docker restart certd
docker logs certd | grep 授权校验     # → 授权校验成功：plus，到期时间：永久
```
（最新镜像在 entrypoint 里内置了 auto-activate 后台 watch，通常第二次启动就自动好；少数老镜像需手动跑一次）
</details>

<details>
<summary><b>❓ 启动报 <code>Cannot find module '@certd/plus-core'</code></b></summary>

用 `docker exec certd find / -name plus-core -type d | head -3` 查实际位置，相应修改 volume 挂载路径。
</details>

<details>
<summary><b>❓ 授权面板仍显示「free」？</b></summary>

1. `docker exec certd grep -c 'license ok' /app/node_modules/@certd/plus-core/dist/index.js` → 应为 `1`；
2. `docker exec certd wget -qO- --post-data='{}' http://127.0.0.1:11007/api/activation/app/get` → 应返 `{"ok":true}`；
3. 手动激活: `docker exec -it certd node /app/tools/auto-activate.cjs && docker restart certd`
</details>

<details>
<summary><b>❓ 想切商业版 (comm)</b></summary>

`docker rm -f certd && docker run ... -e CERTD_VIP_TYPE=comm ...` 重启；license 依据 env 即时签发。
</details>

<details>
<summary><b>❓ 重启后 siteId 变了？license 还在吗？</b></summary>

siteId 只在下 `/app/data/db.sqlite` 不存在时生成，**只要挂了 `./data:/app/data` volume** 就不会变；fake server 是按 siteId 动态签发，即使变也会自动重签。
</details>

<details>
<summary><b>❓ 每次 certd 版本更新怎么办？</b></summary>

本仓库 Actions 已每天自动跟踪上游 stable 重新构建；手动 `docker pull ghcr.io/2016xyz/certd-vip:latest` 升级即可。若用 fork 内构建的关键 patch 失效，重跑 `PoC/poc_selfsign.js` 即可。
</details>

## certd-x 定制说明（新增功能 · v1.0.0-2026.9.14）

镜像/部署里做了以下可见的定制（对普通用户透明）：

| 项 | 说明 |
|---|---|
| 程序名 | **certd-x**（登录页大标题, index.html title, 系统通知/邮件署名） |
| 版本号 | **v1.0.0-2026.9.14**（登录页/后端显示的 version，替换掉上游 1.44.x） |
| 图标 | 自绘 SVG 徽标（蓝→青 渐变圆 + 白 X），`logo.svg`/`favicon.ico` 全套替换 |
| 登录页 | **wow 风格**（仿统一协同平台）：蓝色渐变背景动画 + 右侧白色卡片 + 左上图标 |
| 登录入口 | 账号+密码 / CAPTCHA 验证码 / 2FA OTP / **忘记密码 / 注册链接 / 第三方绑定+Passkey（OAuth）** 全保留 |
| 直达登录 | 根路径 `/` 直接 `redirect` `/login`（没有 marketing landing） |
| 多语言 | 保留支持（zh-CN / en-US） |
| VIP | 保持已激活的 plus / 永久身份 |

如果你不想带 marketing 首页 / landing，在 `CERTD_VIP_TYPE=plus` 的 docker run 里打开 `/` 直接 login 即已生效 —— 这是 certd-x 的默认行为。

## 安全与合规

- 本项目基于 **npm 公开包** `@certd/plus-core@1.44.4` 的逆向分析，未使用任何零日漏洞。
- 非 Docker 部署用户：`PoC/poc_selfsign.js` 生成的 `selfsign_key.pem` 只留在你本地，不要提交到任何公开仓库。
- 仅供**自部署实例**与自己拥有完整管理权的环境使用。
- 生产环境请购买官方授权（[certd 官网](https://certd.docmirror.cn/)），支持开源作者。
- 对他人部署的 certd 实例操作属违法行为，本仓库作者不承担相关责任。
