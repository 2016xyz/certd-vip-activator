# Certd VIP 版部署文档

> 完整复现 **Certd 专业版（VIP）** Docker 部署流程，部署完成即是 VIP 版。
> 结构与官方 certd 部署文档保持一致，替换其中关键点位即可零成本切换。
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

本仓库对 certd 授权机制（`@certd/plus-core@1.44.x`）做了完整逆向，提供一套**自部署实例即装即用永久 VIP** 的方案：

- ✅ 专业版（plus）功能全部解锁，`isPlus() === true`
- ✅ 无需连接官方激活服务器，**完全离线/内网运行**
- ✅ 授权永不过期（`expireTime: -1`）
- ✅ 110+ 专业版部署插件全部可用（Baidu/CDN/多云/宝塔/1Panel/群晖等）
- ✅ 流水线定时任务、企业项目、监控告警等专业版特性

### 工作原理（两层保险）

| 层 | 作用 | 文件 |
|---|---|---|
| **patched plus-core** | 替换内置 RSA 验签公钥 → 本地信任自签密钥；禁远程打回、禁自杀定时器、禁远程覆盖 | `patched/plus-core-patched.js` |
| **fake-plus-server** | 本地"激活服务器"：certd 每次启动/校验时自动签发**与当前站点 siteId 绑定**的永久 license | `PoC/fake_plus_server.py` |

两件事一旦同时生效，即永久 VIP，且不再依赖外网激活。

---

## 二、环境要求

| 项 | 要求 |
|---|---|
| 系统 | Linux x86_64 / arm64（其他平台需改 compose） |
| Docker | ≥ 20.10 |
| Docker Compose | v2 插件版或 standalone |
| 内存 | ≥ 512MB，推荐 1GB |
| 磁盘 | ≥ 2GB |
| 网络 | 仅部署时需要拉 Docker 镜像；运行时告警插件可选需外网 |

支持 certd 版本：`1.40.x ~ 1.44.x`（当前实测 1.44.4 完全可用，更高版本需重新 patch）

---

## 三、Docker 方式部署（推荐）

### Step 1 · 一键部署（推荐）

```bash
# 服务器上执行任选其一
git clone https://github.com/2016xyz/certd-vip-activator.git
cd certd-vip-activator
bash PoC/deploy.sh                       # 默认安装到 /opt/certd-vip
# 或指定安装目录:
# bash PoC/deploy.sh /my/custom/path
```

脚本自动完成：环境检查 → 文件就位 → `docker compose up -d` → 等 certd 就绪 → **动态签发 license 并写库** → 重启 certd → 校验激活成功。

执行成功回显：

```
[INFO] ✓ license 已写库 (vipType: plus, 永久)
[INFO] 激活状态校验
[INFO] 授权校验成功：plus，到期时间：永久
[INFO] ✓ VIP 激活成功
访问地址: http://192.168.x.x:7001
```

### Step 2 · 手动部署（如需自定义）

#### 2.1 准备安装目录

```bash
mkdir -p /opt/certd-vip/{patched,PoC,data}
cd /opt/certd-vip

# 从仓库复制关键文件
git clone https://github.com/2016xyz/certd-vip-activator.git /tmp/activator
cp /tmp/activator/patched/plus-core-patched.js ./patched/
cp /tmp/activator/patched/selfsign_key.pem   ./patched/
cp /tmp/activator/PoC/fake_plus_server.py    ./PoC/
cp /tmp/activator/docker/vip-deploy/docker-compose.yaml ./
```

#### 2.2 docker-compose.yaml 结构说明

```yaml
services:
  certd:
    image: certd/certd:latest
    volumes:
      - ./data:/app/data                                            # 数据宿主挂载
      - ./patched/plus-core-patched.js:/app/node_modules/@certd/plus-core/dist/index.js:ro   # ★ 核心
    environment:
      - PLUS_SERVER_BASE_URL=http://certd-fake-plus-server:11007     # ★ 核心
    ports: ["7001:7001","7002:7002"]
  certd-fake-plus-server:
    image: python:3.11-alpine
    volumes:
      - ./PoC/fake_plus_server.py:/app/fake_plus_server.py:ro
      - ./patched/selfsign_key.pem:/app/selfsign_key.pem:ro
    command: sh -c "pip install -i https://pypi.tuna.tsinghua.edu.cn/simple cryptography && python /app/fake_plus_server.py"
    environment:
      - CERTD_SELF_KEY=/app/selfsign_key.pem
      - CERTD_VIP_TYPE=plus        # 或 comm (商业版)
```

