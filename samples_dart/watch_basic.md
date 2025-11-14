# watch_basic

```ts
import { defineComponent as _defineComponent } from "vue";

export default /*@__PURE__*/ _defineComponent({
  __name: "watch_basic",
  setup(__props, { expose: __expose }) {
    __expose();

    const v = ref(0);
    watch(v, (nv, ov) => {});

    const __returned__ = { v };
    Object.defineProperty(__returned__, "__isScriptSetup", {
      enumerable: false,
      value: true,
    });
    return __returned__;
  },
});
```
