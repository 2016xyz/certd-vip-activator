<template>
  <div class="pi-group-selector flex full-w">
    <div class="flex-1">
      <fs-dict-select :value="modelValue" :dict="groupDictRef" :allow-clear="true" @update:value="doUpdate"></fs-dict-select>
    </div>

    <fs-table-select
      class="flex-0"
      :create-crud-options="createCrudOptions"
      :crud-options-override="{
        search: { show: false },
        table: {
          scroll: {
            x: 540,
          },
        },
      }"
      :model-value="modelValue"
      :dict="groupDictRef"
      :show-current="false"
      :show-select="false"
      :dialog="{ width: 960 }"
      :destroy-on-close="false"
      height="400px"
      @update:model-value="doUpdate"
      @dialog-closed="doRefresh"
    >
      <template #default="scope">
        <fs-button class="ml-5" type="primary" icon="ant-design:edit-outlined" @click="scope.open"></fs-button>
      </template>
    </fs-table-select>
  </div>
</template>

<script setup lang="ts">
import createCrudOptions from "./crud";
import { dict, FsDictSelect } from "@fast-crud/fast-crud";
import { groupDictRef } from "./dicts";

const props = defineProps<{
  modelValue?: number;
}>();

defineOptions({
  name: "GroupSelector",
});

const emit = defineEmits(["refresh", "update:modelValue"]);
function doRefresh() {
  emit("refresh");
  groupDictRef.reloadDict();
}

function doUpdate(value: any) {
  emit("update:modelValue", value);
}
</script>
