# defineAsyncComponent_basic

```
import { defineComponent as _defineComponent } from "vue";
import {
defineAsyncComponent,
} from "vue";

export default /*@__PURE__*/ _defineComponent({
setup(__props, { expose: __expose }) {
__expose();

const Comp = defineAsyncComponent(() => Promise.resolve({}));

const __returned__ = {
Comp,
};
Object.defineProperty(__returned__, "__isScriptSetup", {
enumerable: false,
value: true,
});
return __returned__;
},
});
```
