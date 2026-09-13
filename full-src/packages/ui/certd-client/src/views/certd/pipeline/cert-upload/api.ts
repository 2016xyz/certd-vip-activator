import { request } from "/src/api/service";

const apiPrefix = "/monitor/cert";
export async function UploadCert(body: { id?: number; cert: { crt: string; key: string }; pipeline?: any }) {
  return await request({
    url: apiPrefix + "/upload",
    method: "post",
    data: body,
  });
}
