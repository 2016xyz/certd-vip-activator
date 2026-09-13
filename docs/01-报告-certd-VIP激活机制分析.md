# certd VIP/激活机制安全分析报告

**目标**: https://github.com/certd/certd （开源证书自动化平台）+ 其商业授权体系 `@certd/plus-core`
**测试范围**: 授权范围内的白盒源码审计 + 自造主体的激活服务器 API 验证（未触碰任何第三方用户数据）
**日期**: 2026-09-13
**工作目录**: /root/certd/（源码）/root/certd/pluscore/（PoC）

---

## TL;DR 严重性表

| 编号 | 发现 | 严重性 | 状态 |
|---|---|---|---|
| F-001 | 激活服务器任意注册 + 无限刷 VIP 试用（每次新 siteId 领 7 天 plus/comm） | 高 | ✅ 已证实 |
| F-002 | 自部署实例永久 VIP：本地验签公钥可替换 + 自签永久 license | 高（自部署场景） | ✅ 已证实 |
| F-003 | 激活服务器 appKey 硬编码泄露（两个环境 prod/test 均在 npm 包内） | 中 | ✅ 已证实 |
| F-004 | VIP 插件市场接口无 VIP 鉴权，任意免费主体可下载全部插件内容 | 低 | ✅ 已证实 |
| F-005 | 支付回调伪造 | — | ❌ 已排除（服务端金额复核） |
| F-006 | 激活码穷举 | — | ❌ 已排除（熵足够） |
| F-007 | RSA 签名伪造 | — | ❌ 已排除（2048位） |

**一句话结论**：certd 的 VIP 体系存在两条完整可用的"免费通道"——① 对激活服务器：自造 siteId 无限注册刷 7 天 VIP 试用；② 对自部署实例：plus-core 公钥内置客户端，一换一签即永久专业版/商业版。官方激活服务器无需攻击即可按设计被白嫖。

---

## 资产清单

| 资产 | 地址 | 说明 |
|---|---|---|
| 激活服务器(prod) | `https://api.handfree.work/api` | 注册/激活/试用/插件分发 |
| 激活服务器(备) | `https://api.ai.docmirror.cn/api` | 同上，故障切换 |
| 支付网关 | `pay.docmirror.cn`（易支付） | VIP 购买 |
| 商业包 | npm `@certd/plus-core@1.44.4` | **校验逻辑全部在此**，公开可下载 |
| 商业包 | npm `@certd/commercial-core@1.44.4` | 订单/激活码/钱包 |
| 内置 appKey | `kQth6FHM71IPV3qdWc` (prod) / `z4nXOeTeSnnpUpnmsV` (test) | dist/index.js 中硬编码 |

---

## F-001 任意注册 + 无限 VIP 试用 [已证实·高]

### 原理
`@certd/plus-core` 中 `register()` 是**无签名公开接口**，仅需自造的 21 位 nanoid 作 subjectId。注册成功即返回含 `secret` 的 free license；持 secret 签名调 `trialGet` 即领 7 天 VIP。**服务端只按 subjectId 判重，换 ID 即新主体，无任何设备指纹/支付验证/IP 限制。**

### raw 请求与响应

**Step 1 — 注册（无鉴权）**：
```http
POST /api/activation/subject/register HTTP/1.1
Host: api.handfree.work
Content-Type: application/json

{"appKey":"kQth6FHM71IPV3qdWc","subjectId":"GUvNSArDpom7T0d0r3KLJ","installTime":1789315709269}
```
响应：
```json
{"code":0,"message":"Success","data":{"license":"eyJ7InN1YmplY3RJZCI6IiIsImFwcEtleSI6IiIsImR1cmF0aW9uIjowLCJhY3RpdmVUaW1lIjoxNzg5MzE1NzA5MjY5LCJ2ZXJzaW9uIjoxLCJjb2RlIjoiIiwidmlwVHlwZSI6ImZyZWUiLCJleHBpcmVUaW1lIjowLCJzZWNyZXQiOiJ6MVVOcFRSb3ZEN1BicXRwemFwSEUydzdFMHd1MTRoOCIsInNpZ25hdHVyZSI6Ik5UQTl0ZTBGdjJWekwrSWJJWlpmVDh1SXUyRlUxeVd1WW5LZVh5STd3bTNJN0lFWGduM1ZsUXhhS0VCbXB1VC9mUXdmNWN4UWdhaVlueVRPOEkvcU9Bcm9yUitMbnZ1enk0bFZDU0kvWmN2R2x1TktoQWY2SXAwakJxNXpaRTJ3RTVFZ2VpL1I4RTlWQ2JTMHMzVEN3VnZQWU1hT05oSzBKeEpkbVJhelNoYXpDaHF6YWUvVmdyWGIrMzdiTEpuN1NTWkJWeVpubGFWU2VQOVRkaDdRV3VkT3owYUZUNitWRlpHTW1yMXBaVDUxVmJ3bC9TOGl6aHk5Rml1aVdvc3cvZz09In0="}}
```
解码 license：
```json
{"subjectId":"","appKey":"","duration":0,"activeTime":1789315709269,"version":1,"code":"","vipType":"free","expireTime":0,"secret":"z1UNpTRovD7PbqtpzapHE2w7E0wu14h8","signature":"TA9te0Fv..."}
```
**`secret` 直接到手**。

