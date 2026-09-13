import { request } from "/src/api/service";

const apiPrefix = "/monitor/site/ip";

export const siteIpApi = {
  async GetList(query: any) {
    return await request({
      url: apiPrefix + "/page",
      method: "post",
      data: query,
    });
  },

  async AddObj(obj: any) {
    return await request({
      url: apiPrefix + "/add",
      method: "post",
      data: obj,
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
  async DoCheck(id: number) {
    return await request({
      url: apiPrefix + "/check",
      method: "post",
      data: { id },
    });
  },
  async CheckAll(siteId: number) {
    return await request({
      url: apiPrefix + "/checkAll",
      method: "post",
      data: {
        siteId,
      },
    });
  },

  async DoSync(siteId: number) {
    return await request({
      url: apiPrefix + "/sync",
      method: "post",
      data: {
        siteId,
      },
    });
  },
  async Import(form: any) {
    return await request({
      url: apiPrefix + "/import",
      method: "post",
      data: form,
    });
  },
};
