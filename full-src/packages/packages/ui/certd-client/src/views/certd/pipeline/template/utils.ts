import { eachSteps } from "/@/views/certd/pipeline/utils";

export function useStepHelper(pluginStore: any) {
  function getStepsMap(pipeline: any) {
    const stepMap: any = {};
    eachSteps(pipeline, (step: any) => {
      const plugin = pluginStore.getPluginDefineSync(step.type);
      if (!plugin) {
        return;
      }

      const inputs: any = {};
      for (const key in plugin.input) {
        const input: any = plugin.input[key];
        if (input.template === false || input.component?.name === "output-selector") {
          continue;
        }
        inputs[key] = {
          value: step.input[key],
          define: {
            ...plugin.input[key],
            name: [step.id, key],
          },
        };
      }
      stepMap[step.id] = {
        id: step.id,
        title: step.title,
        type: step.type,
        input: inputs,
      };
    });
    return stepMap;
  }
  return {
    getStepsMap,
  };
}
