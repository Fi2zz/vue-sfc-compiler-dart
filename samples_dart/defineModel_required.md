# defineModel_required

```
import { useModel as _useModel, mergeModels as _mergeModels, defineComponent as _defineComponent } from "vue";

export default /*@__PURE__*/ _defineComponent({
props: /*@__PURE__*/ _mergeModels({
},
{
visible: { type: Boolean, ...{ required: true } },
visibleModifiers: {},
}),
emits: /*@__PURE__*/ _mergeModels([], ["update:visible"]),
setup(__props, { expose: __expose }) {
__expose();

const visible = _useModel<boolean>(__props, 'visible');

const __returned__ = {
visible,
};
Object.defineProperty(__returned__, "__isScriptSetup", {
enumerable: false,
value: true,
});
return __returned__;
},
});
```
