import comm from "./comm-show.js";
const install = function (app: any) {
  app.directive("comm", comm);
};

export default {
  install,
};
