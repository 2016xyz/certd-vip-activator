import { request } from "/@/api/service";

export async function DomainResolve(domain: string) {
  return await request({
    url: "/sys/nettest/domainResolve",
    method: "post",
    data: { domain },
  });
}

export async function PingTest(domain: string) {
  return await request({
    url: "/sys/nettest/ping",
    method: "post",
    data: { domain },
  });
}

export async function TelnetTest(domain: string, port: number) {
  return await request({
    url: "/sys/nettest/telnet",
    method: "post",
    data: { domain, port },
  });
}

// 获取服务器信息（包括本地IP、外网IP和DNS服务器）
export async function GetServerInfo() {
  return await request({
    url: "/sys/nettest/serverInfo",
    method: "post",
  });
}
