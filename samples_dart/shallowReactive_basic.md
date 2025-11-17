# shallowReactive_basic

```
import { defineComponent as _defineComponent } from "vue";
import {
shallowReactive,
} from "vue";

export default /*@__PURE__*/ _defineComponent({
setup(__props, { expose: __expose }) {
__expose();

const obj = shallowReactive({ a: 1 });

const __returned__ = {
obj,
};
Object.defineProperty(__returned__, "__isScriptSetup", {
enumerable: false,
value: true,
});
return __returned__;
},
});
```
