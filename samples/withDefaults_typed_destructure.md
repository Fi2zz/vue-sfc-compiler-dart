# withDefaults_typed_destructure

```ts
import { defineComponent as _defineComponent } from "vue";

export default /*@__PURE__*/ _defineComponent({
  __name: "withDefaults_typed_destructure",
  props: {
    msg: { type: String, required: false, default: "hi" },
    count: { type: Number, required: false, default: 1 },
  },
  setup(__props: any, { expose: __expose }) {
    __expose();

    const { msg, count } = __props;

    const __returned__ = { msg, count };
    Object.defineProperty(__returned__, "__isScriptSetup", {
      enumerable: false,
      value: true,
    });
    return __returned__;
  },
});
```
