# defineModel_default_runtime_type

```ts
import { useModel as _useModel } from "vue";

export default {
  __name: "defineModel_default_runtime_type",
  props: {
    modelValue: { type: String },
    modelModifiers: {},
  },
  emits: ["update:modelValue"],
  setup(__props, { expose: __expose }) {
    __expose();

    const model = _useModel(__props, "modelValue");

    const __returned__ = { model };
    Object.defineProperty(__returned__, "__isScriptSetup", {
      enumerable: false,
      value: true,
    });
    return __returned__;
  },
};
```
