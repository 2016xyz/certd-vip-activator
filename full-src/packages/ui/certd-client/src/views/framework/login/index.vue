<!-- certd-x 登录页 · 与统一协同平台(1000.2016xlx.cn:3011) 1:1 还原 -->
<template>
    <main class="wow-login-page">
      <div class="wow-login-background" aria-hidden="true"></div>
      <div class="wow-login-content">
        <header class="wow-login-header">
          <div class="wow-login-title">certd-x</div>
          <div class="wow-login-subtitle">Certificate Automation Platform</div>
        </header>
        <section class="wow-login-card">
          <div class="wow-language-switch i18n">
            <button id="languagemenu" type="button" aria-label="Language" @click="cycleLang">{{ langLabel }}</button>
          </div>
          <form class="wow-login-form" onsubmit="return false;" v-if="!twoFactor.loginId">
            <div class="wow-input-group form-group">
              <span class="wow-input-icon user-icon" aria-hidden="true"><i class="fas fa-user"></i></span>
              <input class="form-control" name="username" v-model="formState.username"
                     placeholder="请输入账号" autocomplete="username" required type="text" />
            </div>
            <div class="wow-input-group form-group">
              <span class="wow-input-icon password-icon" aria-hidden="true"><i class="fas fa-lock"></i></span>
              <input class="form-control login-pwd" name="password" v-model="formState.password"
                     :type="showPwd ? 'text' : 'password'" placeholder="请输入密码" autocomplete="current-password" required />
              <button type="button" class="pwd-toggle" aria-label="toggle password" @click="showPwd = !showPwd">
                <i :class="showPwd ? 'fas fa-eye-slash' : 'fas fa-eye'"></i>
              </button>
            </div>
            <div class="wow-verification form-group" v-if="settingStore.sysPublic.captchaEnabled">
              <CaptchaInput v-model:model-value="formState.captcha" @keydown.enter="handleFinish"></CaptchaInput>
            </div>
            <label class="wow-remember">
              <input type="checkbox" name="remember" v-model="rememberMe" />
              <span>记住账号</span>
            </label>
            <button id="loginBtn" class="btn btn-primary btn-login block full-width"
                    :disabled="loading" type="submit" @click="handleFinish">
              <span class="btn-label">登　录</span>
              <span class="btn-spinner" aria-hidden="true" v-if="loading"><i class="fas fa-circle-notch fa-spin"></i></span>
            </button>
            <div class="login-alt wow-login-alt-links">
              <router-link v-if="!!settingStore.sysPublic.selfServicePasswordRetrievalEnabled && !queryBindCode"
                           :to="{ name: 'forgotPassword' }">
                {{ t("authentication.forgotPassword") }}
              </router-link>
              <a v-else-if="!queryBindCode" href="https://certd.docmirror.cn/guide/use/forgotpasswd/" target="_blank">
                {{ t("authentication.forgotPassword") }}
              </a>
              <router-link v-if="hasRegisterTypeEnabled() && !queryBindCode"
                           :to="{ name: 'register' }" class="wow-link-strong">
                {{ t("authentication.registerLink") }}
              </router-link>
            </div>
          </form>

          <!-- 第三方绑定 / Passkey / OAuth (恢复) -->
          <div v-if="!queryBindCode && (settingStore.sysPublic.oauthEnabled || settingStore.sysPublic.passkeyEnabled) && settingStore.isPlus"
               class="wow-oauth-footer">
            <oauth-footer :oauth-only="isOauthOnly"></oauth-footer>
          </div>

          <!-- 2FA -->
          <form class="wow-login-form" onsubmit="return false;" v-else>
            <div class="mb-6 text-sm">请打开您的 Authenticator APP，获取动态验证码</div>
            <div class="wow-input-group form-group">
              <span class="wow-input-icon password-icon" aria-hidden="true"><i class="fas fa-shield-alt"></i></span>
              <input class="form-control" name="verifyCode" v-model="twoFactor.verifyCode"
                     placeholder="动态验证码" autocomplete="one-time-code" required />
            </div>
            <button id="loginBtn2" class="btn btn-primary btn-login block full-width"
                    :disabled="loading" type="submit" @click="handleTwoFactorSubmit">
              <span class="btn-label">OTP 验证登录</span>
            </button>
            <a class="wow-link-back" @click="twoFactor.loginId = null">← 返回</a>
          </form>
        </section>
      </div>
    </main>
