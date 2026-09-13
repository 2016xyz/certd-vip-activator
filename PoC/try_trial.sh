#!/usr/bin/env bash
# 白嫖 certd 官方激活服务器 7 天 VIP 试用（到期换 siteId 无限续）
# 前置: node ≥ 18, 自己可任意访问外网
# 用法: bash try_trial.sh [vipType]   (plus|comm)
set -e

VIP_TYPE="${1:-plus}"
API="https://api.handfree.work/api"
APP_KEY="kQth6FHM71IPV3qdWc"

node -e "
(async()=>{
  const crypto=require('crypto');
  const http='$API';
  const APP_KEY='$APP_KEY';
  const VIP_TYPE='$VIP_TYPE';

  // 真正的 nanoid（字符表与官方一致）
  const urlAlphabet='useandom26T198340PX75pxJACKVERYMINDBUSHWOLFGQZbfghjklqvwyzrict';
  function nanoid(size=21){
    let id=''; const b=crypto.randomBytes(size);
    for(let i=0;i<size;i++) id+=urlAlphabet[b[i]&63];
    return id;
  }
  function sha256(s){return crypto.createHash('sha256').update(s).digest('base64');}

  // 1. 注册
  const sid=nanoid();
  let r=await fetch(http+'/activation/subject/register',{
    method:'POST',headers:{'Content-Type':'application/json'},
    body:JSON.stringify({appKey:APP_KEY,subjectId:sid,installTime:Date.now()})});
  let j=await r.json();
  if(j.code!==0){console.error('注册失败:', JSON.stringify(j));process.exit(1);}
  const secret=JSON.parse(Buffer.from(j.data.license,'base64').toString()).secret;
  console.log('[✓] siteId:', sid);
  console.log('[✓] secret:', secret);

  // 2. 签名领 VIP 试用
  const data={vipType:VIP_TYPE};
  const ts=Date.now();
  const sign=sha256(JSON.stringify(data)+'.'+ts+'.'+secret);
  const header=Buffer.from(JSON.stringify({subjectId:sid,appKey:APP_KEY,sign,timestamps:ts})).toString('base64');
  r=await fetch(http+'/activation/subject/vip/trialGet',{
    method:'POST',headers:{'Content-Type':'application/json','X-Plus-Subject':header},
    body:JSON.stringify(data)});
  j=await r.json();
  if(j.code!==0){console.error('trialGet 失败:', JSON.stringify(j));process.exit(1);}
  const lic=JSON.parse(Buffer.from(j.data.license,'base64').toString());
  console.log('[✓] 已签发', lic.vipType, 'license, 有效期至', new Date(lic.expireTime).toISOString());
  require('fs').writeFileSync('trial_'+VIP_TYPE+'_'+sid+'.b64', j.data.license);
  console.log('[✓] license 已保存到 trial_'+VIP_TYPE+'_'+sid+'.b64');
  console.log('');
  console.log('[→] 到期/已领过则 bash try_trial.sh '+VIP_TYPE+' 重跑, 自造新 siteId 无限续');
  console.log('[→] 想要 comm: bash try_trial.sh comm');
})().catch(e=>{console.error('ERR:',e.message);process.exit(1)});
"
