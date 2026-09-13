export function eachTree(tree: any[], callback: (item: any) => void) {
  tree.forEach(item => {
    callback(item);
    if (item.children) {
      eachTree(item.children, callback);
    }
  });
}

export function treeMap(tree: any[], mapFunc: (item: any) => {}) {
  return tree.map((item: any) => {
    const newItem: any = mapFunc(item);
    if (item.children) {
      newItem.children = treeMap(item.children, mapFunc);
    }
    return newItem;
  });
}

export const treeUtils = {
  eachTree,
  treeMap,
};
