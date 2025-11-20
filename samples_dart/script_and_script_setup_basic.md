# script_and_script_setup_basic

```
export default /*@__PURE__*/_defineComponent({
  __name: 'script_and_script_setup_basic',
setup(__props, { expose: __expose }) {
  __expose();

const count = ref(0)

const __returned__ = { count }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })

return __returned__
}

})
```
