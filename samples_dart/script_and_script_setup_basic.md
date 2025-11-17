# script_and_script_setup_basic

```
import { defineComponent as _defineComponent } from "vue";

const __default__ = {
name: "MyComponent",
inheritAttrs: false
};
export default /*@__PURE__*/ _defineComponent({
...__default__,
setup(__props, { expose: __expose }) {
__expose();

const count = ref(0);

const __returned__ = {
count,
};
Object.defineProperty(__returned__, "__isScriptSetup", {
enumerable: false,
value: true,
});
return __returned__;
},
});
```
