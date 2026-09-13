// @ts-ignore
import { request } from "/src/api/service";
const apiPrefix = "/monitor/site/setting";
export type UserSiteMonitorSetting = {
  notificationId?: number;
  retryTimes?: number;
  cron?: string;
  dnsServer?: string[];
  certValidDays?: number;
};

export async function SiteMonitorSettingsGet() {
  const res = await request({
    url: apiPrefix + "/get",
    method: "post",
  });
  if (!res) {
    return {};
  }
  return res as UserSiteMonitorSetting;
}
export async function SiteMonitorSettingsSave(data: UserSiteMonitorSetting) {
  await request({
    url: apiPrefix + "/save",
    method: "post",
    data: data,
  });
}
