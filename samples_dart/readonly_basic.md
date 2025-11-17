# readonly_basic

```
import { defineComponent as _defineComponent } from "vue";
import {
reactive,
readonly,
} from "vue";

export default /*@__PURE__*/ _defineComponent({
setup(__props, { expose: __expose }) {
__expose();

const s = readonly(reactive({ a: 1 }));

const __returned__ = {
s,
};
Object.defineProperty(__returned__, "__isScriptSetup", {
enumerable: false,
value: true,
});
return __returned__;
},
});
```
