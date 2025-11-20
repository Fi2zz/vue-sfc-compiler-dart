# class_private_field_basic

```
export default /*@__PURE__*/_defineComponent({
  __name: 'class_private_field_basic',
setup(__props, { expose: __expose }) {
  __expose();

const y = new Y()

const __returned__ = { y }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })

return __returned__
}

})
```