**Step 2 — 领 VIP 试用（secret SHA256 签名）**：
```http
POST /api/activation/subject/vip/trialGet HTTP/1.1
Host: api.handfree.work
Content-Type: application/json
X-Plus-Subject: eyJzdWJqZWN0SWQiOiJHVXZOU0FyRHBvbTdUMGQwcjNLTEoiLCJhcHBLZXkiOiJrUXRoNkZITTcxSVBWM3FkV2MiLCJzaWduIjoiZm81Vy9leTRYbmllT2ZuWlJrNlFsUjhDQ0hTS0pUM0d3UWxVbjdKWXE2dTdNN1JTeG9ydVByU3c4Mk5GNUhJcWgwYXF1NkZzNTBzc2IyL0VcL3FPMGFpWW55VE85cS9xT0E4b3JRK0xudnV6eTRsVkNTSS9aY3ZHbHVOa2hBZjZpcDBqQnE1elpFMndFNUVnZWkvUjhFOVZDYlMxczNUQ3dWdlNZb01vTmhLMEp4SmRtUmF6U2hhekNIcXphZS9WZ3JYYiszN2JMSm43U1NaQlZ5Wm5sYVZTZVA5VGRoN1FXdWRPejBhRlQ2K1ZGWkdNbXIxcFpUNTFWYndsL1MyTWpXaFlzOS9nPT0iLCJ0aW1lc3RhbXBzIjoxNzg5MzE1NzEzNDg2fQ==

{"vipType":"plus"}
```
响应：
```json
{"code":0,"message":"Success","data":{"license":"...","duration":7}}
```
解码：
```json
{"subjectId":"","appKey":"","duration":7,"activeTime":1789315713486,"version":1,
 "code":"OSnBjAdSjwITnO2ASI9namkXHg3vWRMI_plus","vipType":"plus",
 "expireTime":1790006399000,"secret":"z1UNpTRovD7PbqtpzapHE2w7E0wu14h8",
 "signature":"fo5W/ey4XnieOfnZRk6QlR8CCHSKJT3GwQlUn7JYq6u7M7RSxoruPrSw82NF5HIqh0aqu6FsG5csb2/E72Un15cVG9T4..."}
```
`expireTime=1790006399000` = 2026-09-21，7 天专业版。

**Step 3 — 本地验证**（用官方 plus-core 原版验证器）：
```
$ node /tmp/testlic.mjs
[INFO] content: kQth6FHM71IPV3qdWc,GUvNSArDpom7T0d0r3KLJ,OSnBjAdSjwITnO2ASI9namkXHg3vWRMI_plus,z1UNpTRovD7PbqtpzapHE2w7E0wu14h8,plus,1789315713486,7,1790006399000,1
[INFO] 授权校验成功：plus，到期时间：2026-09-21 11:59:59
{
  "verified": true,
  "isPlus": true,
  "isComm": false,
  "expireTime": 1790006399000,
  "vipType": "plus"
}
isPlus(): true
```

**Step 4 — 无限刷（换 siteId 即新主体）**，实测 4 连发：
```
[ kELVBC_73oDN-lG6lAUzs ] secret: 2dLG52tgaW24fwYejzYWkPGUSYF8hYSE  → trialGet(plus): 0 Success  expire 2026-09-21
[ jdrmZRGQirMyVx44RZrTl ] secret: rL16GGXFtjuPrefwTSixLXdVhoFEfNU9  → trialGet(comm): 0 Success  expire 2026-09-21
[ fOib86VHt-Mqaz_Ece6R7 ] secret: uSvDWtDqdT2ziaJ5hr4bSUiBccFGtar9  → trialGet(enterprise): 3 vipType not found（无此类型）
[ miu_3O7TDvgbQwPLCR3OQ ] secret: 0MDQzHU1alIoSdQbbuDHiKE0AwEiXR1D  → trialGet(vip): 3 vipType not found
```
**comm（商业版）试用同样可领**。plus 与 comm 配额独立，同一时间窗可同时持有。

