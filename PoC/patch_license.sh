#!/bin/bash
# 手动 patch 既有 certd 实例的 license（deploy.sh 内部使用，也可独立调用）
# 用法: bash patch_license.sh [certd容器名|源码目录] [fake_server_url]
set -e

TARGET="${1:-certd}"
FAKE="${2:-http://certd-fake-plus-server:11007}"

if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${TARGET}$"; then
  echo "[*] 容器模式: certd=$TARGET, fake=$FAKE"
  docker exec "$TARGET" node -e "
(async()=>{
  const Database=require('better-sqlite3');
  const db=new Database('/app/data/db.sqlite');
  let siteId;
  for(let i=0;i<10;i++){
    const row=db.prepare(\"SELECT setting FROM sys_settings WHERE key='sys.install'\").get();
    if(row&&JSON.parse(row.setting).siteId){siteId=JSON.parse(row.setting).siteId;break;}
    await new Promise(r=>setTimeout(r,2000));
  }
  if(!siteId){console.error('未等到 siteId');process.exit(1);}
  console.log('siteId:', siteId);
  const r=await fetch('${FAKE}/api/activation/subject/register',{
    method:'POST',headers:{'Content-Type':'application/json'},
    body:JSON.stringify({appKey:'kQth6FHM71IPV3qdWc',subjectId:siteId,installTime:Date.now()})});
  const j=await r.json();
  if(j.code!==0)throw new Error('fake server 异常:'+JSON.stringify(j));
  const exists=db.prepare(\"SELECT COUNT(*) c FROM sys_settings WHERE key='sys.license'\").get();
  if(exists.c>0){
    db.prepare(\"UPDATE sys_settings SET setting=? WHERE key='sys.license'\").run(JSON.stringify({license:j.data.license}));
  } else {
    db.prepare(\"INSERT INTO sys_settings (key,title,setting,access) VALUES ('sys.license','授权许可信息',?, 'private')\").run(JSON.stringify({license:j.data.license}));
  }
  console.log('✓ license 已写库');
})().catch(e=>{console.error('ERR',e.message);process.exit(1)});
"
  echo "[*] 重启 certd 完成激活"
  docker restart "$TARGET"
  sleep 20
  docker logs "$TARGET" --since 1m 2>&1 | grep -E "授权校验成功" && \
    echo "✓ VIP 激活成功" || echo "⚠ 未见授权成功日志, 请检查 fake server 日志"
else
  echo "[*] 目录模式: $TARGET"
  cd "$TARGET"
  node -e "
(async()=>{
  const Database=require('better-sqlite3');
  const db=new Database('./data/db.sqlite');
  const row=db.prepare(\"SELECT setting FROM sys_settings WHERE key='sys.install'\").get();
  const siteId=JSON.parse(row.setting).siteId;
  const r=await fetch('${FAKE}/api/activation/subject/register',{
    method:'POST',headers:{'Content-Type':'application/json'},
    body:JSON.stringify({appKey:'kQth6FHM71IPV3qdWc',subjectId:siteId,installTime:Date.now()})});
  const j=await r.json();
  const exists=db.prepare(\"SELECT COUNT(*) c FROM sys_settings WHERE key='sys.license'\").get();
  if(exists.c>0){
    db.prepare(\"UPDATE sys_settings SET setting=? WHERE key='sys.license'\").run(JSON.stringify({license:j.data.license}));
  } else {
    db.prepare(\"INSERT INTO sys_settings (key,title,setting,access) VALUES ('sys.license','授权许可信息',?, 'private')\").run(JSON.stringify({license:j.data.license}));
  }
  console.log('✓ license 已写库');
})().catch(e=>{console.error('ERR',e.message);process.exit(1)});
"
fi
