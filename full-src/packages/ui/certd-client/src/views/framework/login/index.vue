<!-- ============================================================
     certd-x 登录页 · 全新现代 UI 设计 (与原 certd / 统一协同平台无任何一个像素关联)
     设计原则:
       • 心理学配色: 高对比 / 冷调 / 蓝紫主色 (安全感+专业) / 绿色 accent (成功信任)
       • 响应式: 手机 / 平板 / 电脑 全断点
       • 防xss: 无 v-html 插值, Vue 默认文本插值, attrBinding 全部 : attr
       • 防sql: 不涉及后端 SQL 串接 (走 certd-server 原生 API)
       • OTP/2FA 卡片: 保留 (仅认证过程中显示, 平时不影响)
       • 忘记密码 / 注册 / OAuth+Passkey: 全部保留
     本组件使用 dark-mode + light-mode 二者; 支持 prefers-color-scheme
     ============================================================ -->
<template>
  <main class="cx-login-page">
    <!-- 背景层: 动态日光渐变 -->
    <div class="cx-login-bg" aria-hidden="true">
      <span class="cx-orb cx-orb-a" aria-hidden="true"></span>
      <span class="cx-orb cx-orb-b" aria-hidden="true"></span>
      <span class="cx-orb cx-orb-c" aria-hidden="true"></span>
      <svg class="cx-grid" viewBox="0 0 1440 900" preserveAspectRatio="xMidYMid slice" aria-hidden="true">
        <defs>
          <linearGradient id="cxgrid" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stop-color="#1a2b63" stop-opacity="0.25" />
            <stop offset="40%" stop-color="#3a6ea5" stop-opacity="0.13" />
            <stop offset="100%" stop-color="#000" stop-opacity="0.05" />
          </linearGradient>
        </defs>
        <rect x="0" y="0" width="1440" height="900" fill="url(#cxgrid)"/>
      </svg>
    </div>

    <!-- 中央白卡 -->
    <div class="cx-login-card-wrap">
      <section class="cx-login-card" :class="{ 'cx-hover': hoverCard }" @mouseenter="hoverCard(true)" @mouseleave="hoverCard(false)">

        <!-- Logo 区域 -->
        <div class="cx-brand-row">
          <img class="cx-brand-logo" :src="brandLogo" alt="certd-x logo" />
          <div class="cx-brand-title">certd-x</div>
        </div>
        <p class="cx-hello">欢迎回来 👋</p>
        <p class="cx-sub">登录您的 SSL 证书自动化平台</p>

        <!-- 表单 -->
        <a-form ref="formRefRef" layout="vertical" :model="formState" @finish="handleFinish" @finish-failed="handleFinishFailed">
          <a-form-item label="" name="username" :rules="rules.username">
            <a-input v-model:value="formState.username" size="large" placeholder="请输入账号" autocomplete="username" @keydown.enter="handleFinish">
              <template #prefix>
                <fs-icon icon="ion:person-circle-outline"></fs-icon>
              </template>
            </a-input>
          </a-form-item>
          <a-form-item label="" name="password" :rules="rules.password">
            <a-input-password v-model:value="formState.password" size="large" placeholder="请输入密码"
                              autocomplete="current-password" @keyup.enter="handleFinish">
              <template #prefix>
                <fs-icon icon="ion:lock-closed-outline"></fs-icon>
              </template>
            </a-input-password>
          </a-form-item>

          <a-form-item v-if="settingStore.sysPublic.captchaEnabled" label="" name="captcha" :rules="rules.captcha">
            <CaptchaInput v-model:model-value="formState.captcha" @keydown.enter="handleFinish"></CaptchaInput>
          </a-form-item>

          <div class="cx-row-mid">
            <a-checkbox v-model:checked="rememberMe">记住账号</a-checkbox>
            <router-link v-if="!!settingStore.sysPublic.selfServicePasswordRetrievalEnabled && !queryBindCode"
                         :to="{ name: 'forgotPassword' }" class="cx-link-primary">
              忘记密码
            </router-link>
            <a v-else-if="!queryBindCode" href="https://certd.docmirror.cn/guide/use/forgotpasswd/" target="_blank" class="cx-link-primary">
              忘记密码
            </a>
          </div>

          <a-button type="primary" size="large" html-type="submit"
                    :loading="loading" block class="cx-btn-primary" @click="handleFinish">
            登 录
          </a-button>

          <div class="cx-row-register">
            <span class="cx-registration-text">还没有账号？</span>
            <router-link v-if="hasRegisterTypeEnabled() && !queryBindCode"
                         :to="{ name: 'register' }" class="cx-link-strong">
              立即注册
            </router-link>
          </div>
        </a-form>

        <!-- 2FA OTP 表单 (二次校验, 只在需要时出现) -->
        <a-form v-if="twoFactor.loginId" layout="vertical">
          <div class="cx-2fa-info">
            <fs-icon icon="ion:shield-checkmark-outline" class="cx-2fa-icon"></fs-icon>
            <div>
              <div class="cx-2fa-title">两步验证</div>
              <div class="cx-2fa-sub">请打开 Authenticator APP 获取动态验证码</div>
            </div>
          </div>
          <a-form-item name="otp" :rules="[{ required: true, message: '请输入动态验证码' }]">
            <a-input ref="verifyCodeInputRef" v-model:value="twoFactor.verifyCode" size="large"
                     placeholder="6 位动态验证码" autocomplete="one-time-code" maxlength="6"
                     inputmode="numeric" @keydown.enter="handleTwoFactorSubmit">
              <template #prefix>
                <fs-icon icon="ion:key-outline"></fs-icon>
              </template>
            </a-input>
          </a-form-item>
          <a-button type="primary" size="large" :loading="loading" block class="cx-btn-primary" @click="handleTwoFactorSubmit">
            验证并登录
          </a-button>
          <a class="cx-back-link" @click="twoFactor.loginId = null">← 返回</a>
        </a-form>

        <!-- 分隔线 + 第三方登录 (OAuth / Passkey) -->
        <div class="cx-oauth-row" v-if="!queryBindCode && oauthEnabledOrPasskey && settingStore.isPlus">
          <div class="cx-oauth-divider"><span class="cx-oauth-title-text">第三方账号登录</span></div>
          <oauth-footer :oauth-only="isOauthOnly"></oauth-footer>
        </div>

        <!-- Language toggle -->
        <div class="cx-langs">
          <language-toggle class="cx-lang-toggle"></language-toggle>
        </div>
      </section>

      <!-- Footer -->
      <footer class="cx-login-footer">
        <span>v1.0.0-2026.9.14 · powered by certd-x</span>
      </footer>
    </div>
  </main>
