# customRef_basic

```ts
import { defineComponent as _defineComponent } from "vue";

export default /*@__PURE__*/ _defineComponent({
  __name: "customRef_basic",
  setup(__props, { expose: __expose }) {
    __expose();

    const r = customRef((track, trigger) => ({
      get() {
        track();
        return 1;
      },
      set(v) {
        trigger();
      },
    }));

    const __returned__ = { r };
    Object.defineProperty(__returned__, "__isScriptSetup", {
      enumerable: false,
      value: true,
    });
    return __returned__;
  },
});
```
