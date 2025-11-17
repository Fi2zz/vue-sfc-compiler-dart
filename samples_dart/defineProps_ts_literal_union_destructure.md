# defineProps_ts_literal_union_destructure

```
import { defineComponent as _defineComponent } from "vue";

export default /*@__PURE__*/ _defineComponent({
props: {
size: { type: Object, required: true },
},
setup(__props: any, { expose: __expose }) {
__expose();

const { size = 'medium' } = __props;

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
