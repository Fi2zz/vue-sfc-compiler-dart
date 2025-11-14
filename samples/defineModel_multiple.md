# defineModel_multiple

```ts
import {
  useModel as _useModel,
  defineComponent as _defineComponent,
} from "vue";

export default /*@__PURE__*/ _defineComponent({
  __name: "defineModel_multiple",
  props: {
    modelValue: { type: String },
    modelModifiers: {},
    checked: { type: Boolean },
    checkedModifiers: {},
  },
  emits: ["update:modelValue", "update:checked"],
  setup(__props, { expose: __expose }) {
    __expose();

    const title = _useModel<string>(__props, "modelValue");
    const checked = _useModel<boolean>(__props, "checked");

    const __returned__ = { title, checked };
    Object.defineProperty(__returned__, "__isScriptSetup", {
      enumerable: false,
      value: true,
    });
    return __returned__;
  },
});
```
