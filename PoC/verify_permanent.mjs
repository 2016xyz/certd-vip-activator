// 终验: patched plus-core + 自签永久 license => isPlus() 永久 true
const mod = await import('/root/certd/pluscore/package/dist/index.js');
const fs = await import('fs');
const lic = fs.readFileSync('/root/certd/pluscore/license_permanent.b64', 'utf8').trim();
const res = await mod.verifyLocalOnly({
  subjectId: 'GUvNSArDpom7T0d0r3KLJ',
  license: lic,
});
console.log('verifyLocalOnly:', JSON.stringify(res, null, 2));
console.log('isPlus():', mod.isPlus());
console.log('getVipType():', mod.getVipType());
console.log('getExpiresTime():', mod.getExpiresTime(), '(-1 = 永久)');
console.log('getSecret():', mod.getSecret());
// checkPlus 不抛异常即认为专业版功能放行
try { mod.checkPlus(); console.log('checkPlus(): 通过 (专业版功能已解锁)'); }
catch (e) { console.log('checkPlus() 抛异常:', e.message); }
try { mod.checkComm(); console.log('checkComm(): 通过'); }
catch (e) { console.log('checkComm():', e.message); }
