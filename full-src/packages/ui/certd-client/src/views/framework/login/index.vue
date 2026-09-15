<!-- ============================================================
     certd-x 登录页 · 1:1 完全还原统一协同平台 (1000.2016xlx.cn:3011)
     + 新增: 忘记密码 / 注册 / 第三方 OAuth (按 certd 原生逻辑)
     ============================================================ -->
<template>
  <main class="wow-login-page">
    <div class="wow-login-background" aria-hidden="true"></div>
    <div class="wow-login-content">
      <header class="wow-login-header">
        <div class="wow-login-title">certd-x</div>
        <div class="wow-login-subtitle">Certificate Automation Platform</div>
      </header>

      <section class="wow-login-card">
        <!-- 语言切换 (右上) -->
        <div class="wow-language-switch i18n">
          <button id="languagemenu" type="button" aria-label="Language" @click="toggleLang">{{ langLabel }}</button>
        </div>

        <!-- 登录表单 -->
        <form class="wow-login-form" onsubmit="return false;" v-if="!twoFactor.loginId">
          <div class="wow-input-group form-group">
            <span class="wow-input-icon user-icon" aria-hidden="true"><i class="fas fa-user"></i></span>
            <input class="form-control" name="username" v-model.trim="formState.username"
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

          <!-- ★ 忘记密码 / 注册链接 (login-alt 双链接区) -->
          <div class="wow-login-card .login-alt login-alt">
            <router-link v-if="!!settingStore.sysPublic.selfServicePasswordRetrievalEnabled && !queryBindCode"
                         :to="{ name: 'forgotPassword' }">
             忘记密码
            </router-link>
            <a v-else-if="!queryBindCode" href="https://certd.docmirror.cn/guide/use/forgotpasswd/" target="_blank">
              忘记密码
            </a>
            <span class="login-alt-sep">|</span>
            <router-link v-if="hasRegisterTypeEnabled() && !queryBindCode"
                         :to="{ name: 'register' }" class="wow-link-strong">
              注册账号
            </router-link>
          </div>
        </form>

        <!-- 2FA OTP 表单 -->
        <form class="wow-login-form" onsubmit="return false;" v-if="twoFactor.loginId">
          <div class="cx-2fa-tip">请打开您的 Authenticator APP，获取动态验证码</div>
          <div class="wow-input-group form-group">
            <span class="wow-input-icon password-icon" aria-hidden="true"><i class="fas fa-shield-alt"></i></span>
            <input class="form-control" name="verifyCode" ref="verifyCodeInputRef" v-model="twoFactor.verifyCode"
                   placeholder="动态验证码" autocomplete="one-time-code" required />
          </div>
          <button id="loginBtn2FA" class="btn btn-primary btn-login block full-width"
                  :disabled="loading" type="submit" @click="handleTwoFactorSubmit">
            <span class="btn-label">OTP 验证登录</span>
          </button>
          <a class="wow-link-back" @click="twoFactor.loginId = null;">← 返回</a>
        </form>

        <!-- ★ 第三方登录 (OAuth + Passkey), 分割线 + 列表按钮 -->
        <div class="wow-oauth-section" v-if="!queryBindCode && oauthEnabledOrPasskey && settingStore.isPlus">
          <div class="oauth-divider">
            <span class="oauth-title">第三方账号登录</span>
          </div>
          <oauth-footer :oauth-only="isOauthOnly"></oauth-footer>
        </div>
      </section>

      <footer class="wow-login-footer">
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

const route = useRoute();
const userStore = useUserStore();
const settingStore = useSettingStore();
const { t } = useI18n();

const queryBindCode = ref(route.query.bindCode as string | undefined);
const queryOauthOnly = route.query.oauthOnly as string;
const verifyCodeInputRef = ref();
const loading = ref(false);
const showPwd = ref(false);
const rememberMe = ref(false);
const langLabel = ref('中文');

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

function handleFinish() {
  loading.value = true;
  if (formState.loginType === "password" || formState.loginType === "sms") {
    userStore.login(formState.loginType, toRaw(formState))
      .then(() => {
        if (queryBindCode.value) {
          return oauthApi.BindUser(queryBindCode.value).then(() => {
            notification.success({ message: "绑定第三方账号成功" });
          });
        }
      })
      .catch((e: any) => {
        if (e.code === 10020) {
          twoFactor.loginId = e.data;
          nextTick(() => verifyCodeInputRef.value?.focus?.());
        } else {
          notification.error({ message: e?.message || "登录失败" });
        }
      })
      .finally(() => {
        loading.value = false;
        formState.captcha = null;
      });
  }
}

