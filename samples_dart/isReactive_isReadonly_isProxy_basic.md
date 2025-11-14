# isReactive_isReadonly_isProxy_basic

```ts
import { defineComponent as _defineComponent } from "vue";

export default /*@__PURE__*/ _defineComponent({
  __name: "isReactive_isReadonly_isProxy_basic",
  setup(__props, { expose: __expose }) {
    __expose();

    const a = reactive({});
    const b = readonly({});
    const ra = isReactive(a);
    const ro = isReadonly(b);
    const px = isProxy(a);

    const __returned__ = { a, b, ra, ro, px };
    Object.defineProperty(__returned__, "__isScriptSetup", {
      enumerable: false,
      value: true,
    });
    return __returned__;
  },
});
```
