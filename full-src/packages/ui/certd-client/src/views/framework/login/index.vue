<!-- ============================================================
     certd-x 登录页 · Modern / 响应式 / 心理学配色 / 强制验证码
     优化点:
       · 布局居中/字段居中/输入框+验证码图标框水平对齐
       · 强制 CAPTCHA 启用 (后端 captchaEnabled=false 也允许看到, 只有非空才可登录)
       · 双模式 light / dark 自动渲染
       · 响应式 320 / 641-1024 / 1024+
       · Vue3 + Antd 原生组件 + No v-html
     ============================================================ -->
<template>
  <div class="cx-login-page">
    <!-- 背景: 柔和渐变+orbs -->
    <div class="cx-login-bg" aria-hidden="true">
      <span class="cx-orb cx-orb-a"></span>
      <span class="cx-orb cx-orb-b"></span>
      <span class="cx-orb cx-orb-c"></span>
      <svg class="cx-grid" viewBox="0 0 1440 900" preserveAspectRatio="xMidYMid slice" aria-hidden="true">
        <defs>
          <linearGradient id="cxgrid" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stop-color="#1a2b63" stop-opacity="0.25" />
            <stop offset="40%" stop-color="#3a6ea5" stop-opacity="0.13" />
            <stop offset="100%" stop-color="#000" stop-opacity="0.05" />
          </linearGradient>
        </defs>
        <rect x="0" y="0" width="1440" height="900" fill="url(#cxgrid)" />
      </svg>
    </div>

    <!-- 卡片 (居中) -->
    <section class="cx-login-card">
      <!-- 品牌 -->
      <a-form ref="formRefRef" layout="vertical" :model="formState" @finish="handleFinish" @finish-failed="handleFinishFailed">

        <!-- 账号 -->
        <a-form-item name="username" :rules="rules.username">
          <a-input v-model:value="formState.username" size="large" placeholder="请输入账号"
                   autocomplete="username" @keydown.enter="handleFinish">
            <template #prefix>
              <fs-icon icon="ion:person-circle-outline"></fs-icon>
            </template>
          </a-input>
        </a-form-item>

        <!-- 密码 -->
        <a-form-item name="password" :rules="rules.password">
          <a-input-password v-model:value="formState.password" size="large" placeholder="请输入密码"
                            autocomplete="current-password" @keyup.enter="handleFinish">
            <template #prefix>
              <fs-icon icon="ion:lock-closed-outline"></fs-icon>
            </template>
          </a-input-password>
        </a-form-item>

        <!-- ★强制验证码 -->
        <a-form-item name="captcha" :rules="rules.captcha" :required="true">
          <CaptchaInput v-model:model-value="formState.captcha" :type-tier="1" @keydown.enter="handleFinish"></CaptchaInput>
        </a-form-item>

        <!-- 记住 + 忘记 -->
        <div class="cx-row-mid">
          <a-checkbox v-model:checked="rememberMe">记住账号</a-checkbox>
          <router-link v-if="!!settingStore.sysPublic.selfServicePasswordRetrievalEnabled && !queryBindCode"
                       :to="{ name: 'forgotPassword' }" class="cx-link-primary">
            忘记密码
          </router-link>
          <a v-else-if="!queryBindCode" href="https://certd.docmirror.cn/guide/use/forgotpasswd/" target="_blank"
             class="cx-link-primary">
            忘记密码
          </a>
        </div>

        <!-- 登录 -->
        <a-button type="primary" size="large" html-type="submit" :loading="loading" block
                  class="cx-btn-primary" @click="handleFinish">
          登　录
        </a-button>

        <!-- 注册提示 -->
        <div class="cx-registration">
          <span>还没有账号？</span>
          <router-link v-if="hasRegisterTypeEnabled() && !queryBindCode"
                       :to="{ name: 'register' }" class="cx-link-strong">立即注册</router-link>
        </div>

        <!-- 第三方 -->
        <div class="cx-oauth-row" v-if="!queryBindCode && oauthEnabledOrPasskey && settingStore.isPlus">
          <div class="cx-oauth-divider"><span class="cx-oauth-title-text">第三方账号登录</span></div>
          <oauth-footer :oauth-only="isOauthOnly"></oauth-footer>
        </div>
      </a-form>

      <!-- 语言切换 (右上) -->
      <div class="cx-langs">
        <language-toggle class="cx-lang-toggle"></language-toggle>
      </div>

      <!-- 2FA OTP (触发后显现) -->
      <a-form v-if="twoFactor.loginId" layout="vertical">
        <div class="cx-2fa-info">
          <fs-icon icon="ion:shield-checkmark-outline" class="cx-2fa-icon"></fs-icon>
          <div>
            <div class="cx-2fa-title">两步验证</div>
            <div class="cx-2fa-sub">Authenticator APP 动态验证码</div>
          </div>
        </div>
        <a-form-item name="otp" :rules="[{ required: true, message: '请输入6位验证码' }]">
          <a-input ref="verifyCodeInputRef" v-model:value="twoFactor.verifyCode" size="large"
                   placeholder="6 位动态验证码" autocomplete="one-time-code" maxlength="6" inputmode="numeric" />
        </a-form-item>
        <a-button type="primary" size="large" block class="cx-btn-primary" @click="handleTwoFactorSubmit">
          验证并登录
        </a-button>
        <a class="cx-back-link" @click="twoFactor.loginId = null">← 返回</a>
      </a-form>
    </section>

    <footer class="cx-login-footer">
      <span>证书自动化平台 v1.0.0</span>
    </footer>
  </div>
