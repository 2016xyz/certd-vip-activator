// PoC v2: 生成 PKCS#1 格式公钥 (BEGIN RSA PUBLIC KEY), 与原内置 key 格式一致
const crypto = require('crypto');
const fs = require('fs');
const PKG = '/root/certd/pluscore/package/dist/index.js';

// 从 selfsign_key.pem (pkcs8) 导出 pkcs1 公钥
const pkcs8 = fs.readFileSync('/root/certd/pluscore/selfsign_key.pem', 'utf8');
const keyObj = crypto.createPrivateKey(pkcs8);
const pubPkcs1 = keyObj.export({ type: 'pkcs1', format: 'pem' }); // BEGIN RSA PUBLIC KEY
const pubB64 = Buffer.from(pubPkcs1).toString('base64');

// license 内容不变, 重新 patch 公钥 (v1 已把 key 换成坏格式, 现在替换成正确的)
let src = fs.readFileSync(PKG, 'utf8');
// 找当前 let l="..." (v1 写入的错误公钥) —— 用正则匹配当前值整体替换
const m = src.match(/let l="([A-Za-z0-9+/=]+)"/);
if (!m) throw new Error('公钥常量未找到');
src = src.replace(m[0], `let l="${pubB64}"`);
fs.writeFileSync(PKG, src);

// 校验转换正确: 用自签私钥验一遍自签内容
const licenseRaw = fs.readFileSync('/root/certd/pluscore/license_permanent.b64', 'utf8').trim();
const lic = JSON.parse(Buffer.from(licenseRaw, 'base64').toString());
const content = `kQth6FHM71IPV3qdWc,GUvNSArDpom7T0d0r3KLJ,${lic.code},${lic.secret},${lic.vipType},${lic.activeTime},${lic.duration},${lic.expireTime},${lic.version}`;
const v = crypto.createVerify('RSA-SHA256');
v.update(content);
const ok = v.verify(pubPkcs1, lic.signature, 'base64');
console.log('[+] 新公钥(pem):', pubPkcs1.split('\n')[1].slice(0, 40) + '...');
console.log('[+] 独立验签(密钥对自洽):', ok);
console.log('[+] patched plus-core 公钥已更新为 PKCS#1');