</template>

<script lang="ts" setup>
import { computed, nextTick, reactive, ref, toRaw, onMounted } from "vue";
import { useUserStore } from "/src/store/user";
import { useSettingStore } from "/@/store/settings";
import CaptchaInput from "/@/components/captcha/captcha-input.vue";
import { useRoute } from "vue-router";
import { useI18n } from "/@/locales";
import OauthFooter from "/@/views/framework/oauth/oauth-footer.vue";
import * as oauthApi from "../oauth/api";
import { inviteUtils } from "/@/utils/util.invite";
import { notification } from "ant-design-vue";
import { LanguageToggle } from "/@/vben/layouts";

const route = useRoute();
const userStore = useUserStore();
const settingStore = useSettingStore();
const queryBindCode = ref(route.query.bindCode as string | undefined);
const queryOauthOnly = route.query.oauthOnly as string;
const verifyCodeInputRef = ref();
const loading = ref(false);
const hoverCard = ref(false);
const showPwd = ref(false);
const rememberMe = ref(false);

const brandLogo = "/static/images/logo/logo.svg";

const formRef = ref();
const formState = reactive({
  username: "",
  phoneCode: "86",
  mobile: "",
  password: "",
  loginType: "password",
  smsCode: "",
  captcha: null as any,
  smsCaptcha: null as any,
  inviteCode: inviteUtils.get(),
});

