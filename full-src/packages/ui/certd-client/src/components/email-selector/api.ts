import { request } from "/src/api/service";

export async function EmailList() {
  return await request({
    url: "/mine/email/list",
    method: "post",
    data: {},
  });
}

export async function EmailDelete(email: string) {
  return await request({
    url: "/mine/email/delete",
    method: "post",
    data: {
      email: email,
    },
  });
}

export async function EmailAdd(email: string) {
  return await request({
    url: "/mine/email/add",
    method: "post",
    data: {
      email: email,
    },
  });
}
