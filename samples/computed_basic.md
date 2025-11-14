# computed_basic

```ts
import { defineComponent as _defineComponent } from "vue";
import { ref, computed } from "vue";

export default /*@__PURE__*/ _defineComponent({
  __name: "computed_basic",
  setup(__props, { expose: __expose }) {
    __expose();

    const count = ref(1);
    const double = computed(() => count.value * 2);

    const __returned__ = { count, double, ref, computed };
    Object.defineProperty(__returned__, "__isScriptSetup", {
      enumerable: false,
      value: true,
    });
    return __returned__;
  },
});
```
