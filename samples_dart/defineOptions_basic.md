# defineOptions_basic

```
import { defineComponent as _defineComponent } from "vue";

export default /*@__PURE__*/ _defineComponent({
...{ name: "MyComponent", inheritAttrs: false },
setup(__props, { expose: __expose }) {
__expose();


const __returned__ = {
};
Object.defineProperty(__returned__, "__isScriptSetup", {
enumerable: false,
value: true,
});
return __returned__;
},
});
```
