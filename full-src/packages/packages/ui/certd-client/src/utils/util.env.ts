import { forEach } from "lodash-es";
export function getEnvValue(key: string) {
  // @ts-ignore
  return import.meta.env["VITE_APP_" + key];
}

export class EnvConfig {
  MODE: string = import.meta.env.MODE;
  API: string;
  STORAGE: string;
  TITLE: string;
  SLOGAN: string;
  LOGO: string;
  LOGIN_LOGO: string;
  ICP_NO: string;
  COPYRIGHT_YEAR: string;
  COPYRIGHT_NAME: string;
  COPYRIGHT_URL: string;
  PM_ENABLED: string;
  VIP_PRODUCT_URL: string;

  constructor() {
    this.init();
  }
  init() {
    const env = import.meta.env;
    for (const key in this) {
      const metaKey = "VITE_APP_" + key;
      if (this.hasOwnProperty(key) && env.hasOwnProperty(metaKey)) {
        this[key] = env[metaKey];
      }
    }
  }

  get(key: string, defaultValue: string) {
    //@ts-ignore
    return this[key] ?? defaultValue;
  }
  isDev() {
    return this.MODE === "development" || this.MODE === "debug";
  }
  isProd() {
    return this.MODE === "production";
  }
}

export const env = new EnvConfig();
