# defineOptions_props_error

```ts
import { defineComponent as _defineComponent } from "vue";

export default /*@__PURE__*/ _defineComponent({
  ...{ name: "OptsPropsErr", props: { a: String } },
  __name: "defineOptions_props_error",
  setup(__props, { expose: __expose }) {
    __expose();

    const __returned__ = {};
    Object.defineProperty(__returned__, "__isScriptSetup", {
      enumerable: false,
      value: true,
    });
    return __returned__;
  },
});
```
