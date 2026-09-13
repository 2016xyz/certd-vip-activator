<template>
  <component :is="captchaComponent" v-if="settingStore.inited" ref="captchaRef" :model-value="modelValue" class="captcha_input" :captcha-get="getCaptcha" @change="onChange" />
</template>
<script setup lang="ts">
import { ref, computed, defineAsyncComponent } from "vue";
import { useSettingStore } from "/@/store/settings";
import { nanoid } from "nanoid";
import { request } from "/@/api/service";

const props = defineProps({
  modelValue: {
    type: Object,
    default: () => ({}),
  },
  type: {
    type: String,
    default: "image",
  },
  addonId: {
    type: Number,
    default: 0,
  },
});
const captchaRef = ref(null);
const settingStore = useSettingStore();

const emits = defineEmits(["update:modelValue", "change"]);
const captchaImpls = import.meta.glob("./captchas/*.vue");

const captchaAddonId = computed(() => {
  return settingStore.sysPublic.captchaAddonId ?? 0;
});
const captchaComponent = computed(() => {
  let type: any = props.type ?? "image";
  if (settingStore.sysPublic.captchaAddonId && settingStore.sysPublic.captchaType) {
    type = settingStore.sysPublic.captchaType;
  }
  const componentName = `${type}_captcha`;
  return defineAsyncComponent(captchaImpls[`./captchas/${componentName}.vue`]);
});

async function getCaptcha(): Promise<any> {
  const randomStr = nanoid(10);
  return await request({
    url: `/basic/code/captcha/get?randomStr=${randomStr}`,
    method: "post",
    data: {
      captchaAddonId: captchaAddonId.value,
    },
  });
}

function onChange(data: any) {
  emits("update:modelValue", data);
  emits("change", data);
}

async function getCaptchaForm() {
  return await captchaRef.value?.getCaptchaForm();
}
async function reset() {
  await captchaRef.value?.reset();
}
defineExpose({
  getCaptchaForm,
  reset,
});
</script>
