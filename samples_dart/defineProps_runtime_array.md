# defineProps_runtime_array

```ts
import { defineComponent as _defineComponent } from "vue";

export default /*@__PURE__*/ _defineComponent({
  __name: "defineProps_runtime_array",
  props: {},
  setup(__props: any, { expose: __expose }) {
    __expose();

    const props = __props;

    const __returned__ = { props };
    Object.defineProperty(__returned__, "__isScriptSetup", {
      enumerable: false,
      value: true,
    });
    return __returned__;
  },
});
```
