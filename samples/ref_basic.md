# ref_basic

```ts
import { defineComponent as _defineComponent } from "vue";
import { ref } from "vue";

export default /*@__PURE__*/ _defineComponent({
  __name: "ref_basic",
  setup(__props, { expose: __expose }) {
    __expose();

    const count = ref(0);

    const __returned__ = { count, ref };
    Object.defineProperty(__returned__, "__isScriptSetup", {
      enumerable: false,
      value: true,
    });
    return __returned__;
  },
});
```