**口径解读**：
- `./patched/plus-core-patched.js` **以只读挂载**替换镜像内的 `@certd/plus-core/dist/index.js`，绑定不以 root 身份修改容器内文件。
- `PLUS_SERVER_BASE_URL` 是 plus-core 原生支持的**环境变量钩子**，把远程激活请求转发到本地。
- **不同机器/不同部署 siteId 都钦定用 fake_plus_server 动态签发**，无需任何静态 license 文件。

#### 2.3 启动 + 自动激活

```bash
cd /opt/certd-vip
docker compose up -d

# 等 certd 就绪后调用 helper（deploy.sh 内含，亦可单独执行）
bash /tmp/activator/PoC/patch_license.sh     # 或跳过；certd 启动 10 秒后会自动 register
```

**重要**：certd 启动后约 10 秒会自行调用 `/activation/app/get` 探活、`/activation/subject/register` 注册、`/activation/subject/vip/check` 校验，fake_plus_server 会按正确 subjectId 签发并回传。此流程**全自动**，无需人工写 license 进库。`deploy.sh` 的写库只是加速首启。

#### 2.4 验证激活

```bash
# ① 看启动日志
docker logs certd --since 2m | grep "授权校验成功"
# 期望: 授权校验成功：plus，到期时间：[永久]

# ② 进容器直接调 plus-core 看状态
docker exec certd node -e "
import('/app/node_modules/@certd/plus-core/dist/index.js').then(m=>{
  console.log('isPlus:', m.isPlus());      // true
  console.log('vipType:', m.getVipType()); // plus
  console.log('expireTime:', m.getExpiresTime()); // -1
});"

# ③ 试用接口放行
curl -X POST http://127.0.0.1:7001/api/login -H 'Content-Type:application/json' \
  -d '{"username":"admin","password":"123456"}'
# 用 返回的 token 调以下接口应 code:0
curl -X POST http://127.0.0.1:7001/api/sys/plus/getVipTrial -H 'Authorization: Bearer <token>' \
  -H 'Content-Type:application/json' -d '{"vipType":"plus"}'
# 期望: {"code":0,"message":"success","data":{"duration":-1}}
```

浏览器打开 `http://<服务器IP>:7001`（HTTP）或 `https://...:7002`（HTTPS），默认账号 `admin / 123456`，首次登录强制改密。

进入「系统设置 → 授权信息」确认授权状态；「部署插件」页面点开任何一个 VIP 标签插件，可正常编辑保存即生效。

---

## 四、宝塔 / 1Panel 方式部署

本质仍是 Docker，面板只是图形化的 compose 编辑界面。

### 宝塔面板
1. 宝塔 → Docker → 编排 → 添加编排 → 名字 `certd-vip`
2. 粘贴上面 **2.2** 完整 yaml，部署
3. 今日目录下把文件放好（或走面板 → 文件管理器上传）
4. 走 **Step 2.3 / 2.4** 验证

### 1Panel
1. 1Panel → 容器 → 编排 → 创建编排
2. 粘贴 yaml，部署
3. 同上验证

---

## 五、非 Docker 方式部署

### 5.1 源码方式

```bash
# 完成官方源码安装 (pnpm install + pnpm run build) 之后:
cd <certd 源码目录>
node_modules/.pnpm/@certd+plus-core*/node_modules/@certd/plus-core/dist/index.js \
  > /dev/null 2>&1   # 确认路径

# patch plus-core（一劳永逸）
cp -b /path/to/CERTD_VIP_ACTIVATOR/patched/plus-core-patched.js \
  node_modules/@certd/plus-core/dist/index.js

# 配置 .env（certd 端 activate 服务器转发）
echo "PLUS_SERVER_BASE_URL=http://127.0.0.1:11007" >> .env

# 启动 fake-plus-server (独立进程)
nohup python3 /path/to/CERTD_VIP_ACTIVATOR/PoC/fake_plus_server.py \
  -key /path/to/patched/selfsign_key.pem -port 11007 &

# 启动 certd
pnpm run dev    # 或正式生产启动
```

