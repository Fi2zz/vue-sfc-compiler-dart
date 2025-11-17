# defineProps_ts_basic

```
import { defineComponent as _defineComponent } from "vue";

export default /*@__PURE__*/ _defineComponent({
props: {
msg: { type: String, required: true },
count: { type: Number, required: false },
},
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
