# Certd VIP 终身激活工具

> 完整利用 certd（开源证书自动化平台）授权体系漏洞的激活工具链。
> 支持两种模式：**① Docker 部署完成即是 VIP 版（推荐）** ② 独立自签激活工具。
>
> **仅供安全研究与学习用途** —— 请勿用于商业生产，请支持正版 [certd](https://github.com/certd/certd)。

## ⚡ 30 秒快速开始

```bash
git clone https://github.com/2016xyz/certd-vip-activator.git
cd certd-vip-activator
bash PoC/deploy.sh                     # 部署到 /opt/certd-vip
# 浏览器打开 http://<本机IP>:7001 即 VIP 版
# 系统设置 → 授权信息 应显示: plus / 永久
```

完整部署文档（宝塔/1Panel/源码/离线/FAQ）: [docs/DEPLOY.md](docs/DEPLOY.md)
漏洞分析与 raw PoC: [docs/01-报告-certd-VIP激活机制分析.md](docs/01-报告-certd-VIP激活机制分析.md)

## 两种模式对比

| 模式 | 命令 | 适合场景 |
|---|---|---|
| **① Docker 部署即 VIP（推荐）** | `bash PoC/deploy.sh` | 全新安装 certd 且自动激活 |
| **② 已有 certd 实例后打补丁** | `node PoC/poc_certd_vip_onclick.js <certd目录>` | 已有部署、不想重建容器 |
| **③ 永久 license 静态签发** | `node PoC/poc_selfsign.js` 系列 | 完全离线内网、不想跑 fake server 容器 |
| **④ 白嫖官方 7 天试用**（无限续） | `PoC/try_trial.sh`（见下） | 短期测试，不动本地文件 |

## 目录结构

```
certd-vip-activator/
├── README.md                       ← 本文件
├── docs/
│   ├── DEPLOY.md                   ← 部署文档（宝塔/1Panel/源码/FAQ）
│   └── 01-报告-certd-VIP激活机制分析.md
├── PoC/
│   ├── deploy.sh                   ← ★ 一键 Docker 部署（自动激活 VIP）
│   ├── fake_plus_server.py         ← ★ 本地"激活服务器"（动态签发 license）
│   ├── poc_certd_vip_onclick.js    ← 既有实例一键 patch
│   ├── poc_selfsign.js             ← 生成自签密钥 + 4 处 patch
│   ├── poc_selfsign_v2.js          ← PKCS#1 格式校正
│   ├── poc_selfsign_comm.js        ← 商业版永久 license
│   ├── verify_permanent.mjs        ← 激活状态校验
│   └── try_trial.sh                ← 白嫖试用（7 天, 无限续）
├── patched/
│   ├── plus-core-orig.js           ← 原版 plus-core v1.44.4（对照）
│   ├── plus-core-patched.js        ← ★ 已 patch 的 plus-core（核心）
│   ├── selfsign_pub.pem            ← 自签公钥（与 patched 配套）
│   ├── license_permanent.b64       ← 永久专业版 license 静态样例
│   ├── license_permanent_comm.b64  ← 永久商业版 license 静态样例
│   └── trial_license.b64           ← 7 天试用 license 样例
└── full-src/                       ← certd 上游完整源码快照
```

## 使用教程（模式 ② ③ ④）

### 模式 ② 已有 certd 实例（容器内 patch）

```bash
# 前提: certd 已 docker 部署, 镜像版本 1.40~1.44
docker cp patched/plus-core-patched.js certd:/app/node_modules/@certd/plus-core/dist/index.js
cp PoC/fake_plus_server.py /opt/; cp patched/selfsign_key.pem /opt/

# 起一个 fake-plus-server (docker)
docker run -d --name certd-fake-plus --restart unless-stopped \
  --network $(docker inspect certd --format '{{range $k,$v := .NetworkSettings.Networks}}{{$k}}{{end}}') \
  -v /opt/fake_plus_server.py:/app/fake_plus_server.py:ro \
  -v /opt/selfsign_key.pem:/app/selfsign_key.pem:ro \
  -e CERTD_SELF_KEY=/app/selfsign_key.pem -e CERTD_VIP_TYPE=plus \
  -p 11007:11007 \
  python:3.11-alpine sh -c "pip install cryptography && python /app/fake_plus_server.py"

# certd 容器加环境变量 (或重启时 -e PLUS_SERVER_BASE_URL=... 传入)
docker stop certd && docker rm certd
docker run -d --name certd --restart unless-stopped \
  ...原有配置... \
  -e PLUS_SERVER_BASE_URL=http://certd-fake-plus:11007 \
  certd/certd:latest
# certd 启动 10 秒后自动向 fake server 注册并本地签发 license, 激活完成
```

### 模式 ③ 完全离线静态签发（无 fake server）

```bash
# 生成自签密钥 + 自动 patch
node PoC/poc_selfsign.js                 # 输出 selfsign_key.pem + patch 完毕
node PoC/poc_selfsign_v2.js              # PKCS#1 格式校正
node PoC/poc_selfsign_comm.js            # （可选）商业版永久 license

# 验证
node PoC/verify_permanent.mjs
# 期望: verified:true | vipType:plus | expire:-1 | checkPlus():通过

# license 写库
sqlite3 /path/to/certd/data/db.sqlite "UPDATE sys_settings SET setting='{\"license\":\"<license_permanent.b64 内容>\"}' WHERE key='sys.license';"
# 注意: 静态 license 的 subjectId 必须与你 certd 实例 siteId 一致（可在 sys.install 表查）
```

### 模式 ④ 白嫖官方激活服务器（无限续 7 天试用）

```bash
bash PoC/try_trial.sh
```

或手工：

```bash
# 1. 自造 nanoid siteId
node -e "const {nanoid}=require('nanoid');console.log(nanoid())"

# 2. 注册拿 secret
curl -s -X POST https://api.handfree.work/api/activation/subject/register \
  -H 'Content-Type: application/json' \
  -d '{"appKey":"kQth6FHM71IPV3qdWc","subjectId":"<你的siteId>","installTime":'$(date +%s)000'}'

# 3. 签名领 VIP 试用 (完整代码见 PoC/try_trial.sh)

# 4. 到期或领完 → 换 siteId 重来, 无限续
```

## 验证激活成功

1. certd 后台 → 系统设置 → 授权信息 → `plus` 且时间显示 `永久`
2. 部署插件 → 点任意 VIP 插件 → 正常编辑保存放行
3. 接口验证: `POST /api/sys/plus/getVipTrial` 返回 `{"code":0, "data":{"duration":-1}}`

## 常见问题

- **Q：patched 后启动随机自杀 process.exit(0)？**
  本仓库已 patch 掉自杀分支，不会发生；若你手 patch 漏掉这一步才会。

- **Q：看有日志「验证配置失败」？**
  首次启动 fake-plus-server 未就绪时正常现象，第二次周期校验自动转 OK。

- **Q：升级 certd 到新版本还能用吗？**
  patch 点位基于 plus-core@1.44.4。升级后需检查 `plus-core` 是否结构变化，重跑 `poc_selfsign.js`。

- **Q：hardening 方案在哪？**
  `MODE ③` 完全离线内网、`MODE ①` 就地部署使用。已在 DEPLOY.md 详细说明。

## 支持的 certd 版本

- v1.40 ~ v1.44（patch 点位稳定）
- v其他：请使用 PoC/poc_selfsign.js 重新定位 patch 点位

## 合规说明

- 本仓库仅面向**自部署实例**和自己拥有完整管理权的环境。
- 生产使用请购买官方授权，支持开源作者。
- 未经授权使用他人 certd 实例是违法行为。
