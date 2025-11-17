# class_basic

```
import { defineComponent as _defineComponent } from "vue";

export default /*@__PURE__*/ _defineComponent({
setup(__props, { expose: __expose }) {
__expose();

class X { a = 1 }
const x = new X();

const __returned__ = {
X,
x,
};
Object.defineProperty(__returned__, "__isScriptSetup", {
enumerable: false,
value: true,
});
return __returned__;
},
});
```
