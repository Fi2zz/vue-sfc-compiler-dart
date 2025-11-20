# defineSlots_basic

```
export default /*@__PURE__*/_defineComponent({
  __name: 'defineSlots_basic',
setup(__props, { expose: __expose }) {
  __expose();

const slots = defineSlots()

const __returned__ = { slots }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })

return __returned__
}

})
```
