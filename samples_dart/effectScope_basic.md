# effectScope_basic

```
import { defineComponent as _defineComponent } from "vue";
import {
effectScope,
} from "vue";

export default /*@__PURE__*/ _defineComponent({
setup(__props, { expose: __expose }) {
__expose();

const scope = effectScope();
scope.stop();

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
