// PoC v3: comm (商业版) 永久 license —— 同一把自签密钥, vipType=comm
const crypto = require('crypto');
const fs = require('fs');
const priv = fs.readFileSync('/root/certd/pluscore/selfsign_key.pem', 'utf8');
const license = {
  subjectId: '', appKey: '', duration: -1, activeTime: Date.now(), version: 1,
  code: 'POC_SELF_SIGNED_COMM', vipType: 'comm', expireTime: -1,
  secret: 'z1UNpTRovD7PbqtpzapHE2w7E0wu14h8',
};
const content = `kQth6FHM71IPV3qdWc,GUvNSArDpom7T0d0r3KLJ,${license.code},${license.secret},${license.vipType},${license.activeTime},${license.duration},${license.expireTime},${license.version}`;
license.signature = crypto.createSign('RSA-SHA256').update(content).sign(priv, 'base64');
const b64 = Buffer.from(JSON.stringify(license)).toString('base64');
fs.writeFileSync('/root/certd/pluscore/license_permanent_comm.b64', b64);
console.log('[+] comm 永久 license 生成完毕');
