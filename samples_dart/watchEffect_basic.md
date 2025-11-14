# watchEffect_basic

```ts
import { defineComponent as _defineComponent } from "vue";

export default /*@__PURE__*/ _defineComponent({
  __name: "watchEffect_basic",
  setup(__props, { expose: __expose }) {
    __expose();

    const v = ref(0);
    watchEffect(() => {
      v.value;
    });

    const __returned__ = { v };
    Object.defineProperty(__returned__, "__isScriptSetup", {
      enumerable: false,
      value: true,
    });
    return __returned__;
  },
});
```
