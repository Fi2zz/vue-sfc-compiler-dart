# onRenderTriggered_basic

```ts
import { defineComponent as _defineComponent } from "vue";
import { onRenderTriggered } from "vue";

export default /*@__PURE__*/ _defineComponent({
  __name: "onRenderTriggered_basic",
  setup(__props, { expose: __expose }) {
    __expose();

    onRenderTriggered(() => {});

    const __returned__ = { onRenderTriggered };
    Object.defineProperty(__returned__, "__isScriptSetup", {
      enumerable: false,
      value: true,
    });
    return __returned__;
  },
});
```