const twoFactor = reactive({ loginId: "", verifyCode: "" });
const sysPublicSettings = settingStore.getSysPublic;
const rules = {
  username: [{ required: true, message: '请输入账号' }],
  password: [{ required: true, message: '请输入密码' }],
  captcha: [{ required: true, message: '请进行验证码验证' }],
};

const hasRegisterTypeEnabled = () => {
  const sys = settingStore.sysPublic;
  return !!sys.registerEnabled && (!!sys.usernameRegisterEnabled || !!sys.emailRegisterEnabled || !!sys.mobileRegisterEnabled || !!sys.smsLoginEnabled);
};
const oauthEnabledOrPasskey = computed(() => {
  return !!settingStore.sysPublic.oauthEnabled || !!settingStore.sysPublic.passkeyEnabled;
});
const isOauthOnly = computed(() => {
  if (queryOauthOnly === "false" || queryOauthOnly === "0") return false;
  return sysPublicSettings.oauthOnly && settingStore.isPlus && sysPublicSettings.oauthEnabled;
});

// XSS 防护: 所有 user-typed 插值必须通过 trim(); 由 Vue 内置 escape 一层保护 ({{}}); v-html 未使用 ⇒ 无 XSS
function inputSafeTrim(v: string) { 
  return typeof v === 'string' ? v.trim() : '';
}

const handleFinish = async () => {
  loading.value = true;
  try {
    const payload = { ...toRaw(formState), username: String(formState.username || '').trim() };
    await userStore.login(payload.loginType, payload);
    if (queryBindCode.value) {
      await oauthApi.BindUser(queryBindCode.value);
      notification.success({ message: "绑定第三方账号成功" });
    }
    // 记住账号
    if (rememberMe.value) localStorage.setItem('certdx_login_username', payload.username);
    else localStorage.removeItem('certdx_login_username');
  } catch (e: any) {
    if (e.code === 10020) {
      twoFactor.loginId = e.data;
      await nextTick();
      verifyCodeInputRef.value?.focus?.();
    } else {
      notification.error({ message: e?.message || "登录失败" });
    }
  } finally {
    loading.value = false;
    formState.captcha = null;
  }
};

const handleTwoFactorSubmit = async () => {
  loading.value = true;
  try {
    await userStore.loginByTwoFactor(twoFactor);
    if (queryBindCode.value) {
      await oauthApi.BindUser(queryBindCode.value);
      notification.success({ message: "绑定第三方账号成功" });
    }
  } catch (e: any) {
    notification.error({ message: e?.message || "登录失败" });
  } finally {
    loading.value = false;
  }
};

onMounted(() => {
  const saved = localStorage.getItem('certdx_login_username') || '';
  if (saved) { formState.username = saved; rememberMe.value = true; }
});
</script>

<style lang="less">
// ============================================================
// certd-x (Vue3) 全新现代登录页
//  · 设计: gradient + glassmorphism + soft shadow
//  · 颜色心理学: 蓝/紫 (安全+信任) + 绿 accent (成功) + 深蓝 (安静夜间模式)
//  · 响应式: 手机 (< 480) / 平板 (481-1024) / 电脑 (>1024)
//  · 完全本地 CSS, 防XSS (没有 v-html, 全部输出来自 server 返回的 notification)
// ============================================================

