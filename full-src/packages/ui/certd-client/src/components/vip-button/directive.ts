import { useSettingStore } from "/@/store/settings";

export default {
  mounted(el: any, binding: any, vnode: any) {
    const { value } = binding;
    const settingStore = useSettingStore();
    el.className = el.className + " need-plus";
    if (!settingStore.isPlus) {
      el.addEventListener("click", function (event: any) {
        event.stopPropagation();
        event.preventDefault();
        settingStore.checkPlus();
      });
      el.addEventListener("move", function (event: any) {
        event.stopPropagation();
        event.preventDefault();
        settingStore.checkPlus();
      });
    }
  },
};
