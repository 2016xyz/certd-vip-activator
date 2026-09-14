<!-- certd-x 登录页 · wow 风格 (仿统一协同平台) -->
<template>
  <main class="wow-login-page certd-x-login">
    <div class="wow-login-background" aria-hidden="true"></div>
    <div class="wow-login-content">
      <header class="wow-login-header">
        <div class="wow-login-logo" aria-hidden="true">
          <svg viewBox="0 0 64 64" width="56" height="56" xmlns="http://www.w3.org/2000/svg">
            <defs>
              <linearGradient id="cx" x1="0" y1="0" x2="1" y2="1">
                <stop offset="0%" stop-color="#4cc9b0"/><stop offset="100%" stop-color="#3b82f6"/>
              </defs>
            </defs>
            <circle cx="32" cy="32" r="30" fill="url(#cx)"/>
            <path d="M22 24 L44 40 M44 24 L22 40" stroke="#fff" stroke-width="4.5" stroke-linecap="round" fill="none"/>
            <circle cx="32" cy="32" r="11" fill="none" stroke="#fff" stroke-width="3"/>
          </svg>
        </div>
        <div class="wow-login-title">certd-x</div>
        <div class="wow-login-subtitle">Certificate Automation Platform</div>
      </header>
      <section class="wow-login-card">
        <div class="wow-language-switch i18n">
          <LanguageToggle class="lang-toggle"></LanguageToggle>
        </div>
        <form class="wow-login-form" onsubmit="return false;" v-if="!twoFactor.loginId">
          <div class="wow-input-group form-group">
            <span class="wow-input-icon user-icon" aria-hidden="true"><i class="fas fa-user"></i></span>
            <a-input v-model:value="formState.username" name="username" placeholder="请输入账号" autocomplete="username" @keydown.enter="handleFinish"/>
          </div>
          <div class="wow-input-group form-group">
            <span class="wow-input-icon password-icon" aria-hidden="true"><i class="fas fa-lock"></i></span>
            <a-input-password v-model:value="formState.password" name="password" placeholder="请输入密码" autocomplete="current-password" @keyup.enter="handleFinish"/>
          </div>
          <div class="wow-verification form-group" v-if="settingStore.sysPublic.captchaEnabled">
            <CaptchaInput v-model:model-value="formState.captcha" @keydown.enter="handleFinish"></CaptchaInput>
          </div>
          <label class="wow-remember">
            <input type="checkbox" name="remember" v-model="rememberMe"> <span>记住账号</span>
          </label>
          <button id="loginBtn" class="btn btn-primary wow-btn-login" :disabled="loading" type="submit" @click="handleFinish">
            <span class="btn-label" v-if="!loading">登 录</span>
            <span class="btn-spinner" v-else><i class="fas fa-circle-notch fa-spin"></i> 登录中...</span>
          </button>
          <div class="wow-links">
            <div class="flex justify-between items-center">
              <div class="flex items-center gap-3">
                <LanguageToggle></LanguageToggle>
                <router-link v-if="!!settingStore.sysPublic.selfServicePasswordRetrievalEnabled && !queryBindCode"
                             :to="{ name: 'forgotPassword' }" class="wow-link">
                  {{ t('authentication.forgotPassword') }}
                </router-link>
                <a v-else-if="!queryBindCode" href="https://certd.docmirror.cn/guide/use/forgotpasswd/" target="_blank" class="wow-link">
                  {{ t('authentication.forgotPassword') }}
                </a>
              </div>
              <router-link v-if="hasRegisterTypeEnabled() && !queryBindCode" class="wow-link wow-link-strong"
                           :to="{ name: 'register' }">
                {{ t('authentication.registerLink') }}
              </router-link>
            </div>
          </div>
        </form>
        <!-- 第三方绑定 / Passkey / OAuth 登录入口 (恢复) -->
        <div v-if="!queryBindCode && (settingStore.sysPublic.oauthEnabled || settingStore.sysPublic.passkeyEnabled) && settingStore.isPlus"
             class="wow-oauth-footer">
          <oauth-footer :oauth-only="isOauthOnly"></oauth-footer>
        </div>

        <!-- 2FA -->
        <form class="wow-login-form" onsubmit="return false;" v-else>
          <div class="mb-6 text-sm">请打开您的 Authenticator APP，获取动态验证码</div>
          <div class="wow-input-group form-group">
            <span class="wow-input-icon password-icon" aria-hidden="true"><i class="fas fa-shield-alt"></i></span>
            <a-input ref="verifyCodeInputRef" v-model:value="twoFactor.verifyCode" name="verifyCode" placeholder="请输入动态验证码" @keydown.enter="handleTwoFactorSubmit"/>
          </div>
          <button class="btn btn-primary wow-btn-login" :disabled="loading" type="submit" @click="handleTwoFactorSubmit">
            <span class="btn-label" v-if="!loading">OTP 验证登录</span>
            <span class="btn-spinner" v-else><i class="fas fa-circle-notch fa-spin"></i></span>
          </button>
          <a class="wow-link-back" @click="twoFactor.loginId = null">← 返回</a>
        </form>
      </section>
    </div>
  </main>
