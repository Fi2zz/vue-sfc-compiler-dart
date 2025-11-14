# shallowReactive_basic

```ts
import { defineComponent as _defineComponent } from "vue";
import { shallowReactive } from "vue";

export default /*@__PURE__*/ _defineComponent({
  __name: "shallowReactive_basic",
  setup(__props, { expose: __expose }) {
    __expose();

    const obj = shallowReactive({ a: 1 });

    const __returned__ = { obj, shallowReactive };
    Object.defineProperty(__returned__, "__isScriptSetup", {
      enumerable: false,
      value: true,
    });
    return __returned__;
  },
});
```
