# getCurrentScope_basic

```
import { defineComponent as _defineComponent } from "vue";
import {
getCurrentScope,
} from "vue";

export default /*@__PURE__*/ _defineComponent({
setup(__props, { expose: __expose }) {
__expose();

const scope = getCurrentScope();

const __returned__ = {
scope,
};
Object.defineProperty(__returned__, "__isScriptSetup", {
enumerable: false,
value: true,
});
return __returned__;
},
});
```