</template>
<script lang="ts" setup>
import { computed, nextTick, reactive, ref, toRaw, onMounted } from "vue";
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
import { notification } from "ant-design-vue";
import { useUserStore as _US } from "/src/store/user"; // noop

const route = useRoute();
const userStore = useUserStore();
const queryBindCode = ref(route.query.bindCode as string | undefined);
const verifyCodeInputRef = ref();
const loading = ref(false);
const rememberMe = ref(false);
const showPwd = ref(false);

const settingStore = useSettingStore();
const formRef = ref();
let defaultLoginType = "password";
const formState = reactive({
  username: "",
  phoneCode: "86",
  mobile: "",
  password: "",
  loginType: defaultLoginType,
  smsCode: "",
  captcha: null as any,
  smsCaptcha: null as any,
  inviteCode: inviteUtils.get(),
});

const sysPublicSettings = settingStore.getSysPublic;
const { t } = useI18n();
const queryOauthOnly = route.query.oauthOnly as string;

const hasRegisterTypeEnabled = () => {
  const sys = settingStore.sysPublic;
  return sys.registerEnabled && (sys.usernameRegisterEnabled || sys.emailRegisterEnabled || sys.mobileRegisterEnabled || sys.smsLoginEnabled);
};

const isOauthOnly = computed(() => {
  if (queryOauthOnly === "false" || queryOauthOnly === "0") return false;
  return sysPublicSettings.oauthOnly && settingStore.isPlus && sysPublicSettings.oauthEnabled;
});

const twoFactor = reactive({
  loginId: "",
  verifyCode: "",
});

function cycleLang() {
  // 简单循环 zh/en 由全局 LanguageToggle 处理 — 这里直接调用
  const cur = (window as any).__CERTDX_LANG__ || "zh-CN";
  const next = cur === "zh-CN" ? "en-US" : "zh-CN";
  (window as any).__CERTDX_LANG__ = next;
  // 触发全局 LanguageToggle = 调用 internal API
  location.reload();
}
const langLabel = computed(() => ((window as any).__CERTDX_LANG__ === "en-US" ? "English" : "中文"));

