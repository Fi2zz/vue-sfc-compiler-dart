# defineOptions_duplicate_error

```ts
import { defineComponent as _defineComponent } from "vue";

export default /*@__PURE__*/ _defineComponent({
  ...{ name: "X1" },
  ...{ name: "X2" },
  __name: "defineOptions_duplicate_error",
  setup(__props, { expose: __expose }) {
    __expose();

    const __returned__ = {};
    Object.defineProperty(__returned__, "__isScriptSetup", {
      enumerable: false,
      value: true,
    });
    return __returned__;
  },
});
```
