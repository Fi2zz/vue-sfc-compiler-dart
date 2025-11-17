# nextTick_basic

```
import { defineComponent as _defineComponent } from "vue";
import {
nextTick,
} from "vue";

export default /*@__PURE__*/ _defineComponent({
setup(__props, { expose: __expose }) {
__expose();

await nextTick();

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