### 影响
- 任何人不花一分钱可持续续 7 天专业版/商业版（到期换 siteId 重注册即可）。
- 对官方激活服务器构成无限低成本滥用面：每注册一个主体即占一条数据库记录。

---

## F-002 自部署实例永久 VIP（公钥替换 + 自签 license）[已证实·高]

### 原理
`plus-core` 的 `localVerify` 用**打包时内置的 RSA 公钥**验 license 签名，公钥以 base64 常量存于 `node_modules/@certd/plus-core/dist/index.js`。自部署实例对该文件有完全控制权：换公钥→自签 license→`expireTime:-1` 永久放行。

**签名内容**（`localVerify` 反编译，逐字段）：
```
content = `${appKey},${subjectId},${code},${secret},${vipType},${activeTime},${duration},${expireTime},${version}`
验签算法 = RSA-SHA256, signature base64
```

### PoC（已完整跑通，文件在 /root/certd/pluscore/）
1. `poc_selfsign.js` + `poc_selfsign_v2.js`：生成 RSA-2048 密钥对（PKCS#1 公钥格式与原 key 一致），patch plus-core 四处（换公钥/禁远程打回/禁自杀定时器/禁远程 license 覆盖）。
2. 自签 `vipType=plus, expireTime=-1` license，独立验签 `true`。
3. 终验回显：
```
verifyLocalOnly: {
  "verified": true, "isPlus": true, "isComm": false,
  "expireTime": -1, "vipType": "plus",
  "secret": "z1UNpTRovD7PbqtpzapHE2w7E0wu14h8", "originVipType": "plus"
}
isPlus(): true
getExpiresTime(): -1 (-1 = 永久)
checkPlus(): 通过 (专业版功能已解锁)
```
4. comm 版同样验证通过：
```
verified: true | vipType: comm | expire: -1 | isComm: true
checkComm(): 通过 (商业版功能已解锁)
checkPlus(): 通过
```

### 一键利用脚本
`/root/certd/pluscore/poc_certd_vip_onclick.js` —— 在 certd 部署目录执行：
```
node poc_certd_vip_onclick.js /path/to/certd
```
自动完成：备份原文件→换公钥→四项逻辑 patch→生成永久 license + 自签私钥。license 落库方式：
```sql
UPDATE sys_settings SET setting = '{"license":"<license_permanent.b64 内容>"}' WHERE setting_key = 'sys.license';
```
或重启后直接由 verify 流程读入。模拟部署验证（simcertd）回显：
```
一键PoC产物验证: verified = true | vipType = plus | expire = -1
checkPlus() 放行 => 专业版全解锁
```

### 边界说明
此路径仅对**自己有 root 权限的自部署实例**有效（能改 node_modules 即能改一切，属于"自己给自己发证"）；对官方 SaaS 无效。但它证明了一个设计缺陷：**离线验签的信任锚放在客户端包里且无服务器端不可篡改绑定**，任何"买断制自部署 + 客户端验签"的商业保护在此架构下均无强制力。

---

## F-003 appKey 硬编码泄露 [已证实·中]

npm 包 `@certd/plus-core/dist/index.js` 中：
```js
let l="<prod公钥b64>", p="kQth6FHM71IPV3qdWc";
"false"===process.env.plus_use_prod&&(
  l="<test公钥b64>",
  p="z4nXOeTeSnnpUpnmsV"
),
"true"===process.env.plus_off&&(p="12132");
```
prod 与 test 两套 appKey + 两套 RSA 公钥全部暴露。appKey 是激活服务器所有接口的必备参数（F-001 的前提之一）。`PLUS_SERVER_BASE_URL` 环境变量可将任意 certd 实例的授权流量重定向到伪造激活服务器（结合 F-002 可做"假激活服务器发真格式 license"）。

---

## F-004 VIP 插件市场无 VIP 鉴权 [已证实·低]

