# for_loop_basic

```ts
import { defineComponent as _defineComponent } from "vue";

export default /*@__PURE__*/ _defineComponent({
  __name: "for_loop_basic",
  setup(__props, { expose: __expose }) {
    __expose();

    for (let i = 0; i < 3; i++) {}

    const __returned__ = { i };
    Object.defineProperty(__returned__, "__isScriptSetup", {
      enumerable: false,
      value: true,
    });
    return __returned__;
  },
});
```
