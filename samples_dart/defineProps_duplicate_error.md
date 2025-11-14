# defineProps_duplicate_error

```ts
import { defineComponent as _defineComponent } from "vue";

export default /*@__PURE__*/ _defineComponent({
  __name: "defineProps_duplicate_error",
  props: {
    b: { type: String, required: true },
  },
  setup(__props: any, { expose: __expose }) {
    __expose();

    const p1 = __props;
    const p2 = __props;

    const __returned__ = { props, p1, p2 };
    Object.defineProperty(__returned__, "__isScriptSetup", {
      enumerable: false,
      value: true,
    });
    return __returned__;
  },
});
```
