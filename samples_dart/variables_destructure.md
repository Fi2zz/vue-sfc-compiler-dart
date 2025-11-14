# variables_destructure

```ts
import { defineComponent as _defineComponent } from "vue";

export default /*@__PURE__*/ _defineComponent({
  __name: "variables_destructure",
  setup(__props, { expose: __expose }) {
    __expose();

    const { x, ok = true } = { x: 1, ok: true };

    const __returned__ = {};
    Object.defineProperty(__returned__, "__isScriptSetup", {
      enumerable: false,
      value: true,
    });
    return __returned__;
  },
});
```
