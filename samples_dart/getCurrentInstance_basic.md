# getCurrentInstance_basic

```ts
import { defineComponent as _defineComponent } from "vue";

export default /*@__PURE__*/ _defineComponent({
  __name: "getCurrentInstance_basic",
  setup(__props, { expose: __expose }) {
    __expose();

    const inst = getCurrentInstance();

    const __returned__ = { inst };
    Object.defineProperty(__returned__, "__isScriptSetup", {
      enumerable: false,
      value: true,
    });
    return __returned__;
  },
});
```
