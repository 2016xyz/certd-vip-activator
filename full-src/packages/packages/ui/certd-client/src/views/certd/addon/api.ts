import { request } from "/src/api/service";
import { RequestHandleReq } from "/@/components/plugins/lib";
import { AddonTypeDefines } from "./types";

export function createAddonApi(opts: { from: any; addonType: string } = { from: "user", addonType: "" }) {
  let apiPrefix = "/addon";
  if (opts.from === "sys") {
    apiPrefix = "/sys/addon";
  }
  return {
    async GetList(query: any) {
      return await request({
        url: apiPrefix + "/page",
        method: "post",
        data: {
          ...query,
          query: {
            addonType: opts.addonType,
            ...query.query,
          },
        },
      });
    },

    async AddObj(obj: any) {
      return await request({
        url: apiPrefix + "/add",
        method: "post",
        data: {
          ...obj,
          addonType: opts.addonType,
        },
      });
    },

    async UpdateObj(obj: any) {
      return await request({
        url: apiPrefix + "/update",
        method: "post",
        data: obj,
      });
    },

    async DelObj(id: number) {
      return await request({
        url: apiPrefix + "/delete",
        method: "post",
        params: { id },
      });
    },

    async GetObj(id: number) {
      return await request({
        url: apiPrefix + "/info",
        method: "post",
        params: { id },
      });
    },

    async GetOptions(id: number) {
      return await request({
        url: apiPrefix + `/options?addonType=${opts.addonType}`,
        method: "post",
      });
    },

    async SetDefault(id: number) {
      return await request({
        url: apiPrefix + "/setDefault",
        method: "post",
        params: { id },
      });
    },

    async GetDefaultId() {
      return await request({
        url: apiPrefix + "/getDefaultId",
        method: "post",
      });
    },

    async GetSimpleInfo(id: number) {
      return await request({
        url: apiPrefix + `/simpleInfo?addonType=${opts.addonType}`,
        method: "post",
        params: { id },
      });
    },

    async GetDefineTypes() {
      return await request({
        url: apiPrefix + `/getTypeDict?addonType=${opts.addonType}`,
        method: "post",
      });
    },

    async GetProviderDefine(type: string) {
      return await request({
        url: apiPrefix + `/define?addonType=${opts.addonType}`,
        method: "post",
        params: { type },
      });
    },

    async GetProviderDefineByType(type: string) {
      return await request({
        url: apiPrefix + `/defineByType?addonType=${opts.addonType}`,
        method: "post",
        params: { type },
      });
    },

    async Handle(req: RequestHandleReq, opts: any = {}) {
      const url = `/handle/${req.type}?addonType=${opts.addonType}`;
      const { typeName, action, data, input } = req;
      const res = await request({
        url,
        method: "post",
        data: {
          typeName,
          action,
          data,
          input,
        },
        ...opts,
      });
      return res;
    },
  };
}

export function getAddonTypeDefine(addonType: string) {
  return AddonTypeDefines[addonType];
}
