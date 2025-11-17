# variables_object

```
export default {
  __name: 'variables_object',
  setup(__props, { expose: __expose }) {
  __expose();

const obj = { x: 1, ok: true }

const __returned__ = { obj }
Object.defineProperty(__returned__, '__isScriptSetup', { enumerable: false, value: true })
return __returned__
}

}
```