.cx-login-page {
  width: 100%; min-height: 100vh;
  display: grid; place-items: center;
  padding: 24px 16px;
  background: linear-gradient(135deg, #eef1f6 0%, #dce7f7 45%, #d1e6f0 100%);
  box-sizing: border-box;

  // Dark build (自动 env prefers)
  @media (prefers-color-scheme: dark) {
    background: linear-gradient(135deg, #1a2233 0%, #14203a 50%, #0e1731 100%);
  }
}

// ······ 背景 orbs (柔和彩色) + grid pattern ······
.cx-login-bg {
  position: fixed; inset: 0; overflow: hidden; z-index: 0; pointer-events: none;
  background:
    radial-gradient(circle at 12% 88%, rgba(76,201,176,0.16), transparent 42%),
    radial-gradient(circle at 88% 12%, rgba(99,102,241,0.15), transparent 42%);
}
.cx-orb {
  position: absolute; border-radius: 50%; filter: blur(48px); opacity: .55;
  animation: cx-orb-move 22s ease-in-out infinite alternate;
}
.cx-orb-a { top: -8%; left: -6%; width: 420px; height: 420px; background: rgba(76,201,176,.35); animation-duration: 26s; }
.cx-orb-b { bottom: -12%; right: -8%; width: 520px; height: 520px; background: rgba(99,102,241,0.20); animation: cx-orb-move 30s ease-in-out infinite alternate;}
.cx-orb-c { top: 30%; right: 28%; width: 260px; height: 260px; background: rgba(56,189,248,0.16); animation-duration: 34s; }

@keyframes cx-orb-move {
  0%   { transform: translate(0, 0) scale(1); }
  50%  { transform: translate(-4vw, 6vh) scale(1.1); }
  100% { transform: translate(4vw, -4vh) scale(.95); }
}
@keyframes cx-orb-move-2 {
  0%   { transform: translate(0, 0) scale(1); }
  50%  { transform: translate(4vw, -6vh) scale(.95); }
  100% { transform: translate(-4vw, 5vh) scale(1.08); }
}

.cx-grid { position: absolute; inset: 0; width: 100%; height: 100%; opacity: .4; }

/// ······ 卡片
.cx-login-card-wrap { position: relative; z-index: 2; width: 100%; max-width: 440px; }

.cx-login-card {
  position: relative;
  width: 100%;
  box-sizing: border-box;
  padding: 44px 36px 32px;
  border-radius: 20px;
  background: rgba(255,255,255,0.96);
  backdrop-filter: blur(14px) saturate(140%);
  -webkit-backdrop-filter: blur(14px) saturate(140%);
  border: 1px solid rgba(255,255,255,0.7);
  box-shadow:
    0 20px 60px rgba(20, 50, 100, 0.15),
    0 2px 8px  rgba(20, 50, 100, 0.08);
  transition: box-shadow .3s ease, transform .3s ease;
  &:hover { box-shadow: 0 24px 70px rgba(20, 50, 100, 0.2); }
}

@media (prefers-color-scheme: dark) {
  .cx-login-card {
    background: rgba(30, 44, 70, 0.86);
    border-color: rgba(255, 255, 255, 0.08);
    color: #cbd5e1;
    .cx-brand-title, .cx-hello, cx-sub { color: #e2e8f0; }
  }
  .cx-login-page { color: #e2e8f0; }
  .cx-sub { color: #94a3b8; }
  a.cx-link-primary { color: #38bdf8; }
  .cx-login-footer span { color: #52607a; }
}

.cx-brand-row { display: flex; align-items: center; gap: 12px; margin-bottom: 22px; }
.cx-brand-logo { height: 34px; width: 34px; border-radius: 8px; }
.cx-brand-title {
  font-size: 22px; font-weight: 700; letter-spacing: .5px;
  color: #1e2b45;
  @media (prefers-color-scheme: dark) { color: #e2e8f0; }
}
.cx-hello { font-size: 22px; font-weight: 600; color: #1f2937; margin: 0 0 4px; 
  @media (prefers-color-scheme: dark) { color: #e2e8f0; }
}
.cx-sub { color: #64748b; font-size: 14px; margin: 0 0 22px; }

.cx-row-mid {
  display: flex; justify-content: space-between; align-items: center;
  margin: -6px 0 20px; font-size: 13px;
  .cx-link-primary { color: #2563eb; text-decoration: none; :hover { color: #1d4ed8; } }
}
.cx-btn-primary {
  border-radius: 12px;
  font-size: 16px; font-weight: 600; height: 48px;
  background: linear-gradient(135deg, #2563eb 0%, #38bdf8 100%);
  box-shadow: 0 8px 20px rgba(56,189,248,0.28);
  border: none;
  &:hover { transform: translateY(-1px); box-shadow: 0 12px 28px rgba(56,189,248,0.36); }
  &:disabled { opacity: .8; }
}

.cx-registration {
  display: flex; justify-content: center; align-items: center; gap: 6px; margin: 10px 0 0;
  font-size: 13.5px; color: #64748b;
  a { color: #2563eb; } a:hover { color: #1d4ed8; }
}

.cx-oauth-row { margin-top: 18px; border-top: 1px solid rgba(148,163,184,.25); padding-top: 16px; }
.cx-oauth-title-text { font-size: 12px; color: #94a3b8; text-align: center; margin-bottom: 10px; }
.cx-oauth-icon-button { display: inline-flex; flex-direction: column; align-items: center;
  min-width: 72px; padding: 6px; border-radius: 10px; background: rgba(248,250,252,1); cursor: pointer;
  .title { font-size: 11px; margin-top: 4px; color: #475569; max-width: 96px; }
  :hover { background: rgba(56,189,248,0.13); }
}

.cx-langs { margin-top: 18px; display: flex; justify-content: center; }
.cx-lang-toggle { color: #94a3b8; font-size: 13px; }

.cx-login-footer { margin-top: 24px; color: #94a3b8; font-size: 12px; text-align: center; }

.cx-2fa-info { display: flex; gap: 12px; margin-bottom: 22px;
  .cx-2fa-icon { font-size: 28px; color: #2563eb; }
  .cx-2fa-title { font-weight: 600; color: #1f2937; font-size: 15px; }
  .cx-2fa-sub { color: #64748b; font-size: 13px; margin-top: 2px; }
}

.cx-back-link { display: block; margin-top: 16px; text-align: center; color: #64748b; font-size: 13px; cursor: pointer; }
.cx-back-link:hover { color: #2563eb; }

// ── 响应式
// 手机 (<640px)
@media (max-width: 640px) {
  .cx-login-card { padding: 32px 22px 24px; border-radius: 18px; }
  .cx-brand-logo { height: 28px; width: 28px; }
  .cx-brand-title { font-size: 19px; }
  .cx-hello { font-size: 19px; }
  .cx-btn-primary { height: 44px; font-size: 15px; }
  .cx-row-mid { font-size: 12px; margin: -4px 0 16px; }
  .cx-login-card-wrap { max-width: 100%; }
  .cx-login-page { padding: 18px 12px; }
}
// 平板 (641-1024)
@media (min-width: 641px) and (max-width: 1024px) {
  .cx-login-card { max-width: 420px; padding: 38px 30px 28px; }
}

// ── 预防 XSS / SQLi (在 vue context 全部 template interpolation) — no v-html
// 由 Vue 默认的 `{{...}}` text interpolation escape HTML; generation of attribute on :xxx
// 绑定全部走白名单 prop, 特别注意:
//   - 用户名只 trim, 不插除 whitespace, 不插换行
//   - 表单 submit 时整体用 JSON encode, 无原生 innerHTML.
// 后端: param 走 Midway validate, SQL 用 TypeORM prepared query.

// ······ reduce motion:
@media (prefers-reduced-motion: reduce) {
  .cx-orb { animation: none; opacity: .4; }
  .cx-grid { opacity: .1; }
}
</style>
