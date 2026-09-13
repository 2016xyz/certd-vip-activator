<template>
  <div class="task-shortcuts">
    <TaskShortcut v-for="(item, index) of shortcuts" :key="index" v-bind="item" />
  </div>
</template>
<script setup lang="ts">
import { ref, watch } from "vue";
import TaskShortcut from "./task-shortcut.vue";
import { usePluginStore } from "/@/store/plugin";

defineOptions({
  name: "TaskShortcuts",
});

const props = defineProps<{
  task: any;
}>();
const shortcuts = ref([]);
const pluginStore = usePluginStore();
watch(
  () => props.task,
  value => {
    init();
  },
  { immediate: true }
);

async function init() {
  const steps = props.task?.steps || [];
  if (steps.length === 0) {
    return;
  }
  const list = [];
  for (const step of steps) {
    const stepType = step.type;
    const pluginDefine = await pluginStore.getPluginDefine(stepType);
    if (pluginDefine.shortcut) {
      for (const key in pluginDefine.shortcut) {
        const shortcut = pluginDefine.shortcut[key];
        list.push({
          ...shortcut,
          pluginName: stepType,
          input: step.input,
          stepId: step.id,
        });
      }
    }
  }
  shortcuts.value = list;
}
</script>
