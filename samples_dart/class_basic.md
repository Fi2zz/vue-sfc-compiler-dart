# class_basic

```
export default /*@__PURE__*/_defineComponent({
  __name: 'class_basic',
setup(__props, { expose: __expose }) {
  __expose();

const x = new X()

const __returned__ = { x }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })

return __returned__
}

})
```
