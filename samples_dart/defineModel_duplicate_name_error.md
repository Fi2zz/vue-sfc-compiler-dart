# defineModel_duplicate_name_error

```ts
import {
  useModel as _useModel,
  defineComponent as _defineComponent,
} from "vue";

export default /*@__PURE__*/ _defineComponent({
  __name: "defineModel_duplicate_name_error",
  props: {
    count: { type: Number },
    countModifiers: {},
    count: { type: Number },
    countModifiers: {},
  },
  emits: ["update:count", "update:count"],
  setup(__props, { expose: __expose }) {
    __expose();

    const a = _useModel<number>(__props, "count");
    const b = _useModel<number>(__props, "count");

    const __returned__ = { a, b };
    Object.defineProperty(__returned__, "__isScriptSetup", {
      enumerable: false,
      value: true,
    });
    return __returned__;
  },
});
```
