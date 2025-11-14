# defineEmits_duplicate_error

```ts
import { defineComponent as _defineComponent } from "vue";

export default /*@__PURE__*/ _defineComponent({
  __name: "defineEmits_duplicate_error",
  emits: ["b"],
  setup(__props, { expose: __expose, emit: __emit }) {
    __expose();

    const e1 = __emit;
    const e2 = __emit;

    const __returned__ = { emit, e1, e2 };
    Object.defineProperty(__returned__, "__isScriptSetup", {
      enumerable: false,
      value: true,
    });
    return __returned__;
  },
});
```
