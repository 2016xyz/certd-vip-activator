# 部署证书到ESXi

使用`部署证书到主机插件`即可


## 开启ssh
登陆ESXi Web后台，点击 主机 -> 操作 -> 服务 -> 启用 Secure Shell（SSH）打开SSH

## 添加部署到主机任务

![img.png](./images/ssh.png)

## 配置重启脚本
```bash
/etc/init.d/hostd restart
/etc/init.d/vpxa restart
```
