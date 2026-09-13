/**
 * certd VIP 一键激活（自部署实例版）
 * ============================================
 * 在 certd 部署根目录执行:
 *   node poc_certd_vip_onclick.js <certd根目录>
 * 产物:
 *   - node_modules/@certd/plus-core/dist/index.js 已 patch（原版备份 .orig）
 *   - license_permanent.b64（永久 plus license）
 *   - selfsign_key.pem（自签私钥, 勿上传/勿提交仓库）
 * 使用者自部署时也可不依赖本脚本，用 patched/ 里的成品直接替换。
 */
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');

const certdRoot = process.argv[2] || process.cwd();
const plusCorePath = path.join(certdRoot, 'node_modules/@certd/plus-core/dist/index.js');
if (!fs.existsSync(plusCorePath)) {
  console.error('[!] 未找到', plusCorePath);
  console.error('    请在 certd 部署目录运行（需已完成 pnpm install / npm install）');
  process.exit(1);
}

// ── 1. 生成自持 RSA-2048 密钥对 ──
const { privateKey, publicKey } = crypto.generateKeyPairSync('rsa', {
  modulusLength: 2048,
  privateKeyEncoding: { type: 'pkcs8', format: 'pem' },
  publicKeyEncoding: { type: 'pkcs1', format: 'pem' }, // BEGIN RSA PUBLIC KEY
});
const pubB64 = Buffer.from(publicKey).toString('base64');

// ── 2. 构造永久 license（expireTime=-1 即永久）──
const appKey = 'kQth6FHM71IPV3qdWc';
const subjectId = process.env.CERTD_SITE_ID || 'LOCAL_SITE_ID';
const secret = process.env.CERTD_SECRET || 'LOCAL_SECRET';
const license = {
  subjectId: '', appKey: '', duration: -1, activeTime: Date.now(), version: 1,
  code: 'SELF_HOSTED_PERMANENT', vipType: process.env.VIP_TYPE || 'plus',
  expireTime: -1, secret,
};
const content = `${appKey},${subjectId},${license.code},${license.secret},${license.vipType},${license.activeTime},${license.duration},${license.expireTime},${license.version}`;
license.signature = crypto.createSign('RSA-SHA256').update(content).sign(privateKey, 'base64');
const licenseB64 = Buffer.from(JSON.stringify(license)).toString('base64');

// ── 3. patch plus-core（4处）──
let src = fs.readFileSync(plusCorePath, 'utf8');
const backup = plusCorePath + '.orig';
if (!fs.existsSync(backup)) fs.writeFileSync(backup, src);

const m = src.match(/let l="([A-Za-z0-9+/=]+)"/);
if (!m) { console.error('[!] 公钥常量定位失败'); process.exit(1); }
src = src.replace(m[0], `let l="${pubB64}"`);

// patch1: 禁用远程 check 失败时的打回逻辑
src = src.replace(
  'if(e.ok)m()||await this.reLocalVerify(this.licenseReq);else if(!1===e.ok){const t=e.message;return m()?(r.error("vip校验失败，退回基础版，原因："+t),this.setLicenseInfo(!1,{message:t,expireTime:e.expiresAt})):void 0}',
  'if(e.ok){m()||await this.reLocalVerify(this.licenseReq)}'
);
// patch2: 禁用启动自杀定时器
src = src.replace(
  'return e.info("license 校验失败!!!"),function(){const e=Math.floor(1e3*Math.random()*60*60);setTimeout(()=>{console.log("11111"),process.exit(0)},e)}();',
  'return e.info("license ok");'
);
// patch3: 禁用 refreshLicense 远程覆盖本地 license
src = src.replace('if(y()!=e.expiresAt||U()!=e.vipType&&g()!=e.vipType){', 'if(false){');

fs.writeFileSync(plusCorePath, src);

// ── 4. 落盘产物 ──
fs.writeFileSync(path.join(certdRoot, 'license_permanent.b64'), licenseB64);
fs.writeFileSync(path.join(certdRoot, 'selfsign_key.pem'), privateKey);
console.log('[+] plus-core 已 patch（原文件备份 .orig）');
console.log('[+] 永久 license:', path.join(certdRoot, 'license_permanent.b64'));
console.log('[+] 自签私钥:', path.join(certdRoot, 'selfsign_key.pem'), '（妥善保管）');
console.log('[+] 下一步: 重启 certd，或手动 UPDATE 数据库 sys.license 设置');
