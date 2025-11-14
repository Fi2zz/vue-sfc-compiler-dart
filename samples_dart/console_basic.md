# console_basic

```ts
import { defineComponent as _defineComponent } from "vue";

export default /*@__PURE__*/ _defineComponent({
  __name: "console_basic",
  setup(__props, { expose: __expose }) {
    __expose();

    console.log("hello");

    const __returned__ = {};
    Object.defineProperty(__returned__, "__isScriptSetup", {
      enumerable: false,
      value: true,
    });
    return __returned__;
  },
});
```
