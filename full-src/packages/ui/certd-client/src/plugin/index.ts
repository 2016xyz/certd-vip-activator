import "./iconify";
import "./iconfont";
import FastCrud from "./fast-crud";
import permission from "./permission";
import { App } from "vue";
import "./validator/index.js";
import directives from "./directive/index";
import { setupMonaco } from "./monaco";
function install(app: App, options: any = {}) {
  app.use(FastCrud, options);
  app.use(permission);
  app.use(directives);
  setupMonaco();
}

export default {
  install,
};