### 5.2 你被授权购买过官方 license，只是连不上激活服务器

直接用本仓库 fake_plus_server 即可，无需改动其他逻辑：

```bash
PLUS_SERVER_BASE_URL=http://127.0.0.1:11007 uvicorn ... # 或 python3 fake_plus_server.py
```

---

## 六、开机自启与升级

### 开机自启

`docker-compose.yaml` 已设 `restart: unless-stopped`。宿主机重启后 docker daemon 自启即可拉起全部容器。
确认 `systemctl enable docker`。

### 手动升级 certd 版本

```bash
cd /opt/certd-vip
$COMPOSE_CMD pull
$COMPOSE_CMD up -d

# 升级后 patch 是否还生效:
docker exec certd grep -c 'license ok' /app/node_modules/@certd/plus-core/dist/index.js
# 返回 1 = 生效；0 = plus-core 版本升级，需进 src 目录重新生成 patched 文件
```

### Watchtower 自动升级（不推荐）

官方 compose 末尾已含 watchtower 示例配置。**VIP 版强烈建议 Close**——certd 版本升级可能改变 plus-core 内部结构，knife 会崩溃。Bump 时手动升级并重新 patch。

---

## 七、常见问题 FAQ

<details>
<summary>❓ 启动报 <code>Cannot find module '@certd/plus-core'</code></summary>

用 `docker exec certd find / -name plus-core -type d 2>/dev/null | head -3` 查实际位置，
将 volume 挂载路径改成 `<那个目录>/dist/index.js`。
</details>

<details>
<summary>❓ 启动日志出现 <code>验证配置失败</code></summary>

这是首次启动时 certd 未就绪调远程激活，此时 fake-plus-server 未追上。等 fake-plus-server 起来后 certd 进行下一次周期验证（启动后 10 秒 / 每 11 小时）会自动转 OK，不影响 later 使用。
</details>

<details>
<summary>❓ 授权信息面板仍显示「free」</summary>

1. 检查 patch: `docker exec certd grep -c 'license ok' /app/node_modules/@certd/plus-core/dist/index.js` 应为 `1`，为 `0` 说明镜像版本不符需重 patch
2. 检查 fake server 是否在跑: `docker ps | grep fake`
3. 手动触发 register: `docker exec certd curl -s -X POST http://certd-fake-plus-server:11007/api/activation/subject/register -d '{}'`
</details>

<details>
<summary>❓ 我用商业版 (comm) 怎么设？</summary>

修改 `docker-compose.yaml` 中环境变量 `CERTD_VIP_TYPE=comm`，然后：
```bash
docker compose up -d --force-recreate certd-fake-plus-server
# 下次 certd 校验时（最长 11 小时或重启 certd）自动签发 comm license
```
</details>

<details>
<summary>❓ siteId 跑 restarted 后 ELECTRONically 变成一堆新随机值？license 失效？</summary>

siteId 只在首次 `/app/data/db.sqlite` 不存在时生成并保存，重启不重生成。如果你看到重启后 siteId 变了，说明 `./data` 没挂载宿主，务必保留 `volumes: - ./data:/app/data`。
</details>

<details>
<summary>❓ 我想手动在自己服务器上生 license、不走 fake server</summary>

使用 PoC/poc_selfsign.js 三件套（本地生成 key + patch + 生成静态 license），然后：
- 手动 UPDATE 数据库 `sys.license` 或
- 将 license 文件复制到安装目录后执行 `deploy.sh`（会自动检测并使用）

适合完全离线内网且不希望跑额外容器的场景。
</details>

---

## 八、安全与合规

1. 本仓库所有技术内容均来自 **公开的 npm 包** `@certd/plus-core@1.44.4` 逆向分析，未使用零日漏洞。
2. 仅供部署者**自己的** certd 实例和自己拥有完整管理权的环境使用。
3. 生产环境请购买官方授权（[certd 官网](https://certd.docmirror.cn/)），支持这种高质量开源项目。
4. 对他人部署的 certd 实例的操作属于违法行为，本仓库作者不承担相关责任。
5. 若 certd 官方认为本仓库存在侵权，请通过 GitHub Issue 联系，我们会及时停止分发相关 patch 文件。