</template>
<script lang="ts" setup>
import { computed, nextTick, reactive, ref, toRaw } from "vue";
import { useUserStore } from "/src/store/user";
import { useSettingStore } from "/@/store/settings";
import { utils } from "@fast-crud/fast-crud";
import CaptchaInput from "/@/components/captcha/captcha-input.vue";
import { useRoute } from "vue-router";
import { useI18n } from "/@/locales";
import OauthFooter from "/@/views/framework/oauth/oauth-footer.vue";
import * as oauthApi from "../oauth/api";
import { request } from "/src/api/service";
import { inviteUtils } from "/@/utils/util.invite";
import { LanguageToggle } from "/@/vben/layouts";
import { notification } from "ant-design-vue";

const route = useRoute();
const userStore = useUserStore();
const queryBindCode = ref(route.query.bindCode as string | undefined);
const queryOauthOnly = route.query.oauthOnly as string;
const urlLoginType = route.query.loginType as string | undefined;
const verifyCodeInputRef = ref();
const loading = ref(false);
const rememberMe = ref(false);

const settingStore = useSettingStore();
const formRef = ref();
const { t } = useI18n();
let defaultLoginType = settingStore.sysPublic.defaultLoginType || "password";
if (defaultLoginType === "sms") {
  if (!settingStore.sysPublic.smsLoginEnabled || !settingStore.isComm) {
    defaultLoginType = "password";
  }
}
const formState = reactive({
  username: "",
  phoneCode: "86",
  mobile: "",
  password: "",
  loginType: urlLoginType || defaultLoginType,
  smsCode: "",
  captcha: null,
  smsCaptcha: null,
  inviteCode: inviteUtils.get(),
});

const sysPublicSettings = settingStore.getSysPublic;
const twoFactor = reactive({
  loginId: "",
  verifyCode: "",
});

const handleFinish = async () => {
  loading.value = true;
  try {
    const loginType = formState.loginType;
    await userStore.login(loginType, toRaw(formState));
    if (queryBindCode.value) {
      await oauthApi.BindUser(queryBindCode.value);
      notification.success({ message: "绑定第三方账号成功" });
    }
  } catch (e: any) {
    if (e.code === 10020) {
      twoFactor.loginId = e.data;
      await nextTick();
      verifyCodeInputRef.value.focus();
    } else {
      throw e;
    }
  } finally {
    loading.value = false;
    formState.captcha = null;
  }
};

const handleTwoFactorSubmit = async () => {
  await userStore.loginByTwoFactor(twoFactor);
  if (queryBindCode.value) {
    await oauthApi.BindUser(queryBindCode.value);
    notification.success({ message: "绑定第三方账号成功" });
  }
};

const hasRegisterTypeEnabled = () => {
  const sys = settingStore.sysPublic;
  return sys.registerEnabled && (sys.usernameRegisterEnabled || sys.emailRegisterEnabled || sys.mobileRegisterEnabled || sys.smsLoginEnabled);
};

const isOauthOnly = computed(() => {
  if (queryOauthOnly === "false" || queryOauthOnly === "0") {
    return false;
  }
  return sysPublicSettings.oauthOnly && settingStore.isPlus && sysPublicSettings.oauthEnabled;
});
</script>

