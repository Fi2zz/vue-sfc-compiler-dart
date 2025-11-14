# import_basic

```ts
import { defineComponent as _defineComponent } from "vue";

export default /*@__PURE__*/ _defineComponent({
  __name: "import_basic",
  setup(__props, { expose: __expose }) {
    __expose();

    const a = ref(1);
    const ok = isRef(a);

    const __returned__ = { a, ok };
    Object.defineProperty(__returned__, "__isScriptSetup", {
      enumerable: false,
      value: true,
    });
    return __returned__;
  },
});
```
