# defineModel_get_set

```
import { useModel as _useModel, mergeModels as _mergeModels, defineComponent as _defineComponent } from "vue";

export default /*@__PURE__*/ _defineComponent({
props: /*@__PURE__*/ _mergeModels({
},
{
value: { type: Number },
valueModifiers: {},
}),
emits: /*@__PURE__*/ _mergeModels([], ["update:value"]),
setup(__props, { expose: __expose }) {
__expose();

const value = _useModel<number>(__props, 'value');

const __returned__ = {
value,
};
Object.defineProperty(__returned__, "__isScriptSetup", {
enumerable: false,
value: true,
});
return __returned__;
},
});
```
