# variables_let

```ts
import { defineComponent as _defineComponent } from "vue";

export default /*@__PURE__*/ _defineComponent({
  __name: "variables_let",
  setup(__props, { expose: __expose }) {
    __expose();

    let a = 1;

    const __returned__ = { a };
    Object.defineProperty(__returned__, "__isScriptSetup", {
      enumerable: false,
      value: true,
    });
    return __returned__;
  },
});
```