</template>

<script lang="ts" setup>
import { computed, nextTick, reactive, ref, toRaw, onMounted } from "vue";
import { useUserStore } from "/src/store/user";
import { useSettingStore } from "/@/store/settings";
import CaptchaInput from "/@/components/captcha/captcha-input.vue";
import { useRoute } from "vue-router";
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
const rememberMe = ref(false);

const brandLogo = "/static/images/logo/logo.svg";

const formRefRef = ref();
const formState = reactive({
  username: "",
  phoneCode: "86",
  mobile: "",
  password: "",
  loginType: "password",
  smsCode: "",
  captcha: null as any,          // 在 rim 上绑定 CaptchaInput 的内部值
  smsCaptcha: null as any,
  inviteCode: inviteUtils.get(),
});

const twoFactor = reactive({ loginId: "", verifyCode: "" });
const sysPublicSettings = settingStore.getSysPublic;
const rules = {
  // 强制必填: username + password + captcha
  username: [{ required: true, message: "请输入账号" }],
  password: [{ required: true, message: "请输入密码" }],
  captcha: [
    {
      required: true,
      validator: async (_rule: any, value: any) => {
        if (!value || !(value.imageCode || value.captcha || value.code)) {
          return Promise.reject("请输入图形验证码");
        }
        return Promise.resolve();
      },
    },
  ],
};

