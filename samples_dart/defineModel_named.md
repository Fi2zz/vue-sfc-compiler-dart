# defineModel_named

```
import { useModel as _useModel, mergeModels as _mergeModels, defineComponent as _defineComponent } from "vue";

export default /*@__PURE__*/ _defineComponent({
props: /*@__PURE__*/ _mergeModels({
},
{
count: { type: Number, ...{ default: 0 } },
countModifiers: {},
}),
emits: /*@__PURE__*/ _mergeModels([], ["update:count"]),
setup(__props, { expose: __expose }) {
__expose();

const count = _useModel<number>(__props, 'count');

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
