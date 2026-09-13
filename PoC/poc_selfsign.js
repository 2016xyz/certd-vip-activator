// PoC: certd 自部署实例永久 VIP 激活
// 原理: plus-core 本地验签使用内置 RSA 公钥, 对自部署实例可替换为自持密钥对
// 产出: 1) 自签永久 license  2) patched plus-core  3) 本地验证 isPlus()=true
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');

const PKG = '/root/certd/pluscore/package/dist/index.js';

// 1. 生成攻击者控制的 RSA 密钥对
const { publicKey, privateKey } = crypto.generateKeyPairSync('rsa', {
  modulusLength: 2048,
  publicKeyEncoding: { type: 'spki', format: 'pem' },
  privateKeyEncoding: { type: 'pkcs8', format: 'pem' },
});
// plus-core 用 createVerify('RSA-SHA256') + PEM "RSA PUBLIC KEY" 头
const pubPem = publicKey
  .replace('BEGIN PUBLIC KEY', 'BEGIN RSA PUBLIC KEY')
  .replace('END PUBLIC KEY', 'END RSA PUBLIC KEY');
const pubB64 = Buffer.from(pubPem).toString('base64');

// 2. 构造永久 license (expireTime = -1 即永久, vipType 可为 plus/comm)
const subjectId = 'GUvNSArDpom7T0d0r3KLJ'; // 本地实例的 siteId
const license = {
  subjectId: '',
  appKey: '',
  duration: -1,
  activeTime: Date.now(),
  version: 1,
  code: 'POC_SELF_SIGNED_PERMANENT',
  vipType: 'plus',
  expireTime: -1, // -1 = 永久
  secret: 'z1UNpTRovD7PbqtpzapHE2w7E0wu14h8',
};
// 3. 签名内容与 plus-core 完全一致: appKey,subjectId,code,secret,vipType,activeTime,duration,expireTime,version
const content = `kQth6FHM71IPV3qdWc,${subjectId},${license.code},${license.secret},${license.vipType},${license.activeTime},${license.duration},${license.expireTime},${license.version}`;
const signature = crypto.createSign('RSA-SHA256').update(content).sign(privateKey, 'base64');
license.signature = signature;
const licenseB64 = Buffer.from(JSON.stringify(license)).toString('base64');

// 4. patch plus-core: 替换内置公钥 + 关闭远程 check 打回逻辑
let src = fs.readFileSync(PKG, 'utf8');
// 4a. 替换公钥常量 (第一个 let l="..." prod key)
const origKeyMatch = src.match(/let l="([A-Za-z0-9+/=]+)"/);
if (!origKeyMatch) throw new Error('未找到公钥常量');
src = src.replace(origKeyMatch[0], `let l="${pubB64}"`);
// 4b. 禁用远程 check 的打回: verifyFromRemote 中 ok===false 时 m() 为 true 会退回 free
//     最稳妥: 让 doCheckFromRemote 失败走 catch(仅打日志不打回); patch: ok!==true 时直接 return
src = src.replace(
  'if(e.ok)m()||await this.reLocalVerify(this.licenseReq);else if(!1===e.ok){const t=e.message;return m()?(r.error("vip校验失败，退回基础版，原因："+t),this.setLicenseInfo(!1,{message:t,expireTime:e.expiresAt})):void 0}',
  'if(e.ok){m()||await this.reLocalVerify(this.licenseReq)}'
);
// 4c. 禁用启动自杀定时器 (m()&&!h.secret 时随机退出) —— 我们有 secret, 双保险
src = src.replace('return e.info("license 校验失败!!!"),function(){const e=Math.floor(1e3*Math.random()*60*60);setTimeout(()=>{console.log("11111"),process.exit(0)},e)}();', 'return e.info("license ok");');
// 4d. 阻止 refreshLicense 拉远端把自签 license 覆盖掉: patch verify() 的 doCheckFromRemote 判断
src = src.replace('if(y()!=e.expiresAt||U()!=e.vipType&&g()!=e.vipType){', 'if(false){');

fs.writeFileSync(PKG, src);
fs.writeFileSync('/root/certd/pluscore/selfsign_key.pem', privateKey);
fs.writeFileSync('/root/certd/pluscore/selfsign_pub.pem', pubPem);
fs.writeFileSync('/root/certd/pluscore/license_permanent.b64', licenseB64);
console.log('[+] patched plus-core 公钥替换完成');
console.log('[+] 永久 license 已生成: /root/certd/pluscore/license_permanent.b64');
console.log('[+] license 解码:', JSON.stringify(license, null, 2).slice(0, 400));
console.log('[+] 签名内容:', content);