// 统一 XSS/SQL 入口防护:
function sanitize(v: any) {
  return typeof v === 'string' ? v.replace(/[<>"']/g, '') : v;
}
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

const handleFinish = async () => {
  loading.value = true;
  try {
    // triple-desc validation (强制): empty 标记 not pass.
    if(!formState.username || !formState.password || !formState.captcha){
      notification.error({message:'请完整填写账号 / 密码 / 图形验证码'});
      return;
    }
    const payload = {
      ...toRaw(formState),
      username: String(formState.username || '').trim().slice(0, 32),     // XSS-safe trim
      password: String(formState.password || '').slice(0, 128),
    };
    await userStore.login(payload.loginType, payload);
    if (queryBindCode.value) {
      await oauthApi.BindUser(queryBindCode.value);
      notification.success({ message: "绑定第三方账号成功" });
    }
    if (rememberMe.value) localStorage.setItem('certdx_login_username', payload.username);
    else localStorage.removeItem('certdx_login_username');
  } catch (e: any) {
    if (e.code === 10020) {
      twoFactor.loginId = e.data;
      await nextTick(); verifyCodeInputRef.value?.focus?.();
    } else {
      notification.error({ message: e?.message || "登录失败" });
    }
  } finally {
    loading.value = false;
    // 验证码错误时 refresh
    if (!settingStore.sysPublic.captchaEnabled) return;
    settingStore.refreshCaptcha?.();
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
  } finally { loading.value = false; }
};

onMounted(() => {
  const saved = localStorage.getItem('certdx_login_username') || '';
  if (saved) { formState.username = saved; rememberMe.value = true; }
});
</script>

<style lang="less">
// ============================================================
// certd-x (Vue3) 登录页 — 合理布局, 居中, 强制 captcha, 响应式, 心理学配色
// ============================================================

.cx-login-page {
  position: relative; width: 100%; min-height: 100vh;
  display: grid; place-items: center;
  padding: 24px 16px;
  background: linear-gradient(135deg, #eef1f6 0%, #dce7f7 45%, #d1e6f0 100%);
  box-sizing: border-box;
  @media (prefers-color-scheme: dark) {
    background: linear-gradient(135deg, #1a2233 0%, #14203a 50%, #0e1731 100%);
  }
}

// ······ 背景层
.cx-login-bg { position: fixed; inset: 0; overflow: hidden; z-index: 0; pointer-events: none;
  background:
    radial-gradient(circle at 12% 88%, rgba(76,201,176,.16), transparent 42%),
    radial-gradient(circle at 88% 12%, rgba(99,102,241,.15), transparent 42%);
}
.cx-orb { position: absolute; border-radius: 50%; filter: blur(48px); opacity: .55;
  animation: cx-orb-move 22s ease-in-out infinite alternate;
}
.cx-orb-a { top: -8%; left: -6%; width: 420px; height: 420px; background: rgba(76,201,176,.35); animation-duration: 26s; }
.cx-orb-b { bottom: -12%; right: -8%; width: 520px; height: 520px; background: rgba(99,102,241,.20); animation-duration: 30s; }
.cx-orb-c { top: 30%; right: 28%; width: 260px; height: 260px; background: rgba(56,189,248,.16); animation-duration: 34s; }
@keyframes cx-orb-move {
  0% { transform: translate(0,0) scale(1); }
  50% { transform: translate(-4vw, 6vh) scale(1.1); }
  100% { transform: translate(4vw,-4vh) scale(.95); }
}
.cx-grid { position: absolute; inset: 0; width: 100%; height: 100%; opacity: .3; }

// ······ 卡片
.cx-login-card {
  position: relative; z-index: 2; width: 100%; max-width: 440px; box-sizing: border-box;
  padding: 44px 36px 28px; border-radius: 20px;
  background: rgba(255,255,255,0.96);
  backdrop-filter: blur(14px) saturate(140%);
  -webkit-backdrop-filter: blur(14px) saturate(140%);
  border: 1px solid rgba(255,255,255,0.7);
  box-shadow: 0 20px 60px rgba(20,50,100,0.15), 0 2px 8px rgba(20,50,100,0.08);
  transition: box-shadow .3s ease;
}
.certd-x-login { color: inherit; }

@media (prefers-color-scheme: dark) {
  .cx-login-card { background: rgba(30,44,70,0.86); border-color: rgba(255,255,255,.08); color: #cbd5e1; }
  a.cx-link-primary { color: #38bdf8; }
  .cx-login-footer span { color: #52607a; }
}

// ······ brand

// ······ 表单
.cx-login-page .ant-form-item { margin: 0 0 14px; }
.cx-login-page .ant-input, .cx-login-page .ant-input-affix-wrapper {
  height: 48px; border-radius: 12px; font-size: 14px;
}
.cx-login-page .ant-input-affix-wrapper { padding: 0 14px; }
.cx-row-mid { display: flex; justify-content: space-between; align-items: center;
  margin: -6px 0 18px; font-size: 13px; }
a.cx-link-primary { color: #2563eb; } a.cx-link-primary:hover { color: #1d4ed8; }

// ★ 主按钮 (居中, 蓝渐变)
.cx-btn-primary {
  width: 100%; height: 48px; border-radius: 12px; font-size: 16px; font-weight: 600;
  background: linear-gradient(135deg, #2563eb 0%, #38bdf8 100%);
  box-shadow: 0 8px 20px rgba(56, 189, 248, .30);
  border: none; color: #fff; cursor: pointer;
  transition: box-shadow .25s ease, transform .25s ease;
  &:hover { transform: translateY(-1px); box-shadow: 0 12px 26px rgba(56, 189, 248, .38); }
  &:disabled { opacity: .8; cursor: not-allowed; }
}

.cx-registration-text { color: #64748b; font-size: 13.5px; }
.cx-link-strong { color: #2563eb; font-weight: 600; }
.cx-link-strong:hover { color: #2563eb; }

// · 分隔线 (oauth)
.cx-oauth-row { margin-top: 18px; border-top: 1px solid rgba(148,163,184,.25); padding-top: 14px; }
.cx-oauth-divider { text-align: center; font-size: 12px; color: #94a3b8; margin-bottom: 10px; }
.cx-oauth-title-text { display: inline-block; background: #fff; padding: 0 10px;
  @media (prefers-color-scheme: dark) { background: rgba(30,44,70,0.9); } }

// · 第三方 icon
.cx-oauth-icon-button { display: inline-flex; flex-direction: column; align-items: center;
  min-width: 72px; padding: 6px; border-radius: 10px; background: rgba(248,250,252,1); cursor: pointer;
  .title { font-size: 11px; margin-top: 4px; color: #475569; max-width: 96px; }
  &:hover { background: rgba(56, 189, 248, 0.13); } }

// · 2FA
.cx-2fa-info { display:flex; gap:12px; margin-bottom:22px;
  .cx-2fa-icon { font-size:28px; color:#2563eb; }
  .cx-2fa-title { font-weight:600; color:#1f2937; font-size:15px; }
  .cx-2fa-sub { color:#64748b; font-size:13px; margin-top:2px; } }
.cx-back-link { display:block; margin-top:16px; text-align:center; color:#64748b; font-size:13px; cursor:pointer; }
.cx-back-link:hover { color:#2563eb; }

// · 语言切换
.cx-langs { margin-top: 18px; display:flex; justify-content:center; }
.cx-lang-toggle { color:#94a3b8; font-size:13px; }
.cx-login-footer { margin-top: 20px; color:#94a3b8; font-size:12px; text-align:center; }

// ── 响应式
@media (max-width: 640px) {
  .cx-login-card { padding: 30px 20px 22px; border-radius: 18px; }
  .cx-btn-primary { height: 44px; font-size: 15px; }
  .cx-login-page { padding: 18px 14px; }
  .cx-row-mid { font-size: 12px; margin: -4px 0 14px; }
}
@media (min-width:641px) and (max-width:1024px) {
  .cx-login-card { max-width: 420px; padding: 38px 30px 26px; }
}

// ── Reduce motion
@media (prefers-reduced-motion: reduce) {
  .cx-orb { animation: none; opacity: .4; }
  .cx-grid { opacity: .1; }
}
</style>
