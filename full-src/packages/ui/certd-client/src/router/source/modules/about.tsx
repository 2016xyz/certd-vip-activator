import { IFrameView } from "/@/vben/layouts";
import { useSettingStore } from "/@/store/settings";
import { computed } from "vue";
import TutorialButton from "/@/components/tutorial/index.vue";
import i18n from "/@/locales/i18n";

export const aboutResource = [
  {
    title: "certd.dashboard.helpDoc",
    name: "document",
    path: "/about/doc",
    component: IFrameView,
    meta: {
      icon: "lucide:book-open-text",
      link: "https://certd.docmirror.cn",
      title: "certd.dashboard.helpDoc",
      order: 9999,
      show: () => {
        const settingStore = useSettingStore();
        return !settingStore.isComm;
      },
    },
  },
];

export default aboutResource;
