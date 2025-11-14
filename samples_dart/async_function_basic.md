# async_function_basic

```ts
import { defineComponent as _defineComponent } from "vue";

export default /*@__PURE__*/ _defineComponent({
  __name: "async_function_basic",
  setup(__props, { expose: __expose }) {
    __expose();

    async function load() {
      return 1;
    }

    const __returned__ = { load };
    Object.defineProperty(__returned__, "__isScriptSetup", {
      enumerable: false,
      value: true,
    });
    return __returned__;
  },
});
```
