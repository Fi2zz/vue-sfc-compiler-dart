# defineProps_ts_array_object

```ts
import { defineComponent as _defineComponent } from "vue";

export default /*@__PURE__*/ _defineComponent({
  __name: "defineProps_ts_array_object",
  props: {
    items: { type: Array, required: true },
    config: { type: Object, required: false },
  },
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
