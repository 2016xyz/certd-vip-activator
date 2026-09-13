import { useI18n } from "/src/locales";
import { Ref, ref } from "vue";
import { useRouter } from "vue-router";
import { AddReq, compute, CreateCrudOptionsProps, CreateCrudOptionsRet, DelReq, EditReq, UserPageQuery, UserPageRes } from "@fast-crud/fast-crud";
import { useSettingStore } from "/@/store/settings";
import { cloneDeep, find, merge, remove } from "lodash-es";
import { nanoid } from "nanoid";
import { HeaderMenusSettingsSave, SettingsSave } from "../api";
import { utils } from "/@/utils";

export default function ({ crudExpose, context }: CreateCrudOptionsProps): CreateCrudOptionsRet {
  const { crudBinding } = crudExpose;
  const router = useRouter();
  const { t } = useI18n();
  const settingStore = useSettingStore();

  async function saveMenus() {
    const menus = settingStore.headerMenus;
    await HeaderMenusSettingsSave(menus);
  }

  const expandedRowKeys = ref<string[]>([]);
  const pageRequest = async (query: UserPageQuery): Promise<UserPageRes> => {
    const records = cloneDeep(settingStore.headerMenus?.menus || []);
    expandedRowKeys.value = [];
    utils.tree.eachTree(records, (item: any) => {
      if (item.children && item.children.length > 0) {
        expandedRowKeys.value.push(item.id);
      }
    });

    return {
      records: records,
      total: records.length,
      limit: 9999999,
      offset: 0,
    };
  };
  const editRequest = async ({ form, row }: EditReq) => {
    form.id = row.id;
    let found: any = undefined;
    utils.tree.eachTree(settingStore.headerMenus?.menus || [], item => {
      if (item.id === row.id) {
        merge(item, form);
        found = item;
      }
    });
    await saveMenus();
    return found;
  };
  const delRequest = async ({ row }: DelReq) => {
    utils.tree.eachTree([{ children: settingStore.headerMenus?.menus }], item => {
      if (item.children) {
        remove(item.children, (child: any) => child.id === row.id);
      }
    });
    await saveMenus();
  };

  const addRequest = async ({ form }: AddReq) => {
    form.id = nanoid();
    if (form.parentId) {
      utils.tree.eachTree(settingStore.headerMenus?.menus || [], item => {
        if (item.id === form.parentId) {
          if (!item.children) {
            item.children = [];
          }
          item.children.push(form);
        }
      });
    } else {
      settingStore.headerMenus?.menus.push(form);
    }
    await saveMenus();
    return form;
  };

  return {
    crudOptions: {
      request: {
        pageRequest,
        addRequest,
        editRequest,
        delRequest,
      },
      search: {
        show: false,
      },
      table: {
        expandRowByClick: true,
        defaultExpandAllRows: true,
        expandedRowKeys: expandedRowKeys,
        "onUpdate:expandedRowKeys": (val: string[]) => {
          expandedRowKeys.value = val;
        },
      },
      pagination: { show: false, pageSize: 9999999 },
      rowHandle: {
        width: 300,
        fixed: "right",
        buttons: {
          addChild: {
            title: "添加子菜单",
            text: null,
            type: "link",
            icon: "ion:add-circle-outline",
            click: ({ row }) => {
              crudExpose.openAdd({
                row: {
                  parentId: row.id,
                },
              });
            },
          },
        },
      },
      columns: {
        id: {
          title: "ID",
          key: "id",
          type: "text",
          column: {
            width: 200,
            show: false,
          },
          form: {
            show: false,
          },
        },
        title: {
          title: "菜单标题",
          type: "text",
          column: {
            width: 300,
          },
          form: {
            rules: [
              {
                required: true,
                message: "请输入标题",
              },
            ],
          },
        },
        icon: {
          title: "图标",
          type: "icon",
          column: {
            width: 300,
            cellRender: ({ row }) => {
              return <fs-icon class={"fs-16"} icon={row.icon}></fs-icon>;
            },
          },
          form: {
            component: {
              placeholder: "ion:add-circle",
            },
          },
        },
        path: {
          title: "链接",
          type: "link",
          column: {
            width: 300,
          },
          form: {
            rules: [
              {
                required: true,
                message: "请输入链接",
              },
              {
                type: "url",
                message: "请输入正确的链接",
              },
            ],
          },
        },
      },
    },
  };
}
