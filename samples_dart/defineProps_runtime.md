# defineProps_runtime

```
import { defineComponent as _defineComponent } from "vue";

export default /*@__PURE__*/ _defineComponent({
props: { msg: String, count: { type: Number, default: 0 } },
setup(__props: any, { expose: __expose }) {
__expose();

const props = __props;

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
