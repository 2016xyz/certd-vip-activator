<template>
  <div ref="captchaRef" class="geetest_captcha_wrapper"></div>
</template>
<script setup lang="ts">
import { onMounted, defineProps, defineEmits, ref, onUnmounted, Ref, watch } from "vue";
import { useSettingStore } from "/@/store/settings";
import { request } from "/src/api/service";
import { notification } from "ant-design-vue";

import { loadScript } from "vue-plugin-load-script";
const loaded = ref(false);
async function loadCaptchaScript() {
  // 加载验证码js
  await loadScript("https://static.geetest.com/v4/gt4.js");
  loaded.value = true;
}

defineOptions({
  name: "GeetestCaptcha",
});
const emit = defineEmits(["update:modelValue", "change"]);
const props = defineProps<{
  modelValue: any;
  captchaGet: () => Promise<any>;
}>();
const captchaRef = ref(null);

const captchaInstanceRef: Ref = ref({});
async function init() {
  await loadCaptchaScript();
  const { captchaId } = await props.captchaGet();
  // @ts-ignore
  initGeetest4(
    {
      captchaId: captchaId,
    },
    (captcha: any) => {
      // captcha为验证码实例
      captcha.appendTo(captchaRef.value); // 调用appendTo将验证码插入到页的某一个元素中，这个元素用户可以自定义
      captchaInstanceRef.value.instance = captcha;
      captchaInstanceRef.value.captchaId = captchaId;

      captcha.onSuccess(function () {
        const form = getCaptchaForm();
        if (form) {
          emitChange(form);
        }
      });
    }
  );
}

function getCaptchaForm() {
  if (!captchaInstanceRef.value?.instance) {
    // notification.error({
    //   message: "验证码还未初始化",
    // });
    return false;
  }
  const result = captchaInstanceRef.value.instance.getValidate();
  if (!result) {
    // notification.error({
    //   message: "请先完成验证码验证",
    // });
    return false;
  }
  result.captcha_id = captchaInstanceRef.value.captchaId;

  return result;
}

// const valueRef = ref(null);
// const timeoutId = setInterval(() => {
//   const form = getCaptchaForm();
//   if (form && valueRef.value != form) {
//     console.log("form", form);
//     valueRef.value = form;
//     emitChange(form);
//   }
// }, 1000);

// onUnmounted(() => {
//   clearTimeout(timeoutId);
// });

function emitChange(value: string) {
  emit("update:modelValue", value);
  emit("change", value);
}
function reset() {
  captchaInstanceRef.value.instance.reset();
}

watch(
  () => {
    return props.modelValue;
  },
  value => {
    if (value == null) {
      reset();
    }
  }
);

defineExpose({
  getCaptchaForm,
  reset,
});

watch(
  () => [props.captchaGet],
  async () => {
    await init();
  }
);

onMounted(async () => {
  await init();
});
</script>
<style lang="less">
.geetest_captcha_wrapper {
  .geetest_captcha {
    .geetest_holder {
      width: 100%;
    }
  }
}
</style>