function handleTwoFactorSubmit() {
  loading.value = true;
  userStore.loginByTwoFactor(twoFactor)
    .then(() => {
      if (queryBindCode.value) {
        return oauthApi.BindUser(queryBindCode.value).then(() => notification.success({ message: "绑定第三方账号成功" }));
      }
    })
    .catch((e: any) => notification.error({ message: e?.message || "登录失败" }))
    .finally(() => { loading.value = false; });
}

function toggleLang() {
  langLabel.value = langLabel.value === '中文' ? 'English' : '中文';
  // 切 i18n 全局:
  if (typeof (window as any).__setCertdxLang__ === 'function') {
    (window as any).__setCertdxLang__(langLabel.value === '中文' ? 'zh-CN' : 'en-US');
  } else {
    // 备用: location reload 或调 vben locale manager
    location.reload();
  }
}

onMounted(() => {
  // 记住账号
  const saved = localStorage.getItem('nps_login_username') || '';
  if (saved) { formState.username = saved; rememberMe.value = true; }
});
</script>

<style lang="less">
// ============================================================
// 1:1 还原 统一协同平台 1000.2016xlx.cn:3011/login/index
//  keyfreams + styles 精准仿 up-sample
// ============================================================
.certd-x-login {
  width: 100%; min-height: 100vh; overflow: hidden;
  color: #191e2d;
}
.certd-x-login.wow-login-page { position: relative; min-height: 100vh; }

