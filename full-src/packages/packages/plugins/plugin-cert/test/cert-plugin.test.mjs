import { expect } from "chai";
import { CertApplyPlugin } from "../dist/index.js";
import dayjs from "dayjs";
import { logger } from "@certd/basic";

describe("test/cert-plugin.ts", () => {
  const certApplyPlugin = new CertApplyPlugin();
  certApplyPlugin.logger = logger;
  it("should throw error when expires is null or undefined", () => {
    expect(() => {
      // @ts-ignore
      certApplyPlugin.isWillExpire(undefined);
    }).throw("过期时间不能为空");

    expect(() => {
      // @ts-ignore
      certApplyPlugin.isWillExpire(null);
    }).throw("过期时间不能为空");
  });

  it("isWillExpire", () => {
    const now = dayjs().add(36, "day") - 10000;
    const res = certApplyPlugin.isWillExpire(now.valueOf(), 35);
    console.log(res);
    expect(res.isWillExpire).eq(true);
  });
});