const handleFinish = async () => {
  loading.value = true;
  try {
    await userStore.login("password", toRaw(formState));
    if (queryBindCode.value) {
      await oauthApi.BindUser(queryBindCode.value);
      notification.success({ message: "绑定第三方账号成功" });
    }
  } catch (e: any) {
    if (e.code === 10020) {
      twoFactor.loginId = e.data;
      await nextTick();
      verifyCodeInputRef.value && verifyCodeInputRef.value.focus();
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

onMounted(() => {
  // 记住账号
  const saved = localStorage.getItem("nps_login_username") || "";
  if (saved) { formState.username = saved; rememberMe.value = true; }
});
</script>

<style lang="less">
// ======================================================
// 1:1 还原 1000.2016xlx.cn:3011/login/index (统一协同平台)
// 主要 class 都从原 style.css 反编译而来
// ======================================================
.certd-x-login.wow-login-page {
  position: relative;
  min-height: 100vh;
  overflow: hidden;
  color: #191e2d;
}

.certd-x-login .wow-login-background {
  position: absolute;
  inset: 0;
  background:
    radial-gradient(circle at 18% 18%, rgba(255, 255, 255, 0.26), transparent 30%),
    radial-gradient(circle at 86% 86%, rgba(52, 197, 180, 0.2), transparent 32%),
    linear-gradient(135deg, #1b3468 0%, #2d529a 32%, #466ab2 58%, #6f9bd1 80%, #93bde4 100%);
  background-position: center;
  background-size: 180% 180%;
  transform: scale(1.02);
  animation: cx-bg-shift 20s ease-in-out infinite alternate;
}

.certd-x-login .wow-login-background:before,
.certd-x-login .wow-login-background:after {
  position: absolute;
  border-radius: 50%;
  content: "";
  filter: blur(2px);
}

.certd-x-login .wow-login-background:before {
  top: 10%; left: 7%;
  width: 22vw; height: 22vw;
  min-width: 180px; min-height: 180px;
  background: radial-gradient(circle at 35% 35%, rgba(255,255,255,.14), rgba(255,255,255,.05) 60%, transparent 72%);
  animation: cx-float-a 16s ease-in-out infinite;
}

.certd-x-login .wow-login-background:after {
  right: 7%; bottom: 9%;
  width: 28vw; height: 28vw;
  min-width: 220px; min-height: 220px;
  background: radial-gradient(circle at 40% 40%, rgba(46,214,190,.16), rgba(46,214,190,.06) 58%, transparent 72%);
  animation: cx-float-b 19s ease-in-out infinite;
}

@keyframes cx-bg-shift {
  0%   { background-position: 0% 0%; }
  100% { background-position: 100% 100%; }
}
@keyframes cx-float-a {
  0%, 100% { transform: translate(0,0) scale(1); }
  50%      { transform: translate(3vw, 5vh) scale(1.08); }
}
@keyframes cx-float-b {
  0%, 100% { transform: translate(0,0) scale(1); }
  50%      { transform: translate(-3vw,-4vh) scale(1.06); }
}
@keyframes cx-rise {
  from { opacity: 0; transform: translateY(22px); }
  to   { opacity: 1; transform: translateY(0); }
}

.certd-x-login .wow-login-content {
  position: relative;
  z-index: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  min-height: 100vh;
  padding: 42px 20px 88px;
  box-sizing: border-box;
}

.certd-x-login .wow-login-header {
  position: relative;
  margin-bottom: 2px;
  color: #fff;
  text-align: center;
  text-shadow: rgba(0,0,0,.2) 0 0 6px;
}

.certd-x-login .wow-login-title {
  margin: 0 0 10px;
  color: #fff;
  font-size: clamp(26px, 3vw, 38px);
  font-weight: 600;
  line-height: 1.2;
  letter-spacing: 12px;
  text-indent: 12px;
}

.certd-x-login .wow-login-subtitle {
  margin: 0 0 28px;
  color: rgba(255,255,255,.72);
  font-size: clamp(11px, 1.1vw, 13px);
  font-weight: 400;
  letter-spacing: 4px;
  text-indent: 4px;
  text-transform: uppercase;
}

.certd-x-login .wow-login-card {
  position: relative;
  overflow: hidden;
  width: 400px;
  box-sizing: border-box;
  padding: 40px 35px 20px;
  border: 1px solid rgba(255,255,255,.52);
  border-radius: 14px;
  background: rgba(255,255,255,.97);
  box-shadow: 0 24px 60px rgba(19,43,96,.28), 0 4px 12px rgba(19,43,96,.12);
  animation: cx-rise .7s cubic-bezier(.22,.61,.36,1) both;
}

.certd-x-login .wow-login-card:before {
  position: absolute;
  top: 0; right: 0; left: 0;
  height: 3px;
  background: linear-gradient(90deg, #3d53f5, #6f9bd1 45%, #2ec6b4);
  content: "";
}

.certd-x-login .wow-login-form .form-group { margin-bottom: 20px; }

.certd-x-login .wow-login-form .wow-input-group {
  position: relative;
  display: flex;
  height: 50px;
  border: 1px solid #dcdfe6;
  border-radius: 4px;
  background: #fff;
  transition: border-color .2s ease;
}

.certd-x-login .wow-input-group:focus-within {
  border-color: #3d53f5;
  box-shadow: 0 0 0 3px rgba(61,83,245,.12);
}

.certd-x-login .wow-input-group:focus-within .wow-input-icon { color: #3d53f5; }

.certd-x-login .wow-input-icon {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 48px;
  flex: 0 0 48px;
  color: #b8bec5;
  font-size: 16px;
}

.certd-x-login .wow-input-group .form-control {
  flex: 1;
  height: 50px;
  padding: 0 12px;
  border: 0;
  outline: 0;
  font-size: 14px;
  color: #191e2d;
  background: transparent;
  border-radius: 4px;
  box-shadow: none;
}

.certd-x-login .wow-input-group .form-control::placeholder { color: #9aa1a9; }

// 密码右眼睛:
.certd-x-login .wow-input-group .pwd-toggle {
  position: absolute;
  top: 50%;
  right: .6rem;
  transform: translateY(-50%);
  height: 2.1rem;
  width: 2.1rem;
  padding: 0;
  border: none;
  background: transparent;
  color: #94a3b8;
  border-radius: .45rem;
  line-height: 1;
  cursor: pointer;
}
.certd-x-login .wow-input-group .pwd-toggle:hover { color: #3d53f5; }

.certd-x-login .wow-verification { display: flex; align-items: center; gap: 0; }

.certd-x-login .wow-captcha-input {
  min-width: 0;
  flex: 1;
  height: 40px;
  padding: 0 12px;
  border: 0;
  outline: 0;
  color: #191e2d;
  background: transparent;
  font-size: 13px;
}
.certd-x-login .wow-captcha-input::placeholder { color: #74777a; }
.certd-x-login .wow-verification .captcha-container { display: flex; align-items: center; height: 40px; margin-left: 10px; }
.certd-x-login .wow-verification .captcha-img { display: block; height: 36px; border-radius: 3px; cursor: pointer; }

.certd-x-login .wow-remember {
  display: flex;
  align-items: center;
  margin: 0 0 16px;
  color: #515560;
  font-size: 13px;
  cursor: pointer;
  user-select: none;
}

.certd-x-login .wow-login-card .btn-login {
  height: auto;
  min-height: 48px;
  margin: 2px 0 18px;
  padding: 13px 0;
  border: 1px solid #3d53f5;
  border-radius: 4px;
  color: #fff;
  background: linear-gradient(135deg, #3d53f5 0%, #4f6df5 60%, #5a7cf7 100%);
  box-shadow: 0 6px 16px rgba(61, 83, 245, 0.28);
  font-size: 16px;
  font-weight: 400;
  letter-spacing: 2px;
  width: 100%;
  cursor: pointer;
  transition: box-shadow .25s ease, transform .25s ease, background .25s ease;
}
.certd-x-login .wow-login-card .btn-login:hover,
.certd-x-login .wow-login-card .btn-login:focus {
  color: #fff;
  background: linear-gradient(135deg, #4f6df5 0%, #5a7cf7 50%, #2ec6b4 130%);
  border-color: #5a7cf7;
  transform: translateY(-1px);
  box-shadow: 0 10px 24px rgba(61,83,245,.36);
}
.certd-x-login .wow-login-card .btn-login:active { transform: translateY(0); }

.certd-x-login .wow-login-card .login-alt { margin: 0 0 6px; color: #74777a; }
.certd-x-login .wow-login-card .login-alt a { color: #3d53f5; }

// 语言切换按钮 (nps 是右上角)
.certd-x-login .wow-language-switch {
  position: absolute;
  top: 18px;
  right: 22px;
  color: #6b7280;
  font-size: 13px;
}
.certd-x-login .wow-language-switch button#languagemenu {
  padding: 4px 10px;
  border: 1px solid #e5e7eb;
  border-radius: 9999px;
  color: #4b5563;
  background: transparent;
  cursor: pointer;
  font-size: 12px;
}
.certd-x-login .wow-language-switch button#languagemenu:hover { color: #3d53f5; border-color: #3d53f5; }

// 2FA 返回
.certd-x-login .wow-link-back { display: block; text-align: center; color: #4b5563; font-size: 13px; cursor: pointer; }
.certd-x-login .wow-link-back:hover { color: #3d53f5; }

// 让 ant-form 内层元素配合 nps 样式
.certd-x-login .wow-login-form .ant-input {
  border: 0;
  padding-left: 0;
  padding-right: 32px;
  height: 48px;
  border-radius: 0;
  background: transparent;
  box-shadow: none;
  font-size: 14px;
}
.certd-x-login .wow-login-form .ant-input-prefix,
.certd-x-login .wow-login-form .ant-input-suffix { display: none; }
</style>