<style lang="less">
// wow-login 主题样式 (自适应 certd-x 配色)
@wow-primary: #466ab2;
@wow-accent: #4cc9b0;

.certd-x-login.wow-login-page {
  min-height: 100vh;
  overflow: hidden;
  color: #191e2d;
  position: relative;
  .wow-login-background {
    position: absolute;
    inset: 0;
    background: radial-gradient(circle at 18% 18%, rgba(255,255,255,.26), transparent 30%),
                radial-gradient(circle at 86% 86%, rgba(76,201,176,.22), transparent 32%),
                linear-gradient(135deg,#0f3a66 0%,#25528c 32%,#3873c1 58%,#63a3d9 80%,#8fd0f0 100%);
    background-position: center;
    background-size: 180% 180%;
    animation: cx-bg-shift 20s ease-in-out infinite alternate;
  }
  .wow-login-background::before,
  .wow-login-background::after {
    position: absolute; border-radius: 50%; content: ""; filter: blur(2px);
  }
  .wow-login-background::before { top: 10%; left: 7%; width: 22vw; height: 22vw; background: rgba(255,255,255,.14); }
  .wow-login-background::after { bottom: 8%; right: 10%; width: 18vw; height: 18vw; background: rgba(255,255,255,.1); }
  .wow-login-content {
    position: relative;
    min-height: 100vh;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    padding: 24px;
    z-index: 1;
  }
  .wow-login-header { text-align: center; margin-bottom: 22px; color: #fff; }
  .wow-login-logo { display: inline-flex; margin-bottom: 10px; }
  .wow-login-title { font-size: 34px; font-weight: 700; letter-spacing: 2px; }
  .wow-login-subtitle { font-size: 13px; opacity: .85; letter-spacing: 2px; margin-top: 4px; }
  .wow-login-card {
    position: relative;
    width: 100%;
    max-width: 420px;
    background: #fff;
    border-radius: 20px;
    box-shadow: 0 20px 46px rgba(16,36,74,.22);
    padding: 34px 30px 26px;
  }
  .wow-language-switch { display: flex; justify-content: flex-end; margin-bottom: 8px; }
  .wow-login-form { .form-group { margin-bottom: 16px; } }
  .wow-input-group { position: relative; display: flex; align-items: center; }
  .wow-input-icon { position: absolute; left: 12px; color: #98a2b3; z-index: 1; }
  .wow-input-group .ant-input, .wow-input-group .ant-input-password {
    border-radius: 10px;
    padding-left: 38px !important;
    height: 44px;
  }
  .we-login-form .wow-verification { display: flex; gap: 10px; }
  .we-login-form .captcha { flex: 1; }
  .wow-remember {
    display: inline-flex; align-items: center; gap: 6px; font-size: 13px;
    margin: 10px 0 14px; color: #4b5563;
  }
  .wow-btn-login {
    width: 100%; height: 44px; border-radius: 10px; font-size: 16px;
    background: linear-gradient(135deg,@wow-primary,@wow-accent);
    border: none; color: #fff; cursor: pointer; transition: opacity .2s;
    &:hover { opacity: .9; }
    &:disabled { opacity: .7; }
  }
  .wow-link-back { display: block; text-align: center; margin-top: 14px; color: #4b5563; font-size: 13px; cursor: pointer; }
  .wow-links { margin-top: 10px; font-size: 13px; }
  .wow-link { color: #4b5563; text-decoration: none; &:hover { color: @wow-primary; } }
  .wow-link-strong { color: #111; font-weight: 600; &:hover { color: @wow-primary; } }
  .wow-oauth-footer { margin-top: 14px; border-top: 1px solid #eef1f4; padding-top: 12px;
    :deep(.oauth-title-text) { font-size: 12px; color: #94a3b8; text-align: center; margin-bottom: 8px; }
    :deep(.oauth-icon-button) { display: inline-flex; flex-direction: column; align-items: center;
      min-width: 72px; padding: 6px; border-radius: 10px; background: #f8fafc;
      .title { font-size: 11px; margin-top: 4px; color: #475569; max-width: 96px; }
      &:hover { background: #eef6fb; } }
  }
}

@keyframes cx-bg-shift {
  0% { background-position: 0% 0%; }
  100% { background-position: 100% 100%; }
}
</style>