// ✓ background
.certd-x-login .wow-login-background {
  position: absolute; inset: 0;
  background:
    radial-gradient(circle at 18% 18%, rgba(255,255,255,0.26), transparent 30%),
    radial-gradient(circle at 86% 86%, rgba(52,197,180,0.2), transparent 32%),
    linear-gradient(135deg, #1b3468 0%, #2d529a 32%, #466ab2 58%, #6f9bd1 80%, #93bde4 100%);
  background-position: center; background-size: 180% 180%;
  transform: scale(1.02);
  animation: cx-bg-shift 20s ease-in-out infinite alternate;
}
.certd-x-login .wow-login-background:before,
.certd-x-login .wow-login-background:after {
  position: absolute; border-radius: 50%; content: ""; filter: blur(2px);
}
.certd-x-login .wow-login-background:before {
  top: 10%; left: 7%; width: 22vw; height: 22vw;
  min-width: 180px; min-height: 180px;
  background: radial-gradient(circle at 35% 35%, rgba(255,255,255,0.14), rgba(255,255,255,0.05) 60%, transparent 72%);
  animation: cx-float-a 16s ease-in-out infinite;
}
.certd-x-login .wow-login-background:after {
  right: 7%; bottom: 9%;
  width: 28vw; height: 28vw;
  min-width: 220px; min-height: 220px;
  background: radial-gradient(circle at 40% 40%, rgba(46,214,190,0.16), rgba(46,214,190,0.06) 58%, transparent 72%);
  animation: cx-float-b 19s ease-in-out infinite;
}

// keyframes:
@keyframes cx-bg-shift {
  0% { background-position: 0% 0%; }
  100% { background-position: 100% 100%; }
}
@keyframes cx-float-a {
  0%, 100% { transform: translate(0,0) scale(1); }
  50% { transform: translate(3vw, 5vh) scale(1.08); }
}
@keyframes cx-float-b {
  0%, 100% { transform: translate(0,0) scale(1); }
  50% { transform: translate(-3vw,-4vh) scale(1.06); }
}
@keyframes cx-rise {
  from { opacity: 0; transform: translateY(22px); }
  to   { opacity: 1; transform: translateY(0); }
}

// ✓ content
.certd-x-login .wow-login-content {
  position: relative; z-index: 1;
  display: flex; flex-direction: column; align-items: center; justify-content: center;
  min-height: 100vh; padding: 42px 20px 88px; box-sizing: border-box;
}

// ✓ header
.certd-x-login .wow-login-header {
  position: relative; margin-bottom: 2px; color: #fff;
  text-align: center; text-shadow: rgba(0,0,0,0.2) 0 0 6px;
}
.certd-x-login .wow-login-title {
  margin: 0 0 10px; color: #fff;
  font-size: clamp(26px, 3vw, 38px);
  font-weight: 600; line-height: 1.2;
  letter-spacing: 12px; text-indent: 12px;
}
.certd-x-login .wow-login-subtitle {
  margin: 0 0 28px; color: rgba(255,255,255,0.72);
  font-size: clamp(11px, 1.1vw, 13px); font-weight: 400;
  letter-spacing: 4px; text-indent: 4px; text-transform: uppercase;
}

// ✓ card (原本统一样式)
.certd-x-login .wow-login-card {
  position: relative; overflow: hidden; width: 400px; box-sizing: border-box;
  padding: 40px 35px 20px;
  border: 1px solid rgba(255,255,255,0.52);
  border-radius: 14px;
  background: rgba(255,255,255,0.97);
  box-shadow: 0 24px 60px rgba(19,43,96,0.28), 0 4px 12px rgba(19,43,96,0.12);
  animation: cx-rise 0.7s cubic-bezier(0.22,0.61,0.36,1) both;
}
.certd-x-login .wow-login-card:before {
  position: absolute; top: 0; right: 0; left: 0; height: 3px;
  background: linear-gradient(90deg, #3d53f5, #6f9bd1 45%, #2ec6b4);
  content: "";
}

// ✓ login form
.certd-x-login .wow-login-form .form-group { margin-bottom: 20px; }

.certd-x-login .wow-login-form .wow-input-group {
  position: relative; display: flex; height: 50px;
  border: 1px solid #dcdfe6; border-radius: 4px; background: #fff;
  transition: border-color .2s ease;
}
.certd-x-login .wow-input-group:focus-within {
  border-color: #3d53f5;
  box-shadow: 0 0 0 3px rgba(61,83,245,0.12);
}
.certd-x-login .wow-input-group:focus-within .wow-input-icon { color: #3d53f5; }

.certd-x-login .wow-input-icon {
  display: flex; align-items: center; justify-content: center;
  width: 48px; flex: 0 0 48px; color: #b8bec5; font-size: 16px;
}

.certd-x-login .wow-input-group .form-control {
  flex: 1; height: 50px; padding: 0 12px 0 0;
  border: 0; outline: 0; font-size: 14px;
  color: #191e2d; background: transparent;
  border-radius: 0 4px 4px 0; box-shadow: none;
}
.certd-x-login .wow-input-group .form-control::placeholder { color: #9aa1a9; }

.certd-x-login .wow-input-group .pwd-toggle {
  position: absolute; top: 50%; right: .6rem;
  transform: translateY(-50%);
  height: 2.1rem; width: 2.1rem; padding: 0;
  border: none; background: transparent; color: #94a3b8;
  border-radius: .45rem; line-height: 1; cursor: pointer;
}
.certd-x-login .wow-input-group .pwd-toggle:hover { color: #3d53f5; }

.certd-x-login .wow-verification { display: flex; align-items: center; }

// 验证码容器 (图) — antd CaptchaInput 印输出
.certd-x-login .wow-verification .ant-row { width: 100%; }
.certd-x-login .wow-verification .captcha-container { display: flex; align-items: center; height: 40px; margin-left: 10px; }
.certd-x-login .wow-verification .captcha-img { display: block; height: 36px; border-radius: 3px; cursor: pointer; }

.certd-x-login .wow-remember {
  display: flex; align-items: center; margin: 0 0 16px;
  color: #515560; font-size: 13px; cursor: pointer; user-select: none;
}
.certd-x-login .wow-remember input { accent-color: #3d53f5; margin: 0 5px 0 0; vertical-align: -2px; }

// ✓ login button
.certd-x-login .wow-login-card .btn-login {
  height: auto; min-height: 48px; width: 100%;
  margin: 2px 0 18px; padding: 13px 0;
  border: 1px solid #3d53f5; border-radius: 4px; color: #fff;
  background: linear-gradient(135deg, #3d53f5 0%, #4f6df5 60%, #5a7cf7 100%);
  box-shadow: 0 6px 16px rgba(61,83,245,0.28);
  font-size: 16px; font-weight: 400; letter-spacing: 2px;
  cursor: pointer;
  transition: box-shadow .25s ease, transform .25s ease, background .25s ease;
}
.certd-x-login .wow-login-card .btn-login:hover,
.certd-x-login .wow-login-card .btn-login:focus {
  color: #fff;
  background: linear-gradient(135deg, #4f6df5 0%, #5a7cf7 50%, #2ec6b4 130%);
  border-color: #5a7cf7;
  transform: translateY(-1px);
  box-shadow: 0 10px 24px rgba(61,83,245,0.36);
}
.certd-x-login .wow-login-card .btn-login:active { transform: translateY(0); }
.certd-x-login .wow-login-card .btn-login:disabled { opacity: .75; cursor: not-allowed; }

// ✓ login-alt  ( forgot / register / 品牌 )
.certd-x-login .wow-login-card .login-alt {
  margin: 0 0 6px; color: #74777a;
  display: flex; align-items: center; justify-content: space-between;
  padding-top: 4px;
  font-size: 13px;
}
.certd-x-login .wow-login-card .login-alt a { color: #3d53f5; text-decoration: none; transition: color .2s; }
.certd-x-login .wow-login-card .login-alt a:hover { color: #0e6ba8; }
.certd-x-login .wow-login-card .login-alt a.wow-link-strong { color: #111; font-weight: 600; }
.certd-x-login .wow-login-card .login-alt a.wow-link-strong:hover { color: #3d53f5; }
.certd-x-login .wow-login-card .login-alt .login-alt-sep { color: #ccc; margin: 0 8px; }

// ✓ 第三方 oauth + passkey
.certd-x-login .wow-oauth-section {
  margin-top: 16px;
  border-top: 1px solid #eef1f4;
  padding-top: 12px;
}
.certd-x-login .wow-oauth-section .oauth-title {
  position: relative;
  font-size: 12px; color: #94a3b8; text-align: center; margin-bottom: 10px;
}
.certd-x-login .wow-oauth-section :deep(.oauth-title-text) { display: inline-block; background: #fff; padding: 0 10px; }
.certd-x-login .wow-oauth-section :deep(.oauth-icon-button) {
  display: inline-flex; flex-direction: column; align-items: center;
  min-width: 72px; padding: 6px; border-radius: 10px;
  background: #f8fafc; cursor: pointer; transition: background .2s;
}
.certd-x-login .wow-oauth-section :deep(.oauth-icon-button .title) {
  font-size: 11px; margin-top: 4px; color: #475569; max-width: 96px;
}
.certd-x-login .wow-oauth-section :deep(.oauth-icon-button:hover) { background: #eef6fb; }

// ✓ 2FA (流动)
.certd-x-login .cx-2fa-tip { color: #74777a; font-size: 13px; margin-bottom: 18px; }
.certd-x-login .wow-link-back { display: block; text-align: center; color: #4b5563; font-size: 13px; cursor: pointer; }
.certd-x-login .wow-link-back:hover { color: #3d53f5; }

// ✓ language 切换(右上)
.certd-x-login .wow-language-switch {
  position: absolute; top: 18px; right: 22px;
  color: #6b7280; font-size: 12px;
}
.certd-x-login .wow-language-switch button#languagemenu {
  padding: 4px 10px; border: 1px solid #e5e7eb; border-radius: 9999px;
  color: #4b5563; background: transparent; cursor: pointer; font-size: 12px;
}
.certd-x-login .wow-language-switch button#languagemenu:hover { color: #3d53f5; border-color: #3d53f5; }

// ✓ footer
.certd-x-login .wow-login-footer {
  margin-top: 18px;
  color: rgba(255,255,255,.56);
  font-size: 11px; text-align: center; letter-spacing: 1px;
  user-select: none;
}

// ✓ ant-form style override 兼容
.certd-x-login .wow-login-form .ant-input,
.certd-x-login .wow-login-form .ant-input-affix-wrapper {
  border: 0; box-shadow: none; background: transparent; padding: 0; height: 50px; border-radius: 0;
  font-size: 14px;
}
.certd-x-login .wow-login-form .ant-input-prefix,
.certd-x-login .wow-login-form .ant-input-suffix { display: none !important; }
.certd-x-login .wow-login-form .ant-form-item { margin: 0; }
</style>
