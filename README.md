# certd-x · v1.0.0-2026.9.14

> 基于 [certd](https://github.com/certd/certd)（开源证书自动化平台）的 **VIP 终身激活定制版**。
> 程序名 **certd-x** · 版本 **v1.0.0-2026.9.14** · 自定义 Logo/Favicon · wow 风格登录页 · 部署即 VIP。
>
> **v1.0.0-2026.9.14 Release**: [点击查看](https://github.com/2016xyz/certd-vip-activator/releases/tag/v1.0.0-2026.9.14)
>
> **仅供安全研究与学习用途** —— 请勿用于商业生产，请支持正版 [certd](https://github.com/certd/certd)。

| 定制 | 说明 |
|---|---|
| 程序名 | **certd-x**（登录页 / 浏览器 tab / 系统邮件签名 / Passkey rpName） |
| 版本号 | **v1.0.0-2026.9.14**（前后端 / package.json 全同步） |
| 图标 | 自绘 SVG —— 蓝青渐变圆 + 白 X，`logo.svg` + `favicon.ico` 全套 |
| 登录页 | **wow 风格**（仿统一协同平台）：蓝色渐变动态背景 + 右侧白色圆角卡片，含账号密码 / CAPTCHA / 2FA OTP / **忘记密码 / 注册 / 第三方 OAuth + Passkey 一键入口** |
| 直达登录 | 根路径 `/` 直接 redirect `/login`（没有 marketing landing） |
| VIP | 部署后自动激活 **plus / 永久**，正式授权（非试用） |

## ⚡ 30 秒快速开始

### 一键全自动安装（全系统发行版自动识别）★ 推荐

```bash
curl -fsSL https://raw.githubusercontent.com/2016xyz/certd-vip-activator/main/docker/vip-deploy/install-certd-vip.sh -o install.sh && sudo bash install.sh
```

或用 GitHub 项目本地的 `install-certd-vip.sh`（兼容 Ubuntu/Debian/CentOS/RHEL/Rocky/AlmaLinux/Fedora/openEuler/Arch 等）：

```bash
git clone https://github.com/2016xyz/certd-vip-activator.git
sudo bash certd-vip-activator/docker/vip-deploy/install-certd-vip.sh
```

### 手动一行（不需要 cloneRepository， Linux 全部支持）

```bash
mkdir -p /opt/certd-vip/data && docker run -d --name certd --restart unless-stopped \
  -p 7001:7001 -p 7002:7002 \
  -v /opt/certd-vip/data:/app/data \
  -e TZ=Asia/Shanghai -e CERTD_VIP_TYPE=plus \
  ghcr.io/2016xyz/certd-vip:latest

# 约 90 秒后:
docker logs certd | grep 授权校验
# → 授权校验成功：plus，到期时间：永久
```

### 使用固定 tag（推荐生产环境锁定版本）

```bash
docker run -d --name certd --restart unless-stopped \
  -p 7001:7001 -p 7002:7002 \
  -v /opt/certd-vip/data:/app/data \
  -e TZ=Asia/Shanghai -e CERTD_VIP_TYPE=plus \
  ghcr.io/2016xyz/certd-vip:v1.0.0-2026.9.14
```

### docker-compose 部署（推荐数据持久化 + restart 策略）

```yaml
services:
  certd:
    image: ghcr.io/2016xyz/certd-vip:v1.0.0-2026.9.14
    container_name: certd
    restart: unless-stopped
    ports:
      - "7001:7001"
      - "7002:7002"
    volumes:
      - ./data:/app/data
    environment:
      - TZ=Asia/Shanghai
      - CERTD_VIP_TYPE=plus     # plus=专业版 ; comm=商业版
```

## 📌 说明

- **唤醒 VIP 镜像**：`ghcr.io/2016xyz/certd-vip` 共有四个 tag：
  - `:latest`  ·  跟随最新版本 | buildx linux/amd64
  - `:stable` · 上游 stable release
  - `:v1.0.0-2026.9.14` · 本 tag 指向 stable 1.44.4 版本
  - `:<certd-version>` · 跟随 certd 升级自动新增
- **每天北京时间 08:00** 会自动重新拉取上游 certd/certd 最新 release，重跑 patch + buildx，然后 push 新版本镜像。
- **手动触发**：仓库 → Actions → `build-vip-image` → Run workflow，可以指定任意 certd 版本
- **安装方式（4 种）**：
  - ⓪ 一键脚本（Ubuntu / Debian / CentOS / RHEL / Rocky / Alma / Fedora / openEuler / Arch / 极简系统）
  - A 直接 docker/run 镜像（强烈推荐）
  - B 双容器 compose（自持 fake plus server + key）
  - D 已有 certd 实例打补丁

### 验证激活成功（3 种）

```bash
# ① docker logs
docker logs certd | grep 授权校验     # → 授权校验成功：plus，到期时间：永久

# ② 前端登录后测量
浏览器打开 http://<IP>:7001 → 登录后台 → 系统设置 → 授权信息 → 应显示 plus / 永久

# ③ API 验证
curl -X POST http://<IP>:7001/api/sys/plus/getVipTrial \
  -H "Authorization: Bearer <token>" -H 'Content-Type: application/json' \
  -d '{"vipType":"plus"}'        # → {"code":0,"data":{"duration":-1}}
```

### 遇到问题兜底（首启 race 场景）

```bash
docker exec -it certd node /app/tools/auto-activate.cjs && docker restart certd
```

## 组向量定制

| 变量 | 默认 | 说明 |
|---|---|---|
| `CERTD_VIP_TYPE` | plus | plus=专业版 / comm=商业版 |
| `TZ` | Asia/Shanghai | 时区 |
| 数据目录 | `/opt/certd-vip/data` | SQLite 数据库 / SSL 证书 / 临时文件 |

**切商业版 comm：**

```bash
docker rm -f certd && docker run -d --name certd --restart unless-stopped \
  -p 7001:7001 -p 7002:7002 \
  -v /opt/certd-vip/data:/app/data -e CERTD_VIP_TYPE=comm \
  ghcr.io/2016xyz/certd-vip:latest
```

## 目录结构

```
certd-vip-activator/
├── README.md                        ← 本文件
├── docs/
│   ├── DEPLOY.md                    ← 完整部署文档 (宝塔/1Panel/离线/FAQ)
│   └── 01-报告-certd-VIP激活机制分析.md  ← 全流程逆向分析报告
├── .github/workflows/
│   └── build-vip-image.yml          ← ★ auto-build workflow (schedule 和 tag push 双触发)
├── docker/vip-deploy/
│   ├── install-certd-vip.sh         ← ★ 全系统一键安装 (Ubuntu/Debian/CentOS/RHEL/Rocky/Alma/Fedora/openEuler/Arch)
│   ├── Dockerfile.vip               ← VIP 镜像构建文件 (patched 烧入+signature 双校验)
│   ├── entrypoint-vip.sh            ← sidecar fake server + auto-activate 后台
│   ├── auto-activate.cjs            ← 首启自动请求+写库 license
│   ├── fake_plus_server.py          ← 本地"激活服务器" (动态签发 license)
│   ├── docker-compose.yaml          ← 本仓库构建的双容器编版
│   └── docker-compose-prebuilt.yaml ← 全托 GH 预构建镜像的编排 (3行)
├── PoC/
│   ├── deploy.sh                     ← 一键部署 (compose 双容器自动激活)
│   ├── poc_certd_vip_onclick.js      ← 既有实例一键 patch
│   ├── poc_selfsign.js / v2 / comm   ← 生成自签密钥和 license + 4 处 patch
│   ├── verify_permanent.mjs          ← 激活状态校验
│   └── try_trial.sh                  ← 白嫖官方 7 天试用 (无限续)
├── patched/
│   ├── plus-core-orig.js             ← 原版 plus-core (对照)
│   ├── plus-core-patched.js          ← ★ 已 patch (核心)
│   ├── selfsign_key.pem              ← PoC 私钥 (勿外传)
│   ├── selfsign_pub.pem              ← 自签公钥
│   ├── license_permanent.b64         ← 永久专业版 license 样例
│   ├── license_permanent_comm.b64    ← 永久商业版 license 样例
│   └── trial_license.b64             ← 7 天试用 license 样例
└── full-src/                         ← certd 上游源码快照 + certd-x 定制
```

## FAQ

**Q：首次启动 logs 没有出现授权校验成功？**
首启 race：`fake-plus-server` 需 `pip install cryptography` 约 20 秒，比 certd 启动慢。手动兜底：
```bash
docker exec -it certd node /app/tools/auto-activate.cjs && docker restart certd
```

**Q：升级到新版本会不会丢数据？**
数据在 volume 挂载目录 `/opt/certd-vip/data` 里，只要不删这个目录数据就持久。升级只需要在执行 `docker pull ...latest` + `docker rm -f certd` 后再 run 即可。

**Q：我想切到商业版 comm？**
用 `CERTD_VIP_TYPE=comm` 重新创建容器即可，license 会即时重新签发。

**Q：只有 amd64 架构吗？**
当前 `linux/amd64`。arm64 架构的 ssh2 native compile-QEMU 会 Illegal instruction 崩溃。如需 arm64，后续重新通过 cross-compile 或用非 native 版本。

**Q：`sys.license` 数据库直接写？**
可以（静态离线签发时）：`sqlite3 data/db.sqlite "UPDATE sys_settings SET setting='{\"license\":\"<b64>\"}' WHERE key='sys.license';"`
用 PoC/poc_selfsign.js 生成静态 license 后 UPDATE。

## 安全与合规

- 本项目基于 npm 公开包 `@certd/plus-core@1.44.4` 的逆向分析，未使用任何零日漏洞，仅用于安全研究和学习。
- 仅供自部署实例与自己拥有完整管理权的环境使用。
- 生产环境请购买官方授权（[certd 官网](https://certd.docmirror.cn/)），支持高质量开源项目。
- `PoC/poc_selfsign.js` 生成的 `selfsign_key.pem` 属于你个人 key，**仅本地保存，切勿提交公开仓库**。
- 对他人部署 certd 实例操作属违法行为，仓库作者不承担相关责任。
- 如 certd 官方认为本仓库存在侵权，请通过 GitHub Issue 联系，我们及时停止分发。
