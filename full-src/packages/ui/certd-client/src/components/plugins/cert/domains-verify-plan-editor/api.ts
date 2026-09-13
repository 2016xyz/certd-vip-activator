import { request } from "/src/api/service";

const apiPrefix = "/cname/record";
const subDomainApiPrefix = "/pi/subDomain";

export type CnameRecord = {
  id?: number;
  status?: string;
  hostRecord?: string;
  recordValue?: string;
  error?: string;
};

export type DomainGroupItem = {
  domain: string;
  domains?: string[];
  keySubDomains?: string[];
};

export async function GetList() {
  return await request({
    url: apiPrefix + "/list",
    method: "post",
  });
}

export async function GetByDomain(domain: string) {
  return await request({
    url: apiPrefix + "/getByDomain",
    method: "post",
    data: {
      domain,
      createOnNotFound: true,
    },
  });
}

export async function DoVerify(id: number) {
  return await request({
    url: apiPrefix + "/verify",
    method: "post",
    data: {
      id,
    },
  });
}

export async function ResetStatus(id: number) {
  return await request({
    url: apiPrefix + "/resetStatus",
    method: "post",
    data: {
      id,
    },
  });
}

export async function ParseDomain(fullDomain: string) {
  return await request({
    url: subDomainApiPrefix + "/parseDomain",
    method: "post",
    data: {
      fullDomain,
    },
  });
}
