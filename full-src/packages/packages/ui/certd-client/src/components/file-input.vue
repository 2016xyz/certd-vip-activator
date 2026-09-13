<template>
  <div class="file-input">
    <a-button :type="type" @click="onClick">{{ text }}</a-button> {{ fileName }}
    <div class="hidden">
      <input ref="fileInputRef" type="file" @change="onFileChange" />
    </div>
  </div>
</template>

<script lang="ts" setup>
import { ref, defineEmits, defineProps } from "vue";
const fileInputRef = ref<HTMLInputElement | null>(null);

const props = defineProps<{
  text: string;
  type: string;
}>();
const fileName = ref("");
const emit = defineEmits(["change"]);
function onClick() {
  fileInputRef.value.click();
}
function onFileChange(e: any) {
  fileName.value = e.target.files[0].name;
  emit("change", e);
}
</script>
