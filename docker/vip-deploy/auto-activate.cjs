// certd VIP 自动激活: 等 siteId 落库 → 向 fake-plus-server register → 写 sys.license
const wait = (ms) => new Promise((r) => setTimeout(r, ms));
async function main() {
  const Database = require('/app/node_modules/better-sqlite3');
  const port = process.env.CERTD_FAKE_SERVER_PORT || '11007';
  const url = `http://127.0.0.1:${port}`;
  for (let k = 1; k <= 240; k++) {
    await wait(5000);
    let db, siteId, licEmpty;
    try {
      db = new Database('/app/data/db.sqlite', { timeout: 5000 });
      const row = db.prepare("SELECT setting FROM sys_settings WHERE key='sys.install'").get();
      if (!row) continue;
      const inst = JSON.parse(row.setting);
      siteId = inst && inst.siteId;
      if (!siteId) continue;
      const lic = db.prepare("SELECT setting FROM sys_settings WHERE key='sys.license'").get();
      licEmpty = !(lic && JSON.parse(lic.setting || '{}').license);
    } catch (e) { continue; }
    if (!licEmpty) { console.log('[auto-activate] license 已存在, 退出'); process.exit(0); }
    try {
      const r = await fetch(url + '/api/activation/subject/register', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ appKey: 'kQth6FHM71IPV3qdWc', subjectId: siteId, installTime: Date.now() }),
      });
      const j = await r.json();
      if (j.code !== 0 || !j.data || !j.data.license) { console.log('[auto-activate] fake server 返回:', JSON.stringify(j)); continue; }
      db.prepare("UPDATE sys_settings SET setting=? WHERE key='sys.license'").run(JSON.stringify({ license: j.data.license }));
      console.log(`[auto-activate] ✓ license 已按 siteId=${siteId} 写库. 触发 certd 进程重启使其立即生效...`);
      await wait(3000);
      // 如果身为 PID1 (entrypoint exec 场景) — 直接退出, docker restart: unless-stopped 会拉起, 拉起后 license 即生效
      if (process.pid === 1) {
        console.log('[auto-activate] PID1 退出使容器重启 (restart:unless-stopped 拉起后即生效)');
        process.exit(0);
      }
      // 否则尝试 kill certd 子进程
      try {
        const { execSync } = require('child_process');
        const out = execSync(
          "for d in /proc/[0-9]*/; do c=$(tr '\\0' ' ' < $d/cmdline 2>/dev/null); case \"$c\" in *bootstrap.js*) echo ${d//[^0-9]/};; esac; done | head -1",
          { shell: '/bin/sh', encoding: 'utf8' }).trim();
        if (out) { execSync('kill ' + out); console.log('[auto-activate] 已 kill certd pid=' + out); }
      } catch (e) { console.log('[auto-activate] kill err:', e.message); }
      console.log('[auto-activate] 完成');
      process.exit(0);
    } catch (e) { console.log('[auto-activate] fetch err:', e.message); }
  }
  console.log('[auto-activate] 超时退出');
  process.exit(1);
}
main();
