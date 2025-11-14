# variables_object

```ts
import { defineComponent as _defineComponent } from "vue";

export default /*@__PURE__*/ _defineComponent({
  __name: "variables_object",
  setup(__props, { expose: __expose }) {
    __expose();

    const obj = { x: 1, ok: true };

    const __returned__ = { obj };
    Object.defineProperty(__returned__, "__isScriptSetup", {
      enumerable: false,
      value: true,
    });
    return __returned__;
  },
});
```
