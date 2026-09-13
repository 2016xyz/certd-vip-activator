
# 授权插件Demo

```ts
import { AccessInput, BaseAccess, IsAccess } from '@certd/pipeline';
import { isDev } from '../../utils/env.js';

/**
 * 这个注解将注册一个授权配置
 * 在certd的后台管理系统中，用户可以选择添加此类型的授权
 */
@IsAccess({
  name: 'demo',
  title: '授权插件示例',
  icon: 'clarity:plugin-line',
  desc: '',
})
export class DemoAccess extends BaseAccess {
  /**
   * 授权属性配置
   */
  @AccessInput({
    title: '密钥Id',
    component: {
      placeholder: 'demoKeyId',
    },
    required: true,
  })
  demoKeyId = '';

  /**
   * 授权属性配置
   */
  @AccessInput({
    //标题
    title: '密钥串',
    component: {
      //input组件的placeholder
      placeholder: 'demoKeySecret',
    },
    //是否必填
    required: true,
    //改属性是否需要加密
    encrypt: true,
  })
  //属性名称
  demoKeySecret = '';
}
new DemoAccess();
```


# 阿里云授权
```ts

import { IsAccess, AccessInput, BaseAccess } from "@certd/pipeline";

@IsAccess({
  name: "aliyun",
  title: "阿里云授权",
  desc: "",
  icon: "ant-design:aliyun-outlined",
  order: 0,
})
export class AliyunAccess extends BaseAccess {
  @AccessInput({
    title: "accessKeyId",
    component: {
      placeholder: "accessKeyId",
    },
    helper: "登录阿里云控制台->AccessKey管理页面获取。",
    required: true,
  })
  accessKeyId = "";
  @AccessInput({
    title: "accessKeySecret",
    component: {
      placeholder: "accessKeySecret",
    },
    required: true,
    encrypt: true,
    helper: "注意：证书申请需要dns解析权限；其他阿里云插件，需要对应的权限，比如证书上传需要证书管理权限；嫌麻烦就用主账号的全量权限的accessKey",
  })
  accessKeySecret = "";
}

new AliyunAccess();
```