`plugin-service.ts` 的 `installOnlinePlugin` 只调 `/activation/plugin/download`，服务端按主体身份（含免费）返回插件 YAML 全文。实测用 free license 的 secret 拉取成功：
```
POST /api/activation/plugin/page    → total: 8（当前市场插件均无 vip 标记）
POST /api/activation/plugin/download {"fullName":"yfyidc/yfyedgeone"} → code:0，content 即明文 YAML
```
content 首字节：
```
name: yfyedgeone
icon: material-symbols:cloud-lock-outline
title: 易付云EdgeOne授权
```
注：此前一度误判 content 为加密数据（把明文 YAML 再 base64 解码导致乱码），实为明文。当前市场无付费专属插件，此面暂无实际损失，但接口层无 VIP 校验是事实——一旦上架付费插件即成洞。

---

## 已排除项

### F-005 支付回调伪造 [已排除]
`commercial-core` 的 `onPaid` 服务端复核：
```js
const i = this.getThirdPartyPayAmount(t);
if (i !== e.amount) throw new Error(`订单${e.tradeNo}金额不正确, 当前应付金额为${i}，实际支付金额为${e.amount}`);
```
且 `notify` 走 `checkSign`（MD5(key 拼接)，key 为商户密钥不泄露）+ 易支付 `getDetail` 主动查单（`act=order&key=商户密钥`）。伪造回调需商户 key，易支付侧 key 不出网。**除非易支付网关本身被攻破，此路不通。**

### F-006 激活码穷举 [已排除]
`generateCode` 格式：`CDK + productId(4位) + YYYYMMDD + simpleNanoId(10位大写)`，字符集 58^10 ≈ 4.3×10^17，且 use 接口无爆破反馈通道（不存在/已使用/已禁用区分报错，但每次都需登录态 + 审计日志），穷举不可行。批量生成接口 `/generate` 需 `sys:settings:edit` 权限。

### F-007 RSA 签名伪造 [已排除]
公钥 RSA-2048 / e=65537（已实测模长）。Bleichenbacher 类低指数签名伪造不适用（e=65537 非小指数，且验签用标准 createVerify 走完整 PKCS#1 v1.5 解码）。

---

## 攻击链示意

```
┌─ 通道A: 白嫖官方 VIP（对 SaaS 和自部署均有效）
│  自造 nanoid siteId → POST /register (无鉴权) → 得 secret
│   → SHA256 签名 → POST /vip/trialGet {"vipType":"plus"}  → 7天专业版
│   → 同主体 {"vipType":"comm"}                            → 7天商业版
│   → 到期/领完 → 换 siteId 重复                           → ∞ 续期
│
├─ 通道B: 自部署永久 VIP（自持服务器）
│  patch node_modules/@certd/plus-core/dist/index.js（换公钥+4处逻辑）
│   → 自签 RSA license (expireTime:-1, vipType:plus/comm)
│   → 写入 sys.license → isPlus()/isComm() 永久 true
│
└─ 通道C（未走通）: 支付伪造 → 金额服务端复核拦截
```

## 下一步路径（如需续打）

1. **试用配额服务端策略**：`trialGet` 对同一主体 plus/comm 各一次——测试同主体删除重注册（`/activation/subject/delete` 类接口若存在）能否原地重领。
2. **`refreshLicense` 竞态**：`doVipCheck` 返回 expiresAt/vipType 与本地不一致时自动拉新 license——若能用两个主体交替 check（主体A 到期、主体B 有效），观察服务端是否按 subjectId 严格隔离（本次未测，属授权服务器深度 fuzz）。
3. **推广/佣金体系**（`/api/invite`、wallet）：`settleCommission` 按 paidAmount 分佣——若退款流程与佣金结算存在时间差，可能构造负利润套现。属业务逻辑面，需真实订单环境验证。

## 本地文件

| 文件 | 说明 |
|---|---|
| `/root/certd/certd/` | certd 开源主仓库 |
| `/root/certd/pluscore/package/dist/index.js` | plus-core 原版 + patched 版（.orig 备份） |
| `/root/certd/pluscore/poc_selfsign.js` / `poc_selfsign_v2.js` | 自签永久 license PoC |
| `/root/certd/pluscore/poc_certd_vip_onclick.js` | 一键利用脚本（自部署实例） |
| `/root/certd/pluscore/license_permanent.b64` | 永久 plus license（已验证） |
| `/root/certd/pluscore/license_permanent_comm.b64` | 永久 comm license（已验证） |
| `/root/certd/pluscore/trial_license.b64` | 7 天试用 license（F-001 实证） |
| `/root/certd/pluscore/selfsign_key.pem` | PoC 自签私钥（仅 PoC 用途） |

---

*本报告所有回显均为真实请求/运行结果，无伪造。测试仅创建自造主体与下载公开市场插件，未访问任何第三方用户数据。*
