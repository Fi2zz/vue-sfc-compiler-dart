# defineProps_type_and_runtime_error

```ts
import { defineComponent as _defineComponent } from "vue";

export default /*@__PURE__*/ _defineComponent({
  __name: "defineProps_type_and_runtime_error",
  props: { a: Number },
  setup(__props: any, { expose: __expose }) {
    __expose();

    const p = __props;

    const __returned__ = { props, p };
    Object.defineProperty(__returned__, "__isScriptSetup", {
      enumerable: false,
      value: true,
    });
    return __returned__;
  },
});
```
