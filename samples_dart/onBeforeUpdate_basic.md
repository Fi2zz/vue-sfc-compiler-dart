# onBeforeUpdate_basic

```ts
import { defineComponent as _defineComponent } from "vue";

export default /*@__PURE__*/ _defineComponent({
  __name: "onBeforeUpdate_basic",
  setup(__props, { expose: __expose }) {
    __expose();

    onBeforeUpdate(() => {});

    const __returned__ = {};
    Object.defineProperty(__returned__, "__isScriptSetup", {
      enumerable: false,
      value: true,
    });
    return __returned__;
  },
});
```
