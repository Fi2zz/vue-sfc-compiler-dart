# interface_basic

```ts
import { defineComponent as _defineComponent } from "vue";
interface Point {
  x: number;
  y: number;
}

export default /*@__PURE__*/ _defineComponent({
  __name: "interface_basic",
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